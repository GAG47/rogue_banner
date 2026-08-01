class_name BuffService
extends RefCounted

var _attribute_calculator: AttributeCalculator


func _init(attribute_calculator: AttributeCalculator = null) -> void:
	_attribute_calculator = attribute_calculator
	if _attribute_calculator == null:
		_attribute_calculator = AttributeCalculator.new()


func apply_buff(
		unit: UnitState,
		definition: BuffDefinition,
		source: BattleSource
) -> BuffApplicationResult:
	if unit == null or unit.is_defeated() or definition == null:
		return BuffApplicationResult.failure()

	var existing: BuffState = unit.find_buff(definition)
	if existing != null:
		match definition.stacking_rule:
			GameEnums.BuffStackingRule.REFRESH_DURATION:
				existing.remaining_turns = definition.duration_turns
			GameEnums.BuffStackingRule.ADD_STACKS:
				existing.stacks = mini(
						existing.stacks + 1,
						definition.maximum_stacks
				)
				existing.remaining_turns = definition.duration_turns
			GameEnums.BuffStackingRule.REPLACE:
				existing.stacks = 1
				existing.source = (
					source.duplicate_state() if source != null else null
				)
				existing.remaining_turns = definition.duration_turns
		_clamp_unit_values(unit)
		return BuffApplicationResult.success(
				existing.instance_id,
				existing.stacks,
				true
		)

	var buff: BuffState = BuffState.create(
			unit._allocate_buff_id(),
			definition,
			source
	)
	if not unit._add_buff(buff):
		return BuffApplicationResult.failure()
	_clamp_unit_values(unit)
	return BuffApplicationResult.success(buff.instance_id, buff.stacks, false)


func remove_buff(
		unit: UnitState,
		definition: BuffDefinition
) -> Array[BuffState]:
	var removed: Array[BuffState] = []
	if unit == null or definition == null:
		return removed

	for buff: BuffState in unit.get_buffs():
		if buff != null and buff.definition == definition:
			var removed_buff: BuffState = unit._remove_buff(buff.instance_id)
			if removed_buff != null:
				removed.append(removed_buff)
	_clamp_unit_values(unit)
	return removed


func advance_turn(unit: UnitState) -> Array[BuffState]:
	var expired: Array[BuffState] = []
	if unit == null:
		return expired

	for buff: BuffState in unit.get_buffs():
		if buff == null:
			continue
		buff.remaining_turns -= 1
		if buff.remaining_turns <= 0:
			var removed: BuffState = unit._remove_buff(buff.instance_id)
			if removed != null:
				expired.append(removed)
	_clamp_unit_values(unit)
	return expired


func _clamp_unit_values(unit: UnitState) -> void:
	unit.current_health = mini(
			unit.current_health,
			_attribute_calculator.calculate(
					unit,
					GameEnums.AttributeType.MAX_HEALTH
			)
	)
	unit.current_ap = mini(
			unit.current_ap,
			_attribute_calculator.calculate(
					unit,
					GameEnums.AttributeType.MAX_AP
			)
	)

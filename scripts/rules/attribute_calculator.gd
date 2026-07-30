class_name AttributeCalculator
extends RefCounted

class ModifierEntry:
	extends RefCounted

	var definition: ModifierDefinition
	var stacks: int = 1
	var source_order: int = 0


func calculate(
		unit: UnitState,
		attribute: GameEnums.AttributeType
) -> int:
	if unit == null or unit.definition == null:
		return 0

	var value: float = float(_base_value(unit.definition, attribute))
	var entries: Array[ModifierEntry] = _collect_entries(unit, attribute)
	entries.sort_custom(_entry_precedes)

	var additive_percent: float = 0.0
	for entry: ModifierEntry in entries:
		if entry.definition.operation == GameEnums.ModifierOperation.FLAT:
			value += entry.definition.value * float(entry.stacks)
		elif (
			entry.definition.operation
			== GameEnums.ModifierOperation.ADDITIVE_PERCENT
		):
			additive_percent += entry.definition.value * float(entry.stacks)
	value *= 1.0 + additive_percent

	for entry: ModifierEntry in entries:
		if (
			entry.definition.operation
			== GameEnums.ModifierOperation.MULTIPLICATIVE
		):
			value *= pow(entry.definition.value, entry.stacks)

	for entry: ModifierEntry in entries:
		match entry.definition.operation:
			GameEnums.ModifierOperation.OVERRIDE:
				value = entry.definition.value
			GameEnums.ModifierOperation.CLAMP_MIN:
				value = maxf(value, entry.definition.value)
			GameEnums.ModifierOperation.CLAMP_MAX:
				value = minf(value, entry.definition.value)

	return maxi(0, roundi(value))


func _base_value(
		definition: UnitDefinition,
		attribute: GameEnums.AttributeType
) -> int:
	match attribute:
		GameEnums.AttributeType.MAX_HEALTH:
			return definition.max_health
		GameEnums.AttributeType.BASE_ATTACK:
			return definition.base_attack
		GameEnums.AttributeType.MAX_AP:
			return definition.max_ap
	return 0


func _collect_entries(
		unit: UnitState,
		attribute: GameEnums.AttributeType
) -> Array[ModifierEntry]:
	var result: Array[ModifierEntry] = []
	var source_order: int = 0
	for buff: BuffState in unit.get_buffs():
		if buff == null or buff.definition == null:
			continue
		for modifier: ModifierDefinition in buff.definition.modifiers:
			if modifier != null and modifier.attribute == attribute:
				var entry: ModifierEntry = ModifierEntry.new()
				entry.definition = modifier
				entry.stacks = buff.stacks
				entry.source_order = source_order
				result.append(entry)
				source_order += 1
	return result


func _entry_precedes(left: ModifierEntry, right: ModifierEntry) -> bool:
	if left.definition.priority != right.definition.priority:
		return left.definition.priority < right.definition.priority
	return left.source_order < right.source_order

class_name BattleEffectPlanner
extends RefCounted

var _attribute_calculator: AttributeCalculator
var _pathfinder: GridPathfinder


func _init(
		attribute_calculator: AttributeCalculator = null,
		pathfinder: GridPathfinder = null
) -> void:
	_attribute_calculator = attribute_calculator
	if _attribute_calculator == null:
		_attribute_calculator = AttributeCalculator.new()
	_pathfinder = pathfinder
	if _pathfinder == null:
		_pathfinder = GridPathfinder.new()


func plan_all(
		definitions: Array[EffectDefinition],
		context: EffectContext
) -> EffectPlanResult:
	if context == null or context.battle == null:
		return EffectPlanResult.rejected()

	var plans: Array[EffectExecutionPlan] = []
	var move_effect_count: int = 0
	for definition: EffectDefinition in definitions:
		if definition is MoveEffectDefinition:
			move_effect_count += 1
			if move_effect_count > 1:
				return EffectPlanResult.rejected()
		var plan: EffectExecutionPlan = _plan_one(definition, context)
		if plan == null:
			return EffectPlanResult.rejected()
		plans.append(plan)
	return EffectPlanResult.accepted(plans)


func _plan_one(
		definition: EffectDefinition,
		context: EffectContext
) -> EffectExecutionPlan:
	if definition == null:
		return null
	if not _is_supported_definition(definition):
		return null

	var plan: EffectExecutionPlan = EffectExecutionPlan.new()
	plan.definition = definition
	plan.target_unit_ids.assign(_resolve_unit_targets(definition, context))

	if definition is MoveEffectDefinition:
		return _plan_move(plan, context)
	if (
		plan.target_unit_ids.is_empty()
		and definition.target_source
		!= GameEnums.EffectTargetSource.HIT_UNITS
	):
		return null
	for target_id: int in plan.target_unit_ids:
		var target: UnitState = context.battle.get_unit(target_id)
		if target == null:
			return null

	if definition is ScaledUnitEffectDefinition:
		var scaled: ScaledUnitEffectDefinition = (
			definition as ScaledUnitEffectDefinition
		)
		var actor: UnitState = context.battle.get_unit(context.actor_unit_id)
		if actor == null:
			return null
		plan.amount = scaled.flat_amount + roundi(
				float(
					_attribute_calculator.calculate(
							actor,
							scaled.source_attribute
					)
				) * scaled.attribute_multiplier
		)
		if plan.amount <= 0:
			return null
	elif definition is ApplyBuffEffectDefinition:
		if (definition as ApplyBuffEffectDefinition).buff == null:
			return null
	elif definition is RemoveBuffEffectDefinition:
		if (definition as RemoveBuffEffectDefinition).buff == null:
			return null
	return plan


func _plan_move(
		plan: EffectExecutionPlan,
		context: EffectContext
) -> EffectExecutionPlan:
	if (
		plan.target_unit_ids.size() != 1
		or context.targets == null
		or context.targets.cells.size() != 1
	):
		return null
	var unit_id: int = plan.target_unit_ids[0]
	var origin: GridCoordinate = context.battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			unit_id
	)
	if origin == null:
		return null
	var destination: Vector2i = context.targets.cells[0]
	var path_result: GridPathResult = _pathfinder.find_path(
			context.battle.grid,
			origin.value,
			destination
	)
	if not path_result.succeeded():
		return null
	plan.destination = GridCoordinate.new(destination)
	plan.movement_path.assign(path_result.path)
	return plan


func _resolve_unit_targets(
		definition: EffectDefinition,
		context: EffectContext
) -> Array[int]:
	var result: Array[int] = []
	match definition.target_source:
		GameEnums.EffectTargetSource.ACTOR:
			if context.actor_unit_id > 0:
				result.append(context.actor_unit_id)
		GameEnums.EffectTargetSource.HIT_UNITS:
			if context.resolved_targets != null:
				result.assign(context.resolved_targets.hit_unit_ids)
		GameEnums.EffectTargetSource.EVENT_SOURCE_UNIT:
			if context.event != null and context.event.source_unit_id > 0:
				result.append(context.event.source_unit_id)
		GameEnums.EffectTargetSource.EVENT_TARGET_UNIT:
			if context.event != null and context.event.target_unit_id > 0:
				result.append(context.event.target_unit_id)
	return result


func _is_supported_definition(definition: EffectDefinition) -> bool:
	return (
			definition is DamageEffectDefinition
			or definition is HealingEffectDefinition
			or definition is ShieldEffectDefinition
			or definition is ApplyBuffEffectDefinition
			or definition is RemoveBuffEffectDefinition
			or definition is MoveEffectDefinition
			or definition is ForcedMovementEffectDefinition
	)

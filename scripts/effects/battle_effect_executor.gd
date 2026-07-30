class_name BattleEffectExecutor
extends EffectExecutor

var _attribute_calculator: AttributeCalculator
var _buff_service: BuffService
var _movement_service: BattleMovementService


func _init(
		attribute_calculator: AttributeCalculator = null,
		buff_service: BuffService = null,
		movement_service: BattleMovementService = null
) -> void:
	_attribute_calculator = attribute_calculator
	if _attribute_calculator == null:
		_attribute_calculator = AttributeCalculator.new()
	_buff_service = buff_service
	if _buff_service == null:
		_buff_service = BuffService.new(_attribute_calculator)
	_movement_service = movement_service
	if _movement_service == null:
		_movement_service = BattleMovementService.new()


func execute(
		definition: EffectDefinition,
		context: EffectContext
) -> EffectResult:
	if definition == null or context == null:
		return EffectResult.failure(GameEnums.EffectStatus.INVALID_CONTEXT)
	var plan_result: EffectPlanResult = BattleEffectPlanner.new(
			_attribute_calculator
	).plan_all([definition], context)
	if not plan_result.is_valid:
		return EffectResult.failure(GameEnums.EffectStatus.INVALID_DEFINITION)
	return execute_plans(context.battle, context.actor_unit_id, plan_result.plans)


func execute_plans(
		battle: BattleState,
		actor_unit_id: int,
		plans: Array[EffectExecutionPlan]
) -> EffectResult:
	if battle == null:
		return EffectResult.failure(GameEnums.EffectStatus.INVALID_CONTEXT)

	var result: EffectResult = EffectResult.success()
	for plan: EffectExecutionPlan in plans:
		var step_result: EffectResult = _execute_plan(
				battle,
				actor_unit_id,
				plan
		)
		if not step_result.succeeded():
			return step_result
		result.events.append_array(step_result.events)
		for unit_id: int in step_result.affected_unit_ids:
			if not result.affected_unit_ids.has(unit_id):
				result.affected_unit_ids.append(unit_id)
	return result


func _execute_plan(
		battle: BattleState,
		actor_unit_id: int,
		plan: EffectExecutionPlan
) -> EffectResult:
	if plan == null or plan.definition == null:
		return EffectResult.failure(GameEnums.EffectStatus.INVALID_DEFINITION)
	if plan.definition is DamageEffectDefinition:
		return _execute_damage(battle, actor_unit_id, plan)
	if plan.definition is HealingEffectDefinition:
		return _execute_healing(battle, actor_unit_id, plan)
	if plan.definition is ShieldEffectDefinition:
		return _execute_shield(battle, actor_unit_id, plan)
	if plan.definition is ApplyBuffEffectDefinition:
		return _execute_apply_buff(battle, actor_unit_id, plan)
	if plan.definition is RemoveBuffEffectDefinition:
		return _execute_remove_buff(battle, actor_unit_id, plan)
	if plan.definition is MoveEffectDefinition:
		return _execute_move(battle, plan)
	if plan.definition is ForcedMovementEffectDefinition:
		return _execute_forced_movement(battle, actor_unit_id, plan)
	return EffectResult.failure(GameEnums.EffectStatus.INVALID_DEFINITION)


func _execute_damage(
		battle: BattleState,
		actor_unit_id: int,
		plan: EffectExecutionPlan
) -> EffectResult:
	var result: EffectResult = EffectResult.success()
	for target_id: int in plan.target_unit_ids:
		var target: UnitState = battle.get_unit(target_id)
		if target == null:
			return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
		if target.is_defeated():
			continue

		var previous_shield: int = target.current_shield
		var absorbed: int = mini(previous_shield, plan.amount)
		target.current_shield -= absorbed
		var remaining_damage: int = plan.amount - absorbed
		var previous_health: int = target.current_health
		target.current_health = maxi(0, target.current_health - remaining_damage)
		var health_damage: int = previous_health - target.current_health
		if absorbed > 0:
			result.events.append(
					ShieldChangedEvent.create(
							actor_unit_id,
							target_id,
							previous_shield,
							target.current_shield
					)
			)
		result.events.append(
				DamageAppliedEvent.create(
						actor_unit_id,
						target_id,
						plan.amount,
						health_damage,
						absorbed
				)
		)
		if previous_health > 0 and target.current_health == 0:
			result.events.append(
					UnitDefeatedEvent.create(actor_unit_id, target_id)
			)
		result.affected_unit_ids.append(target_id)
	return result


func _execute_healing(
		battle: BattleState,
		actor_unit_id: int,
		plan: EffectExecutionPlan
) -> EffectResult:
	var result: EffectResult = EffectResult.success()
	for target_id: int in plan.target_unit_ids:
		var target: UnitState = battle.get_unit(target_id)
		if target == null:
			return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
		if target.is_defeated():
			continue
		var previous_health: int = target.current_health
		var maximum_health: int = _attribute_calculator.calculate(
				target,
				GameEnums.AttributeType.MAX_HEALTH
		)
		target.current_health = mini(maximum_health, target.current_health + plan.amount)
		result.events.append(
				HealingAppliedEvent.create(
						actor_unit_id,
						target_id,
						plan.amount,
						target.current_health - previous_health
				)
		)
		result.affected_unit_ids.append(target_id)
	return result


func _execute_shield(
		battle: BattleState,
		actor_unit_id: int,
		plan: EffectExecutionPlan
) -> EffectResult:
	var result: EffectResult = EffectResult.success()
	for target_id: int in plan.target_unit_ids:
		var target: UnitState = battle.get_unit(target_id)
		if target == null:
			return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
		if target.is_defeated():
			continue
		var previous_shield: int = target.current_shield
		target.current_shield += plan.amount
		result.events.append(
				ShieldChangedEvent.create(
						actor_unit_id,
						target_id,
						previous_shield,
						target.current_shield
				)
		)
		result.affected_unit_ids.append(target_id)
	return result


func _execute_apply_buff(
		battle: BattleState,
		actor_unit_id: int,
		plan: EffectExecutionPlan
) -> EffectResult:
	var result: EffectResult = EffectResult.success()
	var definition: ApplyBuffEffectDefinition = (
		plan.definition as ApplyBuffEffectDefinition
	)
	for target_id: int in plan.target_unit_ids:
		var target: UnitState = battle.get_unit(target_id)
		if target == null:
			return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
		if target.is_defeated():
			continue
		var previous_health: int = target.current_health
		var application: BuffApplicationResult = _buff_service.apply_buff(
				target,
				definition.buff,
				actor_unit_id
		)
		if not application.succeeded:
			return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
		result.events.append(
				BuffAppliedEvent.create(
						actor_unit_id,
						target_id,
						definition.buff,
						application.stacks
				)
		)
		if previous_health > 0 and target.current_health == 0:
			result.events.append(
					UnitDefeatedEvent.create(actor_unit_id, target_id)
			)
		result.affected_unit_ids.append(target_id)
	return result


func _execute_remove_buff(
		battle: BattleState,
		actor_unit_id: int,
		plan: EffectExecutionPlan
) -> EffectResult:
	var result: EffectResult = EffectResult.success()
	var definition: RemoveBuffEffectDefinition = (
		plan.definition as RemoveBuffEffectDefinition
	)
	for target_id: int in plan.target_unit_ids:
		var target: UnitState = battle.get_unit(target_id)
		if target == null:
			return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
		if target.is_defeated():
			continue
		var previous_health: int = target.current_health
		var removed: Array[BuffState] = _buff_service.remove_buff(
				target,
				definition.buff
		)
		for buff: BuffState in removed:
			result.events.append(
					BuffRemovedEvent.create(
							actor_unit_id,
							target_id,
							buff.definition
					)
			)
		if previous_health > 0 and target.current_health == 0:
			result.events.append(
					UnitDefeatedEvent.create(actor_unit_id, target_id)
			)
		result.affected_unit_ids.append(target_id)
	return result


func _execute_move(
		battle: BattleState,
		plan: EffectExecutionPlan
) -> EffectResult:
	if plan.target_unit_ids.size() != 1:
		return EffectResult.failure(GameEnums.EffectStatus.INVALID_TARGET)
	var target: UnitState = battle.get_unit(plan.target_unit_ids[0])
	if target == null:
		return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
	if target.is_defeated():
		return EffectResult.success()
	var movement: BattleMovementResult = _movement_service.commit_path(
			battle,
			plan.target_unit_ids[0],
			plan.movement_path
	)
	if not movement.succeeded:
		return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
	var result: EffectResult = EffectResult.success()
	result.events.append(movement.event)
	result.affected_unit_ids.append(plan.target_unit_ids[0])
	return result


func _execute_forced_movement(
		battle: BattleState,
		actor_unit_id: int,
		plan: EffectExecutionPlan
) -> EffectResult:
	var definition: ForcedMovementEffectDefinition = (
		plan.definition as ForcedMovementEffectDefinition
	)
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			actor_unit_id
	)
	if definition == null or actor_position == null:
		return EffectResult.failure(GameEnums.EffectStatus.INVALID_CONTEXT)

	var result: EffectResult = EffectResult.success()
	for target_unit_id: int in plan.target_unit_ids:
		var target: UnitState = battle.get_unit(target_unit_id)
		var target_position: GridCoordinate = battle.grid.find_occupant(
				GameEnums.GridOccupantKind.UNIT,
				target_unit_id
		)
		if target == null or target_position == null:
			return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
		if target.is_defeated():
			continue

		var direction: Vector2i = _forced_direction(
				definition,
				actor_position.value,
				target_position.value
		)
		if direction == Vector2i.ZERO:
			continue
		var path: Array[Vector2i] = [target_position.value]
		var destination: Vector2i = target_position.value
		for step: int in range(definition.distance):
			var candidate: Vector2i = destination + direction
			if not battle.grid.can_place_at(candidate).succeeded():
				break
			destination = candidate
			path.append(destination)
		if path.size() < 2:
			continue

		var movement: BattleMovementResult = _movement_service.commit_path(
				battle,
				target_unit_id,
				path
		)
		if not movement.succeeded:
			return EffectResult.failure(GameEnums.EffectStatus.STATE_CHANGED)
		result.events.append(movement.event)
		result.affected_unit_ids.append(target_unit_id)
	return result


func _forced_direction(
		definition: ForcedMovementEffectDefinition,
		actor_position: Vector2i,
		target_position: Vector2i
) -> Vector2i:
	if (
		definition.direction_rule
		== GameEnums.ForcedMovementDirection.FIXED
	):
		return GridDirection.to_vector(definition.fixed_direction)
	var delta: Vector2i = target_position - actor_position
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	var direction: Vector2i = GridDirection.to_vector(
			GridDirection.from_delta(delta)
	)
	if (
		definition.direction_rule
		== GameEnums.ForcedMovementDirection.TOWARD_ACTOR
	):
		direction = -direction
	return direction

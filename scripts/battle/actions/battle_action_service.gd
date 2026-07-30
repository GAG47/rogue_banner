class_name BattleActionService
extends RefCounted

var _pathfinder: GridPathfinder
var _turn_service: BattleTurnService
var _target_resolver: BattleTargetResolver
var _condition_evaluator: ConditionEvaluator
var _effect_planner: BattleEffectPlanner
var _effect_executor: BattleEffectExecutor
var _event_processor: BattleEventProcessor
var _resolution_service: BattleResolutionService
var _movement_service: BattleMovementService


func _init(
		pathfinder: GridPathfinder = null,
		turn_service: BattleTurnService = null,
		event_processor: BattleEventProcessor = null
) -> void:
	_pathfinder = pathfinder
	if _pathfinder == null:
		_pathfinder = GridPathfinder.new()

	_turn_service = turn_service
	if _turn_service == null:
		_turn_service = BattleTurnService.new()

	var attribute_calculator: AttributeCalculator = AttributeCalculator.new()
	var buff_service: BuffService = BuffService.new(attribute_calculator)
	_movement_service = BattleMovementService.new()
	_target_resolver = BattleTargetResolver.new()
	_condition_evaluator = ConditionEvaluator.new()
	_effect_planner = BattleEffectPlanner.new(
			attribute_calculator,
			_pathfinder
	)
	_effect_executor = BattleEffectExecutor.new(
			attribute_calculator,
			buff_service,
			_movement_service
	)
	_event_processor = event_processor
	if _event_processor == null:
		_event_processor = BattleEventProcessor.new(
				_condition_evaluator,
				_effect_planner,
				_effect_executor
		)
	_resolution_service = BattleResolutionService.new()


func validate(
		battle: BattleState,
		request: BattleActionRequest
) -> ActionValidationResult:
	if request == null:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.INVALID_REQUEST
		)
	if battle == null or battle.grid == null or not battle.grid.is_valid():
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.INVALID_BATTLE
		)

	if request is MoveActionRequest:
		return _validate_move(battle, request as MoveActionRequest)
	if request is UseArtActionRequest:
		return _validate_use_art(battle, request as UseArtActionRequest)
	if request is EndTurnActionRequest:
		return _validate_end_turn(battle, request as EndTurnActionRequest)
	return ActionValidationResult.rejected(
			GameEnums.ActionFailureCode.UNSUPPORTED_ACTION
	)


func execute(
		battle: BattleState,
		request: BattleActionRequest
) -> ActionExecutionResult:
	var validation: ActionValidationResult = validate(battle, request)
	if not validation.is_valid:
		return ActionExecutionResult.failure(validation.failure_code)

	var transaction: BattleTransaction = BattleTransaction.begin(battle)
	if transaction == null or transaction.working_state == null:
		return ActionExecutionResult.failure(
				GameEnums.ActionFailureCode.INVALID_BATTLE
		)
	var working_validation: ActionValidationResult = validate(
			transaction.working_state,
			request
	)
	if not working_validation.is_valid:
		return ActionExecutionResult.failure(working_validation.failure_code)

	var result: ActionExecutionResult
	if request is MoveActionRequest:
		result = _execute_move(
				transaction.working_state,
				request as MoveActionRequest,
				working_validation.plan
		)
	elif request is EndTurnActionRequest:
		result = _execute_end_turn(
				transaction.working_state,
				request as EndTurnActionRequest
		)
	elif request is UseArtActionRequest:
		result = _execute_use_art(
				transaction.working_state,
				request as UseArtActionRequest,
				working_validation.plan
		)
	else:
		return ActionExecutionResult.failure(
				GameEnums.ActionFailureCode.UNSUPPORTED_ACTION
		)
	if not result.is_successful:
		return result
	if not transaction.commit():
		return ActionExecutionResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)
	return result


func start_battle(battle: BattleState) -> ActionExecutionResult:
	if battle == null or battle.grid == null or not battle.grid.is_valid():
		return ActionExecutionResult.failure(
				GameEnums.ActionFailureCode.INVALID_BATTLE
		)
	var transaction: BattleTransaction = BattleTransaction.begin(battle)
	if transaction == null or transaction.working_state == null:
		return ActionExecutionResult.failure(
				GameEnums.ActionFailureCode.INVALID_BATTLE
		)
	var transition: TurnTransitionResult = _turn_service._start_battle(
			transaction.working_state
	)
	if not transition.succeeded:
		return ActionExecutionResult.failure(transition.failure_code)
	var result: ActionExecutionResult = _process_events_and_resolve(
			transaction.working_state,
			transition.events
	)
	if not result.is_successful:
		return result
	if not transaction.commit():
		return ActionExecutionResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)
	return result


func _validate_move(
		battle: BattleState,
		request: MoveActionRequest
) -> ActionValidationResult:
	var common_failure: GameEnums.ActionFailureCode = _validate_actor_action(
			battle,
			request.requesting_side,
			request.actor_unit_id
	)
	if common_failure != GameEnums.ActionFailureCode.NONE:
		return ActionValidationResult.rejected(common_failure)

	var actor: UnitState = battle.get_unit(request.actor_unit_id)
	var position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			request.actor_unit_id
	)
	if position == null:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.ACTOR_NOT_PLACED
		)
	if position.value == request.destination:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.DESTINATION_UNCHANGED
		)
	if not battle.grid.is_in_bounds(request.destination):
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.DESTINATION_OUT_OF_BOUNDS
		)

	var destination_cell: CellState = battle.grid.get_cell(request.destination)
	if destination_cell == null or destination_cell.terrain == null:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.DESTINATION_BLOCKED
		)
	if destination_cell.terrain.blocks_movement:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.DESTINATION_BLOCKED
		)
	if battle.grid.get_occupant(request.destination) != null:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.DESTINATION_OCCUPIED
		)

	var path_result: GridPathResult = _pathfinder.find_path(
			battle.grid,
			position.value,
			request.destination
	)
	if not path_result.succeeded():
		return ActionValidationResult.rejected(_map_path_failure(path_result.status))
	if actor.current_ap < path_result.total_cost:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.INSUFFICIENT_AP
		)

	var plan: ActionExecutionPlan = ActionExecutionPlan.create(
			request,
			path_result.total_cost
	)
	plan.movement_path.assign(path_result.path)
	return ActionValidationResult.accepted(plan)


func _validate_use_art(
		battle: BattleState,
		request: UseArtActionRequest
) -> ActionValidationResult:
	var common_failure: GameEnums.ActionFailureCode = _validate_actor_action(
			battle,
			request.requesting_side,
			request.actor_unit_id
	)
	if common_failure != GameEnums.ActionFailureCode.NONE:
		return ActionValidationResult.rejected(common_failure)

	var actor: UnitState = battle.get_unit(request.actor_unit_id)
	if request.art_slot_index < 0 or request.art_slot_index >= actor.arts.size():
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.ART_NOT_FOUND
		)
	var art_state: ArtState = actor.arts[request.art_slot_index]
	if art_state == null or art_state.definition == null:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.ART_NOT_FOUND
		)
	if art_state.definition.category == GameEnums.ArtCategory.PASSIVE:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.ART_NOT_USABLE
		)
	if art_state.current_cooldown > 0:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.ART_ON_COOLDOWN
		)
	if actor.current_ap < art_state.definition.ap_cost:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.INSUFFICIENT_AP
		)
	var art_definition: ArtDefinition = art_state.definition
	if request.targets == null or art_definition.targeting == null:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		)
	var targeting_context: BattleTargetingContext = BattleTargetingContext.create(
			battle,
			actor.instance_id,
			request.targets
	)
	var target_result: TargetResolutionResult = _target_resolver.resolve(
			art_definition.targeting,
			targeting_context,
			request.targets
	)
	if not target_result.is_valid:
		return ActionValidationResult.rejected(target_result.failure_code)

	var condition_context: BattleConditionContext = BattleConditionContext.create(
			battle,
			actor.instance_id,
			target_result.selection,
			art_definition,
			target_result.resolved_targets
	)
	var condition_result: ConditionResult = _condition_evaluator.evaluate_all(
			art_definition.use_conditions,
			condition_context
	)
	if condition_result.status == GameEnums.ConditionStatus.INVALID_CONTEXT:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.CONDITION_CONTEXT_INVALID
		)
	if not condition_result.passed():
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.CONDITION_FAILED
		)

	var effect_context: EffectContext = EffectContext.create(
			battle,
			actor.instance_id,
			target_result.selection,
			art_definition,
			target_result.resolved_targets
	)
	var effect_plan_result: EffectPlanResult = _effect_planner.plan_all(
			art_definition.effects,
			effect_context
	)
	if not effect_plan_result.is_valid or effect_plan_result.plans.is_empty():
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.EFFECT_PLAN_INVALID
		)

	var plan: ActionExecutionPlan = ActionExecutionPlan.create(
			request,
			art_definition.ap_cost
	)
	plan.art_slot_index = request.art_slot_index
	plan.art_definition = art_definition
	plan.resolved_targets = target_result.resolved_targets
	plan.cooldown_to_apply = art_definition.cooldown
	plan.effect_plans.assign(effect_plan_result.plans)
	return ActionValidationResult.accepted(plan)


func _validate_end_turn(
		battle: BattleState,
		request: EndTurnActionRequest
) -> ActionValidationResult:
	var phase_failure: GameEnums.ActionFailureCode = _validate_active_side(
			battle,
			request.requesting_side
	)
	if phase_failure != GameEnums.ActionFailureCode.NONE:
		return ActionValidationResult.rejected(phase_failure)
	return ActionValidationResult.accepted(ActionExecutionPlan.create(request))


func _execute_move(
		battle: BattleState,
		request: MoveActionRequest,
		plan: ActionExecutionPlan
) -> ActionExecutionResult:
	var actor: UnitState = battle.get_unit(request.actor_unit_id)
	var position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			request.actor_unit_id
	)
	if (
			actor == null
			or position == null
			or plan == null
			or plan.movement_path.is_empty()
			or plan.movement_path[0] != position.value
			or actor.current_ap < plan.ap_cost
	):
		return ActionExecutionResult.failure(GameEnums.ActionFailureCode.STATE_CHANGED)

	var movement: BattleMovementResult = _movement_service.commit_path(
			battle,
			request.actor_unit_id,
			plan.movement_path,
			plan.ap_cost
	)
	if not movement.succeeded:
		return ActionExecutionResult.failure(movement.failure_code)
	var result: ActionExecutionResult = _process_events_and_resolve(
			battle,
			[movement.event]
	)
	if result.is_successful:
		result.ap_spent = movement.ap_spent
		result.movement_path.assign(movement.path)
	return result


func _execute_end_turn(
		battle: BattleState,
		request: EndTurnActionRequest
) -> ActionExecutionResult:
	var transition: TurnTransitionResult = _turn_service._end_turn(
			battle,
			request.requesting_side
	)
	if not transition.succeeded:
		return ActionExecutionResult.failure(transition.failure_code)
	return _process_events_and_resolve(battle, transition.events)


func _execute_use_art(
		battle: BattleState,
		request: UseArtActionRequest,
		plan: ActionExecutionPlan
) -> ActionExecutionResult:
	var actor: UnitState = battle.get_unit(request.actor_unit_id)
	if (
		actor == null
		or plan == null
		or plan.art_definition == null
		or plan.art_slot_index < 0
		or plan.art_slot_index >= actor.arts.size()
		or actor.arts[plan.art_slot_index] == null
		or actor.arts[plan.art_slot_index].definition != plan.art_definition
		or actor.arts[plan.art_slot_index].current_cooldown > 0
		or actor.current_ap < plan.ap_cost
	):
		return ActionExecutionResult.failure(GameEnums.ActionFailureCode.STATE_CHANGED)

	actor.current_ap -= plan.ap_cost
	actor.arts[plan.art_slot_index].current_cooldown = plan.cooldown_to_apply
	var effect_result: EffectResult = _effect_executor.execute_plans(
			battle,
			actor.instance_id,
			plan.effect_plans
	)
	if not effect_result.succeeded():
		return ActionExecutionResult.failure(
				GameEnums.ActionFailureCode.EFFECT_EXECUTION_FAILED
		)
	effect_result.events.append(
			ArtUsedEvent.create(
					actor.instance_id,
					plan.art_definition,
					plan.art_slot_index
			)
	)
	var result: ActionExecutionResult = _process_events_and_resolve(
			battle,
			effect_result.events
	)
	if result.is_successful:
		result.ap_spent = plan.ap_cost
	return result


func _process_events_and_resolve(
		battle: BattleState,
		initial_events: Array[BattleEvent]
) -> ActionExecutionResult:
	var event_result: BattleEventProcessResult = _event_processor.process(
			battle,
			initial_events
	)
	if not event_result.succeeded:
		var failure: ActionExecutionResult = ActionExecutionResult.failure(
				event_result.failure_code
		)
		failure.events.assign(event_result.events)
		return failure

	var resolution: BattleResolutionResult = _resolution_service.resolve(battle)
	var result: ActionExecutionResult = ActionExecutionResult.success(battle)
	result.events.assign(event_result.events)
	result.removed_unit_ids.assign(resolution.removed_unit_ids)
	if resolution.event != null:
		result.events.append(resolution.event)
	return result


func _validate_actor_action(
		battle: BattleState,
		requesting_side: GameEnums.BattleSide,
		actor_unit_id: int
) -> GameEnums.ActionFailureCode:
	var phase_failure: GameEnums.ActionFailureCode = _validate_active_side(
			battle,
			requesting_side
	)
	if phase_failure != GameEnums.ActionFailureCode.NONE:
		return phase_failure

	var actor: UnitState = battle.get_unit(actor_unit_id)
	if actor == null:
		return GameEnums.ActionFailureCode.ACTOR_NOT_FOUND
	if actor.side != requesting_side:
		return GameEnums.ActionFailureCode.ACTOR_SIDE_MISMATCH
	if actor.is_defeated():
		return GameEnums.ActionFailureCode.ACTOR_DEFEATED
	if (
			battle.grid.find_occupant(
					GameEnums.GridOccupantKind.UNIT,
					actor_unit_id
			) == null
	):
		return GameEnums.ActionFailureCode.ACTOR_NOT_PLACED
	return GameEnums.ActionFailureCode.NONE


func _validate_active_side(
		battle: BattleState,
		requesting_side: GameEnums.BattleSide
) -> GameEnums.ActionFailureCode:
	if (
			battle.phase != GameEnums.BattlePhase.PLAYER_TURN
			and battle.phase != GameEnums.BattlePhase.ENEMY_TURN
	):
		return GameEnums.ActionFailureCode.BATTLE_NOT_ACTIVE
	if (
			battle.phase == GameEnums.BattlePhase.PLAYER_TURN
			and battle.active_side != GameEnums.BattleSide.PLAYER
	):
		return GameEnums.ActionFailureCode.INVALID_BATTLE
	if (
			battle.phase == GameEnums.BattlePhase.ENEMY_TURN
			and battle.active_side != GameEnums.BattleSide.ENEMY
	):
		return GameEnums.ActionFailureCode.INVALID_BATTLE
	if battle.active_side != requesting_side:
		return GameEnums.ActionFailureCode.WRONG_TURN
	return GameEnums.ActionFailureCode.NONE


func _map_path_failure(
		status: GameEnums.GridPathStatus
) -> GameEnums.ActionFailureCode:
	match status:
		GameEnums.GridPathStatus.OUT_OF_BOUNDS:
			return GameEnums.ActionFailureCode.DESTINATION_OUT_OF_BOUNDS
		GameEnums.GridPathStatus.DESTINATION_BLOCKED:
			return GameEnums.ActionFailureCode.DESTINATION_BLOCKED
		GameEnums.GridPathStatus.NO_PATH:
			return GameEnums.ActionFailureCode.NO_PATH
		_:
			return GameEnums.ActionFailureCode.INVALID_BATTLE

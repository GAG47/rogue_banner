class_name BattleActionService
extends RefCounted

var _pathfinder: GridPathfinder
var _turn_service: BattleTurnService


func _init(
		pathfinder: GridPathfinder = null,
		turn_service: BattleTurnService = null
) -> void:
	_pathfinder = pathfinder
	if _pathfinder == null:
		_pathfinder = GridPathfinder.new()

	_turn_service = turn_service
	if _turn_service == null:
		_turn_service = BattleTurnService.new()


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

	if request is MoveActionRequest:
		return _execute_move(
				battle,
				request as MoveActionRequest,
				validation.plan
		)
	if request is EndTurnActionRequest:
		return _execute_end_turn(battle, request as EndTurnActionRequest)
	return ActionExecutionResult.failure(
			GameEnums.ActionFailureCode.UNSUPPORTED_ACTION
	)


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
	if request.targets == null:
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		)
	var target_count: int = request.targets.count()
	if (
			art_state.definition.targeting == null
			or target_count < art_state.definition.targeting.minimum_targets
			or target_count > art_state.definition.targeting.maximum_targets
	):
		return ActionValidationResult.rejected(
				GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		)

	return ActionValidationResult.rejected(
			GameEnums.ActionFailureCode.ART_EXECUTION_UNAVAILABLE
	)


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

	var grid_result: GridOperationResult = battle.grid.move_occupant(
			GridOccupant.unit(request.actor_unit_id),
			position.value,
			request.destination
	)
	if not grid_result.succeeded():
		return ActionExecutionResult.failure(GameEnums.ActionFailureCode.STATE_CHANGED)

	actor.current_ap -= plan.ap_cost
	var result: ActionExecutionResult = ActionExecutionResult.success(battle)
	result.ap_spent = plan.ap_cost
	result.movement_path.assign(plan.movement_path)
	return result


func _execute_end_turn(
		battle: BattleState,
		request: EndTurnActionRequest
) -> ActionExecutionResult:
	var transition: TurnTransitionResult = _turn_service.end_turn(
			battle,
			request.requesting_side
	)
	if not transition.succeeded:
		return ActionExecutionResult.failure(transition.failure_code)
	return ActionExecutionResult.success(battle)


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

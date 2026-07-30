class_name IntentExecutor
extends RefCounted

var _action_service: BattleActionService
var _target_adapter: IntentTargetAdapter


func _init(action_service: BattleActionService) -> void:
	_action_service = action_service
	_target_adapter = IntentTargetAdapter.new()


func execute(
		battle: BattleState,
		plan: IntentPlan
) -> IntentExecutionResult:
	var result: IntentExecutionResult = IntentExecutionResult.new()
	if plan == null:
		result.status = GameEnums.IntentExecutionStatus.SKIPPED
		return result
	if battle == null or plan.definition == null:
		result.status = GameEnums.IntentExecutionStatus.INTERNAL_FAILURE
		result.failure_code = GameEnums.ActionFailureCode.INTENT_EXECUTION_FAILED
		return result
	result.actor_unit_id = plan.actor_unit_id
	var actor: UnitState = battle.get_unit(plan.actor_unit_id)
	if actor == null or actor.is_defeated():
		result.status = GameEnums.IntentExecutionStatus.SKIPPED
		return result

	match plan.definition.sequence:
		GameEnums.IntentSequence.ART_ONLY:
			if not _append_art_step(battle, plan, result):
				return result
		GameEnums.IntentSequence.MOVE_THEN_ART:
			if not _append_move_step(battle, plan, result):
				return result
			if _is_terminal(battle):
				return result
			if not _append_art_step(battle, plan, result):
				return result
		GameEnums.IntentSequence.ART_THEN_MOVE:
			if not _append_art_step(battle, plan, result):
				return result
			if _is_terminal(battle):
				return result
			if not _append_move_step(battle, plan, result):
				return result
	return result


func _append_move_step(
		battle: BattleState,
		plan: IntentPlan,
		result: IntentExecutionResult
) -> bool:
	if not plan.has_move_destination:
		result.steps.append(IntentStepResult.skipped())
		return true
	var action_result: ActionExecutionResult = _action_service.execute(
			battle,
			MoveActionRequest.create(
					GameEnums.BattleSide.ENEMY,
					plan.actor_unit_id,
					plan.move_destination
			)
	)
	return _append_action_result(action_result, result)


func _append_art_step(
		battle: BattleState,
		plan: IntentPlan,
		result: IntentExecutionResult
) -> bool:
	var selection: TargetSelection = _target_adapter.create_selection(
			battle,
			plan
	)
	if selection == null:
		result.steps.append(
				IntentStepResult.fizzled(
						GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
				)
		)
		return true
	var action_result: ActionExecutionResult = _action_service.execute(
			battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.ENEMY,
					plan.actor_unit_id,
					plan.art_slot_index,
					selection
			)
	)
	return _append_action_result(action_result, result)


func _append_action_result(
		action_result: ActionExecutionResult,
		result: IntentExecutionResult
) -> bool:
	if action_result.is_successful:
		result.steps.append(IntentStepResult.executed(action_result))
		return true
	if _is_expected_fizzle(action_result.failure_code):
		result.steps.append(
				IntentStepResult.fizzled(action_result.failure_code)
		)
		return true
	result.steps.append(
			IntentStepResult.internal_failure(action_result.failure_code)
	)
	result.status = GameEnums.IntentExecutionStatus.INTERNAL_FAILURE
	result.failure_code = action_result.failure_code
	return false


func _is_expected_fizzle(code: GameEnums.ActionFailureCode) -> bool:
	return code in [
		GameEnums.ActionFailureCode.ACTOR_NOT_FOUND,
		GameEnums.ActionFailureCode.ACTOR_DEFEATED,
		GameEnums.ActionFailureCode.ACTOR_NOT_PLACED,
		GameEnums.ActionFailureCode.DESTINATION_OUT_OF_BOUNDS,
		GameEnums.ActionFailureCode.DESTINATION_BLOCKED,
		GameEnums.ActionFailureCode.DESTINATION_OCCUPIED,
		GameEnums.ActionFailureCode.DESTINATION_UNCHANGED,
		GameEnums.ActionFailureCode.NO_PATH,
		GameEnums.ActionFailureCode.INSUFFICIENT_AP,
		GameEnums.ActionFailureCode.ART_NOT_FOUND,
		GameEnums.ActionFailureCode.ART_NOT_USABLE,
		GameEnums.ActionFailureCode.ART_ON_COOLDOWN,
		GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION,
		GameEnums.ActionFailureCode.CONDITION_FAILED,
		GameEnums.ActionFailureCode.TARGET_OUT_OF_RANGE,
		GameEnums.ActionFailureCode.TARGET_RELATION_INVALID,
		GameEnums.ActionFailureCode.LINE_OF_SIGHT_BLOCKED,
	]


func _is_terminal(battle: BattleState) -> bool:
	return (
		battle.phase == GameEnums.BattlePhase.VICTORY
		or battle.phase == GameEnums.BattlePhase.FAILURE
	)

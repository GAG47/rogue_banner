class_name EnemyTurnService
extends RefCounted

var _action_service: BattleActionService
var _intent_executor: IntentExecutor


func _init(action_service: BattleActionService) -> void:
	_action_service = action_service
	_intent_executor = IntentExecutor.new(action_service)


func execute_current_intents(battle: BattleState) -> EnemyTurnResult:
	if (
		battle == null
		or battle.phase != GameEnums.BattlePhase.ENEMY_TURN
		or battle.active_side != GameEnums.BattleSide.ENEMY
	):
		return EnemyTurnResult.failure(GameEnums.ActionFailureCode.INVALID_PHASE)
	var result: EnemyTurnResult = EnemyTurnResult.success()
	var enemy_ids: Array[int] = []
	for enemy_state: EnemyState in battle.get_enemy_states():
		enemy_ids.append(enemy_state.unit_instance_id)
	enemy_ids.sort()

	for enemy_id: int in enemy_ids:
		if _is_terminal(battle):
			return result
		var enemy_state: EnemyState = battle.get_enemy_state(enemy_id)
		var unit: UnitState = battle.get_unit(enemy_id)
		if enemy_state == null or unit == null or unit.is_defeated():
			continue
		var execution: IntentExecutionResult = _intent_executor.execute(
				battle,
				enemy_state.current_intent
		)
		result.executions.append(execution)
		if not execution.succeeded():
			result.succeeded = false
			result.failure_code = execution.failure_code
			return result
		var remaining_state: EnemyState = battle.get_enemy_state(enemy_id)
		if remaining_state != null:
			remaining_state.current_intent = null

	if _is_terminal(battle):
		return result
	result.end_turn_result = _action_service.execute(
			battle,
			EndTurnActionRequest.create(GameEnums.BattleSide.ENEMY)
	)
	if not result.end_turn_result.is_successful:
		result.succeeded = false
		result.failure_code = result.end_turn_result.failure_code
	return result


func _is_terminal(battle: BattleState) -> bool:
	return (
		battle.phase == GameEnums.BattlePhase.VICTORY
		or battle.phase == GameEnums.BattlePhase.FAILURE
	)

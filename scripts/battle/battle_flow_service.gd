class_name BattleFlowService
extends RefCounted

var _action_service: BattleActionService
var _generation_service: IntentGenerationService
var _enemy_turn_service: EnemyTurnService


func _init(
		action_service: BattleActionService = null,
		generation_service: IntentGenerationService = null
) -> void:
	_action_service = action_service
	if _action_service == null:
		_action_service = BattleActionService.new()
	_generation_service = generation_service
	if _generation_service == null:
		_generation_service = IntentGenerationService.new()
	_enemy_turn_service = EnemyTurnService.new(_action_service)


func start_battle(battle: BattleState) -> BattleFlowResult:
	var transaction: BattleTransaction = BattleTransaction.begin(battle)
	if transaction == null or transaction.working_state == null:
		return BattleFlowResult.failure(
				GameEnums.ActionFailureCode.INVALID_BATTLE
		)
	var result: BattleFlowResult = BattleFlowResult.success()
	result.transition_result = _action_service.start_battle(
			transaction.working_state
	)
	if not result.transition_result.is_successful:
		return BattleFlowResult.failure(result.transition_result.failure_code)
	if not _is_terminal(transaction.working_state):
		result.generation_result = _generation_service.generate_for_player_turn(
				transaction.working_state
		)
		if not result.generation_result.succeeded:
			return BattleFlowResult.failure(
					result.generation_result.failure_code
			)
	if not transaction.commit():
		return BattleFlowResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)
	return result


func end_player_turn(battle: BattleState) -> BattleFlowResult:
	var transaction: BattleTransaction = BattleTransaction.begin(battle)
	if transaction == null or transaction.working_state == null:
		return BattleFlowResult.failure(
				GameEnums.ActionFailureCode.INVALID_BATTLE
		)
	var working: BattleState = transaction.working_state
	var result: BattleFlowResult = BattleFlowResult.success()
	result.transition_result = _action_service.execute(
			working,
			EndTurnActionRequest.create(GameEnums.BattleSide.PLAYER)
	)
	if not result.transition_result.is_successful:
		return BattleFlowResult.failure(result.transition_result.failure_code)
	if not _is_terminal(working):
		result.enemy_turn_result = _enemy_turn_service.execute_current_intents(
				working
		)
		if not result.enemy_turn_result.succeeded:
			return BattleFlowResult.failure(
					result.enemy_turn_result.failure_code
			)
	if (
		not _is_terminal(working)
		and working.phase == GameEnums.BattlePhase.PLAYER_TURN
	):
		result.generation_result = _generation_service.generate_for_player_turn(
				working
		)
		if not result.generation_result.succeeded:
			return BattleFlowResult.failure(
					result.generation_result.failure_code
			)
	if not transaction.commit():
		return BattleFlowResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)
	return result


func _is_terminal(battle: BattleState) -> bool:
	return (
		battle.phase == GameEnums.BattlePhase.VICTORY
		or battle.phase == GameEnums.BattlePhase.FAILURE
	)

class_name BattleFlowResult
extends RefCounted

var succeeded: bool = false
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var transition_result: ActionExecutionResult
var enemy_turn_result: EnemyTurnResult
var generation_result: IntentGenerationResult


static func success() -> BattleFlowResult:
	var result: BattleFlowResult = BattleFlowResult.new()
	result.succeeded = true
	return result


static func failure(
		code: GameEnums.ActionFailureCode
) -> BattleFlowResult:
	var result: BattleFlowResult = BattleFlowResult.new()
	result.failure_code = code
	return result

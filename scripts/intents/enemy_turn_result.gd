class_name EnemyTurnResult
extends RefCounted

var succeeded: bool = false
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var executions: Array[IntentExecutionResult] = []
var end_turn_result: ActionExecutionResult


static func success() -> EnemyTurnResult:
	var result: EnemyTurnResult = EnemyTurnResult.new()
	result.succeeded = true
	return result


static func failure(
		code: GameEnums.ActionFailureCode
) -> EnemyTurnResult:
	var result: EnemyTurnResult = EnemyTurnResult.new()
	result.failure_code = code
	return result

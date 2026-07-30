class_name IntentExecutionResult
extends RefCounted

var status: GameEnums.IntentExecutionStatus = (
		GameEnums.IntentExecutionStatus.COMPLETED
)
var actor_unit_id: int = 0
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var steps: Array[IntentStepResult] = []


func succeeded() -> bool:
	return status != GameEnums.IntentExecutionStatus.INTERNAL_FAILURE

class_name IntentStepResult
extends RefCounted

var status: GameEnums.IntentStepStatus = GameEnums.IntentStepStatus.SKIPPED
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var action_result: ActionExecutionResult


static func executed(result: ActionExecutionResult) -> IntentStepResult:
	var step: IntentStepResult = IntentStepResult.new()
	step.status = GameEnums.IntentStepStatus.EXECUTED
	step.action_result = result
	return step


static func fizzled(
		code: GameEnums.ActionFailureCode
) -> IntentStepResult:
	var step: IntentStepResult = IntentStepResult.new()
	step.status = GameEnums.IntentStepStatus.FIZZLED
	step.failure_code = code
	return step


static func skipped() -> IntentStepResult:
	return IntentStepResult.new()


static func internal_failure(
		code: GameEnums.ActionFailureCode
) -> IntentStepResult:
	var step: IntentStepResult = IntentStepResult.new()
	step.status = GameEnums.IntentStepStatus.INTERNAL_FAILURE
	step.failure_code = code
	return step

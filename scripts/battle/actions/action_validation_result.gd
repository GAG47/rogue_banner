class_name ActionValidationResult
extends RefCounted

var is_valid: bool = false
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var plan: ActionExecutionPlan


static func accepted(
		execution_plan: ActionExecutionPlan
) -> ActionValidationResult:
	var result: ActionValidationResult = ActionValidationResult.new()
	result.is_valid = true
	result.plan = execution_plan
	return result


static func rejected(
		code: GameEnums.ActionFailureCode
) -> ActionValidationResult:
	var result: ActionValidationResult = ActionValidationResult.new()
	result.failure_code = code
	return result

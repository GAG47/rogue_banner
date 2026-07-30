class_name IntentGenerationResult
extends RefCounted

var succeeded: bool = false
var failure_code: GameEnums.ActionFailureCode = (
		GameEnums.ActionFailureCode.NONE
)
var plans: Array[IntentPlan] = []


static func success(generated_plans: Array[IntentPlan]) -> IntentGenerationResult:
	var result: IntentGenerationResult = IntentGenerationResult.new()
	result.succeeded = true
	result.plans.assign(generated_plans)
	return result


static func failure(
		code: GameEnums.ActionFailureCode
) -> IntentGenerationResult:
	var result: IntentGenerationResult = IntentGenerationResult.new()
	result.failure_code = code
	return result

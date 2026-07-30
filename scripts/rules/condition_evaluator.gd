class_name ConditionEvaluator
extends RefCounted


func evaluate_all(
		conditions: Array[ConditionDefinition],
		context: ConditionContext
) -> ConditionResult:
	if context == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	for condition: ConditionDefinition in conditions:
		if condition == null:
			return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
		var result: ConditionResult = condition.evaluate(context)
		if result == null:
			return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
		if not result.passed():
			return result
	return ConditionResult.success()

class_name FailingConditionDefinition
extends ConditionDefinition


func evaluate(_context: ConditionContext) -> ConditionResult:
	return ConditionResult.failure()

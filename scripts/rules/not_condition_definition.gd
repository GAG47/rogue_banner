class_name NotConditionDefinition
extends ConditionDefinition

@export var condition: ConditionDefinition


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if condition == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				field_path,
				"Not conditions require one child condition."
		)
	else:
		condition.validate_configuration(result, field_path)


func evaluate(context: ConditionContext) -> ConditionResult:
	if context == null or condition == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	var result: ConditionResult = condition.evaluate(context)
	if result == null or result.status == GameEnums.ConditionStatus.INVALID_CONTEXT:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	return ConditionResult.failure() if result.passed() else ConditionResult.success()

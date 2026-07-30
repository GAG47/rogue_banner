class_name AnyConditionDefinition
extends ConditionDefinition

@export var conditions: Array[ConditionDefinition] = []


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if conditions.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Any-condition groups require at least one child condition."
		)
	for index: int in range(conditions.size()):
		var condition: ConditionDefinition = conditions[index]
		var child_path: StringName = StringName(
				"%s.conditions[%d]" % [String(field_path), index]
		)
		if condition == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					child_path,
					"Condition group entries cannot be null."
			)
		else:
			condition.validate_configuration(result, child_path)


func validate_context(
		context_kind: GameEnums.ConditionContextKind,
		event_kind: GameEnums.BattleEventKind,
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	for index: int in range(conditions.size()):
		var condition: ConditionDefinition = conditions[index]
		if condition != null:
			condition.validate_context(
					context_kind,
					event_kind,
					result,
					_child_path(field_path, index)
			)


func evaluate(context: ConditionContext) -> ConditionResult:
	if context == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	for condition: ConditionDefinition in conditions:
		if condition == null:
			return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
		var result: ConditionResult = condition.evaluate(context)
		if result != null and result.passed():
			return ConditionResult.success()
	return ConditionResult.failure()


func _child_path(field_path: StringName, index: int) -> StringName:
	return StringName("%s.conditions[%d]" % [String(field_path), index])

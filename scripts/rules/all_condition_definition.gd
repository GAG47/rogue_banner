class_name AllConditionDefinition
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
				"All-condition groups require at least one child condition."
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
	return ConditionEvaluator.new().evaluate_all(conditions, context)


func _child_path(field_path: StringName, index: int) -> StringName:
	return StringName("%s.conditions[%d]" % [String(field_path), index])

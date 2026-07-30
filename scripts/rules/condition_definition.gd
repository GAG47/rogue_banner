@abstract
class_name ConditionDefinition
extends Resource


func validate_configuration(
		_result: DefinitionValidationResult,
		_field_path: StringName
) -> void:
	pass


@abstract
func evaluate(context: ConditionContext) -> ConditionResult

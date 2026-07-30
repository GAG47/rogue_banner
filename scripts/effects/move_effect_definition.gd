class_name MoveEffectDefinition
extends EffectDefinition


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if target_source != GameEnums.EffectTargetSource.ACTOR:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Move effects currently require the actor as their target."
		)

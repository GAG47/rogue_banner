class_name ApplyBuffEffectDefinition
extends EffectDefinition

@export var buff: BuffDefinition


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if buff == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				field_path,
				"Apply Buff effects require a Buff Definition."
		)
	elif buff.content_id == &"":
		result.add_issue(
				GameEnums.DefinitionValidationCode.EMPTY_ID,
				field_path,
				"Referenced Buff Definitions require a content ID."
		)

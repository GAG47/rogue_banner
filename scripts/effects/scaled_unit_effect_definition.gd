@abstract
class_name ScaledUnitEffectDefinition
extends EffectDefinition

@export var flat_amount: int = 0
@export var source_attribute: GameEnums.AttributeType = (
		GameEnums.AttributeType.BASE_ATTACK
)
@export var attribute_multiplier: float = 0.0


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if not is_finite(attribute_multiplier):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Effect attribute multipliers must be finite."
		)
	elif flat_amount < 0 or attribute_multiplier < 0.0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Effect amounts and attribute multipliers cannot be negative."
		)
	if flat_amount == 0 and is_zero_approx(attribute_multiplier):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Scaled Unit effects require a positive amount or multiplier."
		)

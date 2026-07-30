class_name ForcedMovementEffectDefinition
extends EffectDefinition

@export_range(1, 8, 1) var distance: int = 1
@export var direction_rule: GameEnums.ForcedMovementDirection = (
		GameEnums.ForcedMovementDirection.AWAY_FROM_ACTOR
)
@export var fixed_direction: GameEnums.CardinalDirection = (
		GameEnums.CardinalDirection.RIGHT
)


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if distance <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Forced movement distance must be greater than zero."
		)

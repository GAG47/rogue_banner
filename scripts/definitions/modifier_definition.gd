class_name ModifierDefinition
extends Resource

@export var attribute: GameEnums.AttributeType = GameEnums.AttributeType.BASE_ATTACK
@export var operation: GameEnums.ModifierOperation = GameEnums.ModifierOperation.FLAT
@export var value: float = 0.0
@export var priority: int = 0


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if not is_finite(value):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_MODIFIER,
				_child_path(field_path, &"value"),
				"Modifier values must be finite."
		)
	elif (
		operation == GameEnums.ModifierOperation.MULTIPLICATIVE
		and value < 0.0
	):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_MODIFIER,
				_child_path(field_path, &"value"),
				"Multiplicative modifier values cannot be negative."
		)


func _child_path(parent: StringName, child: StringName) -> StringName:
	return StringName("%s.%s" % [String(parent), String(child)])

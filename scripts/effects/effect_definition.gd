@abstract
class_name EffectDefinition
extends Resource

@export var target_source: GameEnums.EffectTargetSource = (
		GameEnums.EffectTargetSource.HIT_UNITS
)


func validate_configuration(
		_result: DefinitionValidationResult,
		_field_path: StringName
) -> void:
	pass

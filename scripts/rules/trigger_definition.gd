@abstract
class_name TriggerDefinition
extends Resource

@export var conditions: Array[ConditionDefinition] = []
@export var effects: Array[EffectDefinition] = []


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	for index: int in range(conditions.size()):
		var condition: ConditionDefinition = conditions[index]
		var condition_path: StringName = _indexed_path(field_path, &"conditions", index)
		if condition == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					condition_path,
					"Trigger condition references cannot be null."
			)
			continue
		condition.validate_configuration(result, condition_path)

	if effects.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.MISSING_EFFECT,
				_child_path(field_path, &"effects"),
				"A trigger must contain at least one effect."
		)

	for index: int in range(effects.size()):
		var effect: EffectDefinition = effects[index]
		var effect_path: StringName = _indexed_path(field_path, &"effects", index)
		if effect == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					effect_path,
					"Trigger effect references cannot be null."
			)
			continue
		effect.validate_configuration(result, effect_path)


func _child_path(parent: StringName, child: StringName) -> StringName:
	return StringName("%s.%s" % [String(parent), String(child)])


func _indexed_path(parent: StringName, field: StringName, index: int) -> StringName:
	return StringName("%s.%s[%d]" % [String(parent), String(field), index])

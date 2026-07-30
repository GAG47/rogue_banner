class_name TriggerDefinition
extends Resource

@export var event_kind: GameEnums.BattleEventKind = (
		GameEnums.BattleEventKind.ART_USED
)
@export_range(1, 32, 1) var maximum_triggers_per_action: int = 1
@export var conditions: Array[ConditionDefinition] = []
@export var effects: Array[EffectDefinition] = []


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if event_kind == GameEnums.BattleEventKind.BATTLE_ENDED:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				_child_path(field_path, &"event_kind"),
				"Battle-ended events are terminal and cannot trigger effects."
		)
	if maximum_triggers_per_action <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				_child_path(field_path, &"maximum_triggers_per_action"),
				"Trigger limits must be greater than zero."
		)
	elif maximum_triggers_per_action > 32:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				_child_path(field_path, &"maximum_triggers_per_action"),
				"Trigger limits cannot exceed 32 activations per action."
		)
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
		condition.validate_context(
				GameEnums.ConditionContextKind.EVENT_TRIGGER,
				event_kind,
				result,
				condition_path
		)

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
		if effect.target_source == GameEnums.EffectTargetSource.HIT_UNITS:
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_VALUE,
					effect_path,
					"Trigger effects cannot depend on a spatial hit result."
			)
		elif (
			effect.target_source
			== GameEnums.EffectTargetSource.EVENT_SOURCE_UNIT
			and not BattleEventSchema.supports(
					event_kind,
					GameEnums.EventDataCapability.SOURCE_UNIT
			)
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_VALUE,
					effect_path,
					"The selected event does not provide a source Unit."
			)
		elif (
			effect.target_source
			== GameEnums.EffectTargetSource.EVENT_TARGET_UNIT
			and not BattleEventSchema.supports(
					event_kind,
					GameEnums.EventDataCapability.TARGET_UNIT
			)
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_VALUE,
					effect_path,
					"The selected event does not provide a target Unit."
			)
		if effect is MoveEffectDefinition:
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_VALUE,
					effect_path,
					"Trigger effects cannot request a selected-Cell move."
			)
		effect.validate_configuration(result, effect_path)


func _child_path(parent: StringName, child: StringName) -> StringName:
	return StringName("%s.%s" % [String(parent), String(child)])


func _indexed_path(parent: StringName, field: StringName, index: int) -> StringName:
	return StringName("%s.%s[%d]" % [String(parent), String(field), index])

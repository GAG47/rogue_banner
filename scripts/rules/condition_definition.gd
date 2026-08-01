@abstract
class_name ConditionDefinition
extends Resource


func validate_configuration(
		_result: DefinitionValidationResult,
		_field_path: StringName
) -> void:
	pass


func validate_context(
		_context_kind: GameEnums.ConditionContextKind,
		_event_kind: GameEnums.BattleEventKind,
		_result: DefinitionValidationResult,
		_field_path: StringName
) -> void:
	pass


func requires_actor_unit() -> bool:
	return false


@abstract
func evaluate(context: ConditionContext) -> ConditionResult

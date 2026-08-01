class_name RunGoldConditionDefinition
extends ConditionDefinition

@export_range(0, 999999, 1) var minimum_gold: int = 0


func validate_configuration(
	result: DefinitionValidationResult,
	field_path: StringName
) -> void:
	if minimum_gold < 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Minimum Gold cannot be negative."
		)


func validate_context(
	context_kind: GameEnums.ConditionContextKind,
	_event_kind: GameEnums.BattleEventKind,
	result: DefinitionValidationResult,
	field_path: StringName
) -> void:
	if context_kind != GameEnums.ConditionContextKind.MAP_EVENT:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Run Gold conditions require a Map Event context."
		)


func evaluate(context: ConditionContext) -> ConditionResult:
	var event_context: MapEventConditionContext = (
		context as MapEventConditionContext
	)
	if event_context == null or event_context.run == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	return (
		ConditionResult.success()
		if event_context.run.get_gold() >= minimum_gold
		else ConditionResult.failure()
	)

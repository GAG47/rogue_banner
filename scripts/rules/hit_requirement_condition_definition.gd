class_name HitRequirementConditionDefinition
extends ConditionDefinition

@export var hit_target_kind: GameEnums.HitTargetKind = GameEnums.HitTargetKind.ANY
@export_range(1, 64, 1) var minimum_hits: int = 1


func validate_configuration(
	result: DefinitionValidationResult,
	field_path: StringName
) -> void:
	if minimum_hits <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Hit requirements must require at least one hit."
		)
	elif minimum_hits > 64:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Hit requirements cannot exceed 64 hits."
		)


func evaluate(context: ConditionContext) -> ConditionResult:
	var battle_context: BattleConditionContext = context as BattleConditionContext
	if battle_context == null or battle_context.resolved_targets == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	if (
		battle_context.resolved_targets.hit_count(hit_target_kind)
		>= minimum_hits
	):
		return ConditionResult.success()
	return ConditionResult.failure()


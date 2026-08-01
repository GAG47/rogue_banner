class_name EventUnitRelationConditionDefinition
extends ConditionDefinition

@export var event_unit_role: GameEnums.EventUnitRole = GameEnums.EventUnitRole.TARGET
@export var relation: GameEnums.TargetRelation = GameEnums.TargetRelation.SELF

var _relation_evaluator: UnitRelationEvaluator = UnitRelationEvaluator.new()


func validate_configuration(
	result: DefinitionValidationResult,
	field_path: StringName
) -> void:
	if relation == GameEnums.TargetRelation.NEUTRAL:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Battle event Units cannot use a neutral relation."
		)


func validate_context(
		context_kind: GameEnums.ConditionContextKind,
		event_kind: GameEnums.BattleEventKind,
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if context_kind != GameEnums.ConditionContextKind.EVENT_TRIGGER:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Event Unit relations require an event-trigger context."
		)
		return
	var capability: GameEnums.EventDataCapability = (
			GameEnums.EventDataCapability.SOURCE_UNIT
	)
	if event_unit_role == GameEnums.EventUnitRole.TARGET:
		capability = GameEnums.EventDataCapability.TARGET_UNIT
	if not BattleEventSchema.supports(event_kind, capability):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"The selected event does not provide the required Unit role."
		)


func evaluate(context: ConditionContext) -> ConditionResult:
	var battle_context: BattleConditionContext = context as BattleConditionContext
	if (
		battle_context == null
		or battle_context.battle == null
		or battle_context.event == null
	):
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)

	var event_unit_id: int = battle_context.event.source_unit_id
	if event_unit_role == GameEnums.EventUnitRole.TARGET:
		event_unit_id = battle_context.event.target_unit_id
	var owner: UnitState = battle_context.battle.get_unit(
			battle_context.actor_unit_id
	)
	var event_unit: UnitState = battle_context.battle.get_unit(event_unit_id)
	if owner == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	if event_unit == null:
		return ConditionResult.failure()
	if _relation_evaluator.matches(owner, event_unit, relation):
		return ConditionResult.success()
	return ConditionResult.failure()


func requires_actor_unit() -> bool:
	return true

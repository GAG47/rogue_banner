class_name EventUnitSideConditionDefinition
extends ConditionDefinition

@export var event_unit_role: GameEnums.EventUnitRole = (
		GameEnums.EventUnitRole.TARGET
)
@export var relation: GameEnums.SideRelation = GameEnums.SideRelation.SAME


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
				"Event Unit side conditions require an event-trigger context."
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
				"The selected event cannot provide the required Unit role."
		)


func evaluate(context: ConditionContext) -> ConditionResult:
	var battle_context: BattleConditionContext = context as BattleConditionContext
	if (
		battle_context == null
		or battle_context.battle == null
		or battle_context.event == null
		or battle_context.trigger_source == null
	):
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	var unit_id: int = battle_context.event.source_unit_id
	if event_unit_role == GameEnums.EventUnitRole.TARGET:
		unit_id = battle_context.event.target_unit_id
	if unit_id <= 0:
		return ConditionResult.failure()
	var unit: UnitState = battle_context.battle.get_unit(unit_id)
	if unit == null:
		return ConditionResult.failure()
	var same_side: bool = unit.side == battle_context.trigger_source.side
	if relation == GameEnums.SideRelation.SAME:
		return ConditionResult.success() if same_side else ConditionResult.failure()
	return ConditionResult.failure() if same_side else ConditionResult.success()


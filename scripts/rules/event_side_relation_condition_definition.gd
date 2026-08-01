class_name EventSideRelationConditionDefinition
extends ConditionDefinition

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
				"Event side relations require an event-trigger context."
		)
		return
	if not BattleEventSchema.supports(
			event_kind,
			GameEnums.EventDataCapability.SIDE
	):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"The selected event does not provide a Battle side."
		)


func evaluate(context: ConditionContext) -> ConditionResult:
	var battle_context: BattleConditionContext = context as BattleConditionContext
	if (
		battle_context == null
		or battle_context.battle == null
		or battle_context.event == null
	):
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	var event_side: GameEnums.BattleSide
	if battle_context.event is TurnStartedEvent:
		event_side = (battle_context.event as TurnStartedEvent).side
	elif battle_context.event is TurnEndedEvent:
		event_side = (battle_context.event as TurnEndedEvent).side
	else:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)

	var owner_side: GameEnums.BattleSide
	if battle_context.trigger_source != null:
		owner_side = battle_context.trigger_source.side
	else:
		var owner: UnitState = battle_context.battle.get_unit(
				battle_context.actor_unit_id
		)
		if owner == null:
			return ConditionResult.failure(
					GameEnums.ConditionStatus.INVALID_CONTEXT
			)
		owner_side = owner.side
	if battle_context.trigger_source == null and battle_context.actor_unit_id <= 0:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	var same_side: bool = owner_side == event_side
	if relation == GameEnums.SideRelation.SAME:
		return ConditionResult.success() if same_side else ConditionResult.failure()
	return ConditionResult.failure() if same_side else ConditionResult.success()

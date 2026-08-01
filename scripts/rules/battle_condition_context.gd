class_name BattleConditionContext
extends ConditionContext

var battle: BattleState
var actor_unit_id: int = 0
var targets: TargetSelection
var resolved_targets: ResolvedTargetSet
var source_art: ArtDefinition
var event: BattleEvent
var trigger_source: BattleSource


static func create(
		battle_state: BattleState,
		actor_id: int,
		target_selection: TargetSelection = null,
		art_definition: ArtDefinition = null,
	resolved_target_set: ResolvedTargetSet = null,
	battle_event: BattleEvent = null,
	source: BattleSource = null
) -> BattleConditionContext:
	var context: BattleConditionContext = BattleConditionContext.new()
	context.battle = battle_state
	context.actor_unit_id = actor_id
	context.targets = target_selection
	context.resolved_targets = resolved_target_set
	context.source_art = art_definition
	context.event = battle_event
	context.trigger_source = source
	if (
		context.trigger_source == null
		and battle_state != null
		and actor_id > 0
	):
		var actor: UnitState = battle_state.get_unit(actor_id)
		if actor != null:
			context.trigger_source = BattleSource.unit(actor_id, actor.side)
	return context

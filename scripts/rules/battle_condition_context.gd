class_name BattleConditionContext
extends ConditionContext

var battle: BattleState
var actor_unit_id: int = 0
var targets: TargetSelection
var resolved_targets: ResolvedTargetSet
var source_art: ArtDefinition
var event: BattleEvent


static func create(
		battle_state: BattleState,
		actor_id: int,
		target_selection: TargetSelection = null,
		art_definition: ArtDefinition = null,
		resolved_target_set: ResolvedTargetSet = null,
		battle_event: BattleEvent = null
) -> BattleConditionContext:
	var context: BattleConditionContext = BattleConditionContext.new()
	context.battle = battle_state
	context.actor_unit_id = actor_id
	context.targets = target_selection
	context.resolved_targets = resolved_target_set
	context.source_art = art_definition
	context.event = battle_event
	return context

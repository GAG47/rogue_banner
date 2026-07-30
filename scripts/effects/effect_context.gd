class_name EffectContext
extends RefCounted

var battle: BattleState
var actor_unit_id: int = 0
var targets: TargetSelection
var resolved_targets: ResolvedTargetSet
var source_art: ArtDefinition
var event: BattleEvent


static func create(
		battle_state: BattleState,
	actor_id: int,
	target_selection: TargetSelection,
	art_definition: ArtDefinition = null,
	resolved_target_set: ResolvedTargetSet = null,
	source_event: BattleEvent = null
) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.battle = battle_state
	context.actor_unit_id = actor_id
	context.targets = target_selection
	context.resolved_targets = resolved_target_set
	if context.resolved_targets == null:
		context.resolved_targets = ResolvedTargetSet.from_selection(
				target_selection
		)
	context.source_art = art_definition
	context.event = source_event
	return context

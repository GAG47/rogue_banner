class_name BattleTargetingContext
extends TargetingContext

var battle: BattleState
var actor_unit_id: int = 0
var submitted_selection: TargetSelection


static func create(
		battle_state: BattleState,
		actor_id: int,
		selection: TargetSelection
) -> BattleTargetingContext:
	var context: BattleTargetingContext = BattleTargetingContext.new()
	context.battle = battle_state
	context.actor_unit_id = actor_id
	context.submitted_selection = selection
	return context

class_name EnemyDecisionContext
extends ConditionContext

var battle: BattleState
var actor_unit_id: int = 0


static func create(
		battle_state: BattleState,
		actor_id: int
) -> EnemyDecisionContext:
	var context: EnemyDecisionContext = EnemyDecisionContext.new()
	context.battle = battle_state
	context.actor_unit_id = actor_id
	return context

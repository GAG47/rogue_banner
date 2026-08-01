class_name RewardGenerationContext
extends ConditionContext

var run: RunState
var source: GameEnums.RewardSource = GameEnums.RewardSource.BATTLE
var floor_number: int = 1
var battle_rank: GameEnums.EnemyRank = GameEnums.EnemyRank.STANDARD
var generation_index: int = 0


static func create(
		run_state: RunState,
		reward_source: GameEnums.RewardSource,
		floor: int,
		rank: GameEnums.EnemyRank,
		index: int
) -> RewardGenerationContext:
	var context: RewardGenerationContext = RewardGenerationContext.new()
	context.run = run_state
	context.source = reward_source
	context.floor_number = floor
	context.battle_rank = rank
	context.generation_index = index
	return context


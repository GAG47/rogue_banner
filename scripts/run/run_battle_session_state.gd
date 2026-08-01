class_name RunBattleSessionState
extends RefCounted

var battle_session_id: int = 0
var participant_run_unit_ids: Array[int] = []
var scroll_stack_ids: Array[int] = []
var floor_number: int = 1
var battle_rank: GameEnums.EnemyRank = GameEnums.EnemyRank.STANDARD
var reward_pool: RewardPoolDefinition


func duplicate_state() -> RunBattleSessionState:
	var state: RunBattleSessionState = RunBattleSessionState.new()
	state.battle_session_id = battle_session_id
	state.participant_run_unit_ids.assign(participant_run_unit_ids)
	state.scroll_stack_ids.assign(scroll_stack_ids)
	state.floor_number = floor_number
	state.battle_rank = battle_rank
	state.reward_pool = reward_pool
	return state

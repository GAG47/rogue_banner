class_name BattleRelicState
extends RefCounted

var instance_id: int = 0
var source_run_relic_id: int = 0
var definition: RelicDefinition
var side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER


static func create(
		runtime_id: int,
		run_relic_id: int,
		relic_definition: RelicDefinition,
		owner_side: GameEnums.BattleSide
) -> BattleRelicState:
	if (
		runtime_id <= 0
		or run_relic_id <= 0
		or relic_definition == null
	):
		return null
	var state: BattleRelicState = BattleRelicState.new()
	state.instance_id = runtime_id
	state.source_run_relic_id = run_relic_id
	state.definition = relic_definition
	state.side = owner_side
	return state


func duplicate_state() -> BattleRelicState:
	return BattleRelicState.create(
			instance_id,
			source_run_relic_id,
			definition,
			side
	)


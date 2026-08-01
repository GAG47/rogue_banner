class_name MapNodeSessionState
extends RefCounted

var session_id: int = 0
var node_instance_id: int = 0
var stage: GameEnums.MapSessionStage = (
	GameEnums.MapSessionStage.PREPARING_BATTLE
)
var battle_session_id: int = 0
var offer_id: int = 0
var event_session: MapEventSessionState


func duplicate_state() -> MapNodeSessionState:
	var state: MapNodeSessionState = MapNodeSessionState.new()
	state.session_id = session_id
	state.node_instance_id = node_instance_id
	state.stage = stage
	state.battle_session_id = battle_session_id
	state.offer_id = offer_id
	state.event_session = (
		event_session.duplicate_state() if event_session != null else null
	)
	return state

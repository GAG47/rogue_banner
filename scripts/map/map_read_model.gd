class_name MapReadModel
extends RefCounted

var nodes: Array[MapNodeState] = []
var connections: Array[MapConnection] = []
var current_node_id: int = 0
var current_layer: int = 0
var reachable_node_ids: Array[int] = []
var visible_node_ids: Array[int] = []
var active_session: MapNodeSessionState


static func create(map_state: MapState) -> MapReadModel:
	if map_state == null or not map_state.is_valid():
		return null
	var model: MapReadModel = MapReadModel.new()
	model.nodes.assign(map_state.get_nodes())
	model.connections.assign(map_state.get_connections())
	model.current_node_id = map_state.get_current_node_id()
	model.current_layer = map_state.get_current_layer()
	model.reachable_node_ids.assign(map_state.get_reachable_node_ids())
	model.visible_node_ids.assign(map_state.get_visible_node_ids())
	model.active_session = map_state.get_active_session()
	return model

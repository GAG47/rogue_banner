class_name MapNodeState
extends RefCounted

var instance_id: int = 0
var layer_index: int = 0
var column_index: int = 0
var definition: MapNodeDefinition
var status: GameEnums.MapNodeStatus = GameEnums.MapNodeStatus.UNVISITED


static func create(
	node_instance_id: int,
	node_layer: int,
	node_column: int,
	node_definition: MapNodeDefinition
) -> MapNodeState:
	if node_instance_id <= 0 or node_layer < 0 or node_definition == null:
		return null
	var state: MapNodeState = MapNodeState.new()
	state.instance_id = node_instance_id
	state.layer_index = node_layer
	state.column_index = node_column
	state.definition = node_definition
	return state


func duplicate_state() -> MapNodeState:
	var state: MapNodeState = MapNodeState.new()
	state.instance_id = instance_id
	state.layer_index = layer_index
	state.column_index = column_index
	state.definition = definition
	state.status = status
	return state

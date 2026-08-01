class_name MapConnection
extends RefCounted

var from_node_id: int = 0
var to_node_id: int = 0


static func create(source_id: int, destination_id: int) -> MapConnection:
	if source_id <= 0 or destination_id <= 0 or source_id == destination_id:
		return null
	var connection: MapConnection = MapConnection.new()
	connection.from_node_id = source_id
	connection.to_node_id = destination_id
	return connection


func duplicate_state() -> MapConnection:
	return MapConnection.create(from_node_id, to_node_id)

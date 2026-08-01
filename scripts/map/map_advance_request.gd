class_name MapAdvanceRequest
extends RefCounted

var destination_node_id: int = 0


static func create(node_instance_id: int) -> MapAdvanceRequest:
	var request: MapAdvanceRequest = MapAdvanceRequest.new()
	request.destination_node_id = node_instance_id
	return request

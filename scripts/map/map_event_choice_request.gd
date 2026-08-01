class_name MapEventChoiceRequest
extends RefCounted

var choice_id: StringName = &""


static func create(selected_choice_id: StringName) -> MapEventChoiceRequest:
	var request: MapEventChoiceRequest = MapEventChoiceRequest.new()
	request.choice_id = selected_choice_id
	return request

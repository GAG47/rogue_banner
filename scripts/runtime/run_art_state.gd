class_name RunArtState
extends RefCounted

var instance_id: int = 0
var definition: ArtDefinition


static func create(
		art_instance_id: int,
		art_definition: ArtDefinition
) -> RunArtState:
	if art_instance_id <= 0 or art_definition == null:
		return null
	var state: RunArtState = RunArtState.new()
	state.instance_id = art_instance_id
	state.definition = art_definition
	return state


func duplicate_state() -> RunArtState:
	return RunArtState.create(instance_id, definition)


class_name ArtState
extends RefCounted

var definition: ArtDefinition
var current_cooldown: int = 0


static func create(art_definition: ArtDefinition) -> ArtState:
	var state: ArtState = ArtState.new()
	state.definition = art_definition
	return state


func duplicate_state() -> ArtState:
	var state: ArtState = ArtState.new()
	state._copy_from(self)
	return state


func _copy_from(source: ArtState) -> void:
	if source == null:
		return
	definition = source.definition
	current_cooldown = source.current_cooldown


func advance_cooldown() -> void:
	if current_cooldown > 0:
		current_cooldown -= 1

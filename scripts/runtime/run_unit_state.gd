class_name RunUnitState
extends RefCounted

var instance_id: int = 0
var definition: UnitDefinition
var current_health: int = 0
var installed_arts: Array[ArtDefinition] = []


static func create(
		unit_instance_id: int,
		unit_definition: UnitDefinition
) -> RunUnitState:
	var state: RunUnitState = RunUnitState.new()
	state.instance_id = unit_instance_id
	state.definition = unit_definition

	if unit_definition == null:
		return state

	state.current_health = unit_definition.max_health
	for art_definition: ArtDefinition in unit_definition.default_arts:
		if art_definition != null:
			state.installed_arts.append(art_definition)
	return state


func is_defeated() -> bool:
	return current_health <= 0

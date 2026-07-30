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
	for slot_index: int in range(unit_definition.slot_count):
		var art_definition: ArtDefinition
		if slot_index < unit_definition.default_arts.size():
			art_definition = unit_definition.default_arts[slot_index]
		state.installed_arts.append(art_definition)
	return state


func is_defeated() -> bool:
	return current_health <= 0

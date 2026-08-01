class_name RunUnitState
extends RefCounted

var instance_id: int = 0
var definition: UnitDefinition
var current_health: int = 0
var installed_art_instance_ids: Array[int] = []


static func create(
		unit_instance_id: int,
		unit_definition: UnitDefinition
) -> RunUnitState:
	if unit_definition == null:
		return null
	var validator: DefinitionValidator = DefinitionValidator.new()
	if not validator.validate(unit_definition).is_valid():
		return null
	return create_empty(unit_instance_id, unit_definition)


static func create_empty(
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
		state.installed_art_instance_ids.append(0)
	return state


func is_defeated() -> bool:
	return current_health <= 0


func duplicate_state() -> RunUnitState:
	var state: RunUnitState = RunUnitState.new()
	state.instance_id = instance_id
	state.definition = definition
	state.current_health = current_health
	state.installed_art_instance_ids.assign(installed_art_instance_ids)
	return state

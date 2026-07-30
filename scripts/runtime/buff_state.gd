class_name BuffState
extends RefCounted

var instance_id: int = 0
var definition: BuffDefinition
var source_unit_id: int = 0
var stacks: int = 1
var remaining_turns: int = 0


static func create(
		buff_instance_id: int,
		buff_definition: BuffDefinition,
		source_id: int
) -> BuffState:
	var state: BuffState = BuffState.new()
	state.instance_id = buff_instance_id
	state.definition = buff_definition
	state.source_unit_id = source_id
	if buff_definition != null:
		state.remaining_turns = buff_definition.duration_turns
	return state

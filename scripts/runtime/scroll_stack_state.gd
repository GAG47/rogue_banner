class_name ScrollStackState
extends RefCounted

var instance_id: int = 0
var definition: ScrollDefinition
var quantity: int = 0


static func create(
		stack_instance_id: int,
		scroll_definition: ScrollDefinition,
		initial_quantity: int
) -> ScrollStackState:
	if (
		stack_instance_id <= 0
		or scroll_definition == null
		or initial_quantity <= 0
		or initial_quantity > scroll_definition.max_stack_size
	):
		return null
	var state: ScrollStackState = ScrollStackState.new()
	state.instance_id = stack_instance_id
	state.definition = scroll_definition
	state.quantity = initial_quantity
	return state


func duplicate_state() -> ScrollStackState:
	return ScrollStackState.create(instance_id, definition, quantity)

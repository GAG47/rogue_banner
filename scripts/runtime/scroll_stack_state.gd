class_name ScrollStackState
extends RefCounted

var definition: ScrollDefinition
var quantity: int = 0


static func create(
		scroll_definition: ScrollDefinition,
		initial_quantity: int
) -> ScrollStackState:
	var state: ScrollStackState = ScrollStackState.new()
	state.definition = scroll_definition
	state.quantity = initial_quantity
	return state

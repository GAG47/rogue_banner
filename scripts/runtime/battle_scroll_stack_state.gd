class_name BattleScrollStackState
extends RefCounted

var instance_id: int = 0
var source_run_stack_id: int = 0
var definition: ScrollDefinition
var initial_quantity: int = 0
var quantity: int = 0


static func create(
		runtime_stack_id: int,
		run_stack_id: int,
		scroll_definition: ScrollDefinition,
		stack_quantity: int
) -> BattleScrollStackState:
	if (
		runtime_stack_id <= 0
		or run_stack_id <= 0
		or scroll_definition == null
		or stack_quantity <= 0
		or stack_quantity > scroll_definition.max_stack_size
	):
		return null
	var state: BattleScrollStackState = BattleScrollStackState.new()
	state.instance_id = runtime_stack_id
	state.source_run_stack_id = run_stack_id
	state.definition = scroll_definition
	state.initial_quantity = stack_quantity
	state.quantity = stack_quantity
	return state


func duplicate_state() -> BattleScrollStackState:
	var state: BattleScrollStackState = BattleScrollStackState.create(
			instance_id,
			source_run_stack_id,
			definition,
			initial_quantity
	)
	if state != null:
		state.quantity = quantity
	return state


func consume_one() -> bool:
	if quantity <= 0:
		return false
	quantity -= 1
	return true


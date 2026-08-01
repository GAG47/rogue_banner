class_name BattleScrollOutcome
extends RefCounted

var source_run_stack_id: int = 0
var initial_quantity: int = 0
var remaining_quantity: int = 0


static func create(
		run_stack_id: int,
		initial: int,
		remaining: int
) -> BattleScrollOutcome:
	var outcome: BattleScrollOutcome = BattleScrollOutcome.new()
	outcome.source_run_stack_id = run_stack_id
	outcome.initial_quantity = initial
	outcome.remaining_quantity = remaining
	return outcome


func consumed_quantity() -> int:
	return initial_quantity - remaining_quantity


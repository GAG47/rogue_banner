class_name BattleUnitOutcome
extends RefCounted

var source_run_unit_id: int = 0
var remaining_health: int = 0
var defeated: bool = false


static func create(
		run_unit_id: int,
		health: int
) -> BattleUnitOutcome:
	var outcome: BattleUnitOutcome = BattleUnitOutcome.new()
	outcome.source_run_unit_id = run_unit_id
	outcome.remaining_health = maxi(0, health)
	outcome.defeated = outcome.remaining_health == 0
	return outcome


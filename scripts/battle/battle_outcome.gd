class_name BattleOutcome
extends RefCounted

var battle_session_id: int = 0
var final_phase: GameEnums.BattlePhase = GameEnums.BattlePhase.FAILURE
var final_round_number: int = 0
var unit_outcomes: Array[BattleUnitOutcome] = []
var scroll_outcomes: Array[BattleScrollOutcome] = []


func is_victory() -> bool:
	return final_phase == GameEnums.BattlePhase.VICTORY


func is_terminal() -> bool:
	return (
		final_phase == GameEnums.BattlePhase.VICTORY
		or final_phase == GameEnums.BattlePhase.FAILURE
	)


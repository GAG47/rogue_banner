class_name BattleEndedEvent
extends BattleEvent

var final_phase: GameEnums.BattlePhase = GameEnums.BattlePhase.FAILURE
var final_round_number: int = 0


static func create(
		phase: GameEnums.BattlePhase,
		round: int
) -> BattleEndedEvent:
	var event: BattleEndedEvent = BattleEndedEvent.new()
	event.kind = GameEnums.BattleEventKind.BATTLE_ENDED
	event.final_phase = phase
	event.final_round_number = round
	return event

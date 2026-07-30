class_name TurnEndedEvent
extends BattleEvent

var side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var round_number: int = 0


static func create(
		ended_side: GameEnums.BattleSide,
		round: int
) -> TurnEndedEvent:
	var event: TurnEndedEvent = TurnEndedEvent.new()
	event.kind = GameEnums.BattleEventKind.TURN_ENDED
	event.side = ended_side
	event.round_number = round
	return event

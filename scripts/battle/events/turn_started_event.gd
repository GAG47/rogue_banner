class_name TurnStartedEvent
extends BattleEvent

var side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var round_number: int = 0


static func create(
		active_side: GameEnums.BattleSide,
		round: int
) -> TurnStartedEvent:
	var event: TurnStartedEvent = TurnStartedEvent.new()
	event.kind = GameEnums.BattleEventKind.TURN_STARTED
	event.side = active_side
	event.round_number = round
	return event

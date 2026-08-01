class_name UnitDefeatedEvent
extends BattleEvent


static func create(
		event_source: BattleSource,
		defeated_unit_id: int
) -> UnitDefeatedEvent:
	var event: UnitDefeatedEvent = UnitDefeatedEvent.new()
	event.kind = GameEnums.BattleEventKind.UNIT_DEFEATED
	event.source = event_source
	event.target_unit_id = defeated_unit_id
	return event

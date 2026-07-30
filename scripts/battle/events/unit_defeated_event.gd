class_name UnitDefeatedEvent
extends BattleEvent


static func create(source_id: int, defeated_unit_id: int) -> UnitDefeatedEvent:
	var event: UnitDefeatedEvent = UnitDefeatedEvent.new()
	event.kind = GameEnums.BattleEventKind.UNIT_DEFEATED
	event.source_unit_id = source_id
	event.target_unit_id = defeated_unit_id
	return event

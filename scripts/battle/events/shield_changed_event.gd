class_name ShieldChangedEvent
extends BattleEvent

var previous_shield: int = 0
var current_shield: int = 0


static func create(
		source_id: int,
		target_id: int,
		previous_value: int,
		current_value: int
) -> ShieldChangedEvent:
	var event: ShieldChangedEvent = ShieldChangedEvent.new()
	event.kind = GameEnums.BattleEventKind.SHIELD_CHANGED
	event.source_unit_id = source_id
	event.target_unit_id = target_id
	event.previous_shield = previous_value
	event.current_shield = current_value
	return event

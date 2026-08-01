class_name HealingAppliedEvent
extends BattleEvent

var requested_amount: int = 0
var restored_health: int = 0


static func create(
		event_source: BattleSource,
		target_id: int,
		requested: int,
		restored: int
) -> HealingAppliedEvent:
	var event: HealingAppliedEvent = HealingAppliedEvent.new()
	event.kind = GameEnums.BattleEventKind.HEALING_APPLIED
	event.source = event_source
	event.target_unit_id = target_id
	event.requested_amount = requested
	event.restored_health = restored
	return event

class_name HealingAppliedEvent
extends BattleEvent

var requested_amount: int = 0
var restored_health: int = 0


static func create(
		source_id: int,
		target_id: int,
		requested: int,
		restored: int
) -> HealingAppliedEvent:
	var event: HealingAppliedEvent = HealingAppliedEvent.new()
	event.kind = GameEnums.BattleEventKind.HEALING_APPLIED
	event.source_unit_id = source_id
	event.target_unit_id = target_id
	event.requested_amount = requested
	event.restored_health = restored
	return event

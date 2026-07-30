class_name DamageAppliedEvent
extends BattleEvent

var requested_amount: int = 0
var health_damage: int = 0
var shield_absorbed: int = 0


static func create(
		source_id: int,
		target_id: int,
		requested: int,
		applied_to_health: int,
		absorbed_by_shield: int
) -> DamageAppliedEvent:
	var event: DamageAppliedEvent = DamageAppliedEvent.new()
	event.kind = GameEnums.BattleEventKind.DAMAGE_APPLIED
	event.source_unit_id = source_id
	event.target_unit_id = target_id
	event.requested_amount = requested
	event.health_damage = applied_to_health
	event.shield_absorbed = absorbed_by_shield
	return event

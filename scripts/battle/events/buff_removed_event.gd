class_name BuffRemovedEvent
extends BattleEvent

var buff_definition: BuffDefinition


static func create(
		event_source: BattleSource,
		target_id: int,
		definition: BuffDefinition
) -> BuffRemovedEvent:
	var event: BuffRemovedEvent = BuffRemovedEvent.new()
	event.kind = GameEnums.BattleEventKind.BUFF_REMOVED
	event.source = event_source
	event.target_unit_id = target_id
	event.buff_definition = definition
	return event

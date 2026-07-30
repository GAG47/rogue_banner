class_name BuffRemovedEvent
extends BattleEvent

var buff_definition: BuffDefinition


static func create(
		source_id: int,
		target_id: int,
		definition: BuffDefinition
) -> BuffRemovedEvent:
	var event: BuffRemovedEvent = BuffRemovedEvent.new()
	event.kind = GameEnums.BattleEventKind.BUFF_REMOVED
	event.source_unit_id = source_id
	event.target_unit_id = target_id
	event.buff_definition = definition
	return event

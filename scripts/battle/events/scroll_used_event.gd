class_name ScrollUsedEvent
extends BattleEvent

var scroll_definition: ScrollDefinition
var scroll_stack_instance_id: int = 0


static func create(
		event_source: BattleSource,
		definition: ScrollDefinition,
		stack_instance_id: int
) -> ScrollUsedEvent:
	var event: ScrollUsedEvent = ScrollUsedEvent.new()
	event.kind = GameEnums.BattleEventKind.SCROLL_USED
	event.source = event_source
	event.target_unit_id = (
		event_source.acting_unit_id if event_source != null else 0
	)
	event.scroll_definition = definition
	event.scroll_stack_instance_id = stack_instance_id
	return event

class_name ArtUsedEvent
extends BattleEvent

var art_definition: ArtDefinition
var art_slot_index: int = -1


static func create(
		event_source: BattleSource,
		definition: ArtDefinition,
		slot_index: int
) -> ArtUsedEvent:
	var event: ArtUsedEvent = ArtUsedEvent.new()
	event.kind = GameEnums.BattleEventKind.ART_USED
	event.source = event_source
	event.target_unit_id = (
		event_source.acting_unit_id if event_source != null else 0
	)
	event.art_definition = definition
	event.art_slot_index = slot_index
	return event

class_name ArtUsedEvent
extends BattleEvent

var art_definition: ArtDefinition
var art_slot_index: int = -1


static func create(
		unit_id: int,
		definition: ArtDefinition,
		slot_index: int
) -> ArtUsedEvent:
	var event: ArtUsedEvent = ArtUsedEvent.new()
	event.kind = GameEnums.BattleEventKind.ART_USED
	event.source_unit_id = unit_id
	event.target_unit_id = unit_id
	event.art_definition = definition
	event.art_slot_index = slot_index
	return event

class_name UnitMovedEvent
extends BattleEvent

var origin: Vector2i
var destination: Vector2i
var path: Array[Vector2i] = []


static func create(
		unit_id: int,
		from_coordinate: Vector2i,
		to_coordinate: Vector2i,
		movement_path: Array[Vector2i]
) -> UnitMovedEvent:
	var event: UnitMovedEvent = UnitMovedEvent.new()
	event.kind = GameEnums.BattleEventKind.UNIT_MOVED
	event.source_unit_id = unit_id
	event.target_unit_id = unit_id
	event.origin = from_coordinate
	event.destination = to_coordinate
	event.path.assign(movement_path)
	return event

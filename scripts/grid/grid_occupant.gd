class_name GridOccupant
extends RefCounted

var _kind: GameEnums.GridOccupantKind
var _runtime_id: int

var kind: GameEnums.GridOccupantKind:
	get:
		return _kind

var runtime_id: int:
	get:
		return _runtime_id


func _init(
		occupant_kind: GameEnums.GridOccupantKind,
		occupant_runtime_id: int
) -> void:
	_kind = occupant_kind
	_runtime_id = occupant_runtime_id


static func unit(unit_id: int) -> GridOccupant:
	return GridOccupant.new(GameEnums.GridOccupantKind.UNIT, unit_id)


static func scene_object(scene_object_id: int) -> GridOccupant:
	return GridOccupant.new(
			GameEnums.GridOccupantKind.SCENE_OBJECT,
			scene_object_id
	)


func is_valid() -> bool:
	return _runtime_id > 0


func matches(other: GridOccupant) -> bool:
	return (
			other != null
			and _kind == other.kind
			and _runtime_id == other.runtime_id
	)

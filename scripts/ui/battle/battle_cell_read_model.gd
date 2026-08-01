class_name BattleCellReadModel
extends RefCounted

var coordinate: Vector2i = Vector2i.ZERO
var terrain_name: String = ""
var movement_cost: int = 0
var blocks_movement: bool = false
var blocks_line_of_sight: bool = false
var occupant_kind: int = -1
var occupant_runtime_id: int = 0


func has_occupant() -> bool:
	return occupant_runtime_id > 0


func has_unit() -> bool:
	return (
		has_occupant()
		and occupant_kind == GameEnums.GridOccupantKind.UNIT
	)


func has_scene_object() -> bool:
	return (
		has_occupant()
		and occupant_kind == GameEnums.GridOccupantKind.SCENE_OBJECT
	)

class_name TargetSelection
extends RefCounted

var unit_instance_ids: Array[int] = []
var cells: Array[Vector2i] = []
var terrain_object_instance_ids: Array[int] = []
var targets_battle: bool = false


func count() -> int:
	return (
			unit_instance_ids.size()
			+ cells.size()
			+ terrain_object_instance_ids.size()
			+ int(targets_battle)
	)

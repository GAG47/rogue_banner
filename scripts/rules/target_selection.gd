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


func duplicate_selection() -> TargetSelection:
	var selection: TargetSelection = TargetSelection.new()
	selection.unit_instance_ids.assign(unit_instance_ids)
	selection.cells.assign(cells)
	selection.terrain_object_instance_ids.assign(terrain_object_instance_ids)
	selection.targets_battle = targets_battle
	return selection

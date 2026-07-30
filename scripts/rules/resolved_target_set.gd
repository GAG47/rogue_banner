class_name ResolvedTargetSet
extends RefCounted

var selection: TargetSelection
var aim_cells: Array[Vector2i] = []
var affected_cells: Array[Vector2i] = []
var hit_unit_ids: Array[int] = []
var hit_object_ids: Array[int] = []


static func from_selection(
	target_selection: TargetSelection
) -> ResolvedTargetSet:
	var result: ResolvedTargetSet = ResolvedTargetSet.new()
	if target_selection == null:
		result.selection = TargetSelection.new()
		return result
	result.selection = target_selection.duplicate_selection()
	result.aim_cells.assign(result.selection.cells)
	result.affected_cells.assign(result.selection.cells)
	result.hit_unit_ids.assign(result.selection.unit_instance_ids)
	result.hit_object_ids.assign(result.selection.terrain_object_instance_ids)
	return result


func hit_count(kind: GameEnums.HitTargetKind) -> int:
	match kind:
		GameEnums.HitTargetKind.UNIT:
			return hit_unit_ids.size()
		GameEnums.HitTargetKind.SCENE_OBJECT:
			return hit_object_ids.size()
		GameEnums.HitTargetKind.ANY:
			return hit_unit_ids.size() + hit_object_ids.size()
	return 0


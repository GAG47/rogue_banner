class_name BattleTargetResolver
extends TargetResolver

var _line_of_sight: GridLineOfSight
var _relation_evaluator: UnitRelationEvaluator


func _init(line_of_sight: GridLineOfSight = null) -> void:
	_line_of_sight = line_of_sight
	if _line_of_sight == null:
		_line_of_sight = GridLineOfSight.new()
	_relation_evaluator = UnitRelationEvaluator.new()


func resolve(
	definition: TargetingDefinition,
	context: TargetingContext,
	selection: TargetSelection
) -> TargetResolutionResult:
	var battle_context: BattleTargetingContext = context as BattleTargetingContext
	if (
		definition == null
		or battle_context == null
		or battle_context.battle == null
		or battle_context.battle.grid == null
		or selection == null
	):
		return TargetResolutionResult.rejected(
				GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		)

	var battle: BattleState = battle_context.battle
	var actor: UnitState = battle.get_unit(battle_context.actor_unit_id)
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			battle_context.actor_unit_id
	)
	if actor == null or actor_position == null:
		return TargetResolutionResult.rejected(
				GameEnums.ActionFailureCode.ACTOR_NOT_PLACED
		)
	if (
		selection.count() < definition.minimum_targets
		or selection.count() > definition.maximum_targets
		or not _matches_target_kind(definition.target_kind, selection)
		or _has_duplicates(selection)
	):
		return TargetResolutionResult.rejected(
				GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		)

	var resolved: ResolvedTargetSet = ResolvedTargetSet.from_selection(selection)
	var aim_failure: GameEnums.ActionFailureCode = _resolve_aim_cells(
			battle,
			actor,
			definition,
			selection,
			resolved.aim_cells
	)
	if aim_failure != GameEnums.ActionFailureCode.NONE:
		return TargetResolutionResult.rejected(aim_failure)

	for coordinate: Vector2i in resolved.aim_cells:
		var range_failure: GameEnums.ActionFailureCode = _validate_aim_coordinate(
				battle.grid,
				actor_position.value,
				coordinate,
				definition
		)
		if range_failure != GameEnums.ActionFailureCode.NONE:
			return TargetResolutionResult.rejected(range_failure)

	_resolve_affected_cells(
			battle.grid,
			resolved.aim_cells,
			definition.affected_offsets,
			selection,
			resolved.affected_cells
	)
	_resolve_hits(battle, actor, definition, resolved)
	return TargetResolutionResult.accepted(resolved)


func find_range_cells(
	definition: TargetingDefinition,
	battle: BattleState,
	actor_unit_id: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if definition == null or battle == null or battle.grid == null:
		return result
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			actor_unit_id
	)
	if actor_position == null:
		return result
	for y: int in range(battle.grid.height):
		for x: int in range(battle.grid.width):
			var coordinate: Vector2i = Vector2i(x, y)
			if (
				_validate_aim_coordinate(
						battle.grid,
						actor_position.value,
						coordinate,
						definition
				) == GameEnums.ActionFailureCode.NONE
			):
				result.append(coordinate)
	return result


func _resolve_aim_cells(
	battle: BattleState,
	actor: UnitState,
	definition: TargetingDefinition,
	selection: TargetSelection,
	aim_cells: Array[Vector2i]
) -> GameEnums.ActionFailureCode:
	aim_cells.clear()
	for unit_id: int in selection.unit_instance_ids:
		var target: UnitState = battle.get_unit(unit_id)
		if target == null or target.is_defeated():
			return GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		if not _relation_evaluator.matches(
			actor,
			target,
			definition.target_relation
		):
			return GameEnums.ActionFailureCode.TARGET_RELATION_INVALID
		var position: GridCoordinate = battle.grid.find_occupant(
				GameEnums.GridOccupantKind.UNIT,
				unit_id
		)
		if position == null:
			return GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		aim_cells.append(position.value)

	for coordinate: Vector2i in selection.cells:
		if not battle.grid.is_in_bounds(coordinate):
			return GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		aim_cells.append(coordinate)

	for object_id: int in selection.terrain_object_instance_ids:
		if (
			definition.target_relation != GameEnums.TargetRelation.NEUTRAL
			and definition.target_relation != GameEnums.TargetRelation.ANY
		):
			return GameEnums.ActionFailureCode.TARGET_RELATION_INVALID
		var object_position: GridCoordinate = battle.grid.find_occupant(
				GameEnums.GridOccupantKind.SCENE_OBJECT,
				object_id
		)
		if object_position == null:
			return GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
		aim_cells.append(object_position.value)

	if selection.targets_battle:
		if definition.target_relation != GameEnums.TargetRelation.ANY:
			return GameEnums.ActionFailureCode.TARGET_RELATION_INVALID
	return GameEnums.ActionFailureCode.NONE


func _validate_aim_coordinate(
	grid: GridState,
	actor_coordinate: Vector2i,
	aim_coordinate: Vector2i,
	definition: TargetingDefinition
) -> GameEnums.ActionFailureCode:
	if not grid.is_in_bounds(aim_coordinate):
		return GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
	var distance: int = grid.get_distance(actor_coordinate, aim_coordinate)
	if distance < definition.minimum_range or distance > definition.maximum_range:
		return GameEnums.ActionFailureCode.TARGET_OUT_OF_RANGE
	if (
		definition.requires_line_of_sight
		and not _line_of_sight.has_line_of_sight(
				grid,
				actor_coordinate,
				aim_coordinate
		)
	):
		return GameEnums.ActionFailureCode.LINE_OF_SIGHT_BLOCKED
	return GameEnums.ActionFailureCode.NONE


func _resolve_affected_cells(
	grid: GridState,
	aim_cells: Array[Vector2i],
	offsets: Array[Vector2i],
	selection: TargetSelection,
	affected_cells: Array[Vector2i]
) -> void:
	affected_cells.clear()
	for aim_cell: Vector2i in aim_cells:
		for offset: Vector2i in offsets:
			var resolved_offset: Vector2i = offset
			if selection != null and selection.has_orientation:
				resolved_offset = GridDirection.rotate_from_right(
						offset,
						selection.orientation
				)
			var coordinate: Vector2i = aim_cell + resolved_offset
			if (
				grid.is_in_bounds(coordinate)
				and not affected_cells.has(coordinate)
			):
				affected_cells.append(coordinate)


func _resolve_hits(
	battle: BattleState,
	actor: UnitState,
	definition: TargetingDefinition,
	resolved: ResolvedTargetSet
) -> void:
	resolved.hit_unit_ids.clear()
	resolved.hit_object_ids.clear()
	for coordinate: Vector2i in resolved.affected_cells:
		var occupant: GridOccupant = battle.grid.get_occupant(coordinate)
		if occupant == null:
			continue
		if occupant.kind == GameEnums.GridOccupantKind.UNIT:
			var target: UnitState = battle.get_unit(occupant.runtime_id)
			if (
				target != null
				and not target.is_defeated()
				and _relation_evaluator.matches(
						actor,
						target,
						definition.target_relation
				)
				and not resolved.hit_unit_ids.has(target.instance_id)
			):
				resolved.hit_unit_ids.append(target.instance_id)
		elif (
			occupant.kind == GameEnums.GridOccupantKind.SCENE_OBJECT
			and (
				definition.target_relation == GameEnums.TargetRelation.NEUTRAL
				or definition.target_relation == GameEnums.TargetRelation.ANY
			)
			and not resolved.hit_object_ids.has(occupant.runtime_id)
		):
			resolved.hit_object_ids.append(occupant.runtime_id)


func _matches_target_kind(
	target_kind: GameEnums.TargetKind,
	selection: TargetSelection
) -> bool:
	match target_kind:
		GameEnums.TargetKind.UNIT:
			return (
				not selection.unit_instance_ids.is_empty()
				and selection.cells.is_empty()
				and selection.terrain_object_instance_ids.is_empty()
				and not selection.targets_battle
			)
		GameEnums.TargetKind.CELL:
			return (
				selection.unit_instance_ids.is_empty()
				and not selection.cells.is_empty()
				and selection.terrain_object_instance_ids.is_empty()
				and not selection.targets_battle
			)
		GameEnums.TargetKind.TERRAIN_OBJECT:
			return (
				selection.unit_instance_ids.is_empty()
				and selection.cells.is_empty()
				and not selection.terrain_object_instance_ids.is_empty()
				and not selection.targets_battle
			)
		GameEnums.TargetKind.BATTLE:
			return selection.count() == 1 and selection.targets_battle
	return false


func _has_duplicates(selection: TargetSelection) -> bool:
	var seen_unit_ids: Dictionary[int, bool] = {}
	for unit_id: int in selection.unit_instance_ids:
		if seen_unit_ids.has(unit_id):
			return true
		seen_unit_ids[unit_id] = true

	var seen_cells: Dictionary[Vector2i, bool] = {}
	for coordinate: Vector2i in selection.cells:
		if seen_cells.has(coordinate):
			return true
		seen_cells[coordinate] = true

	var seen_object_ids: Dictionary[int, bool] = {}
	for object_id: int in selection.terrain_object_instance_ids:
		if seen_object_ids.has(object_id):
			return true
		seen_object_ids[object_id] = true
	return false

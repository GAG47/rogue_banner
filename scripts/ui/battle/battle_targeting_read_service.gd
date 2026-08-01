class_name BattleTargetingReadService
extends RefCounted

var _target_resolver: BattleTargetResolver = BattleTargetResolver.new()


func find_range_cells(
		battle: BattleState,
		actor_unit_id: int,
		art_slot_index: int
) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	var art_state: ArtState = get_art_state(
		battle,
		actor_unit_id,
		art_slot_index
	)
	if art_state == null or art_state.definition.targeting == null:
		return result
	for coordinate: Vector2i in _target_resolver.find_range_cells(
		art_state.definition.targeting,
		battle,
		actor_unit_id
	):
		result[coordinate] = true
	return result


func find_targetable_cells(
		battle: BattleState,
		action_service: BattleActionService,
		actor_unit_id: int,
		art_slot_index: int
) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	if battle == null or battle.grid == null or action_service == null:
		return result
	var actor: UnitState = battle.get_unit(actor_unit_id)
	if actor == null:
		return result
	for y: int in range(battle.grid.height):
		for x: int in range(battle.grid.width):
			var coordinate: Vector2i = Vector2i(x, y)
			var selection: TargetSelection = selection_for_coordinate(
				battle,
				actor_unit_id,
				art_slot_index,
				coordinate
			)
			if selection == null:
				continue
			var request: UseArtActionRequest = UseArtActionRequest.create(
				actor.side,
				actor_unit_id,
				art_slot_index,
				selection
			)
			if action_service.validate(battle, request).is_valid:
				result[coordinate] = true
	return result


func find_affected_cells(
		battle: BattleState,
		actor_unit_id: int,
		art_slot_index: int,
		coordinate: Vector2i
) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	var art_state: ArtState = get_art_state(
		battle,
		actor_unit_id,
		art_slot_index
	)
	var selection: TargetSelection = selection_for_coordinate(
		battle,
		actor_unit_id,
		art_slot_index,
		coordinate
	)
	if (
		art_state == null
		or art_state.definition == null
		or art_state.definition.targeting == null
		or selection == null
	):
		return result
	var resolution: TargetResolutionResult = _target_resolver.resolve(
		art_state.definition.targeting,
		BattleTargetingContext.create(battle, actor_unit_id, selection),
		selection
	)
	if not resolution.is_valid:
		return result
	for affected: Vector2i in resolution.resolved_targets.affected_cells:
		result[affected] = true
	return result


func selection_for_coordinate(
		battle: BattleState,
		actor_unit_id: int,
		art_slot_index: int,
		coordinate: Vector2i
) -> TargetSelection:
	var art_state: ArtState = get_art_state(
		battle,
		actor_unit_id,
		art_slot_index
	)
	if (
		battle == null
		or battle.grid == null
		or art_state == null
		or art_state.definition.targeting == null
	):
		return null
	var selection: TargetSelection = TargetSelection.new()
	var occupant: GridOccupant = battle.grid.get_occupant(coordinate)
	match art_state.definition.targeting.target_kind:
		GameEnums.TargetKind.UNIT:
			if (
				occupant == null
				or occupant.kind != GameEnums.GridOccupantKind.UNIT
			):
				return null
			selection.unit_instance_ids.append(occupant.runtime_id)
		GameEnums.TargetKind.CELL:
			selection.cells.append(coordinate)
		GameEnums.TargetKind.TERRAIN_OBJECT:
			if (
				occupant == null
				or occupant.kind
				!= GameEnums.GridOccupantKind.SCENE_OBJECT
			):
				return null
			selection.terrain_object_instance_ids.append(occupant.runtime_id)
		GameEnums.TargetKind.BATTLE:
			selection.targets_battle = true
	return selection


func get_art_state(
		battle: BattleState,
		actor_unit_id: int,
		art_slot_index: int
) -> ArtState:
	if battle == null:
		return null
	var unit: UnitState = battle.get_unit(actor_unit_id)
	if (
		unit == null
		or art_slot_index < 0
		or art_slot_index >= unit.arts.size()
	):
		return null
	return unit.arts[art_slot_index]

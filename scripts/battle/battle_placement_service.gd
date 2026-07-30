class_name BattlePlacementService
extends RefCounted


func place_run_unit(
		battle: BattleState,
		run_unit: RunUnitState,
		side: GameEnums.BattleSide,
		coordinate: Vector2i
) -> BattlePlacementResult:
	var battle_validation: BattlePlacementResult = _validate_battle_for_placement(battle)
	if not battle_validation.succeeded():
		return battle_validation
	if run_unit == null or run_unit.definition == null:
		return BattlePlacementResult.failure(
				GameEnums.BattlePlacementCode.INVALID_UNIT
		)

	var cell_validation: GridOperationResult = battle.grid.can_place_at(coordinate)
	if not cell_validation.succeeded():
		return BattlePlacementResult.failure(_map_grid_code(cell_validation.code))

	var unit_id: int = battle._allocate_unit_id()
	var unit: UnitState = UnitState.create_from_run_unit(unit_id, run_unit, side)
	return _commit_placement(battle, unit, coordinate)


func place_unit_definition(
		battle: BattleState,
		definition: UnitDefinition,
		side: GameEnums.BattleSide,
		coordinate: Vector2i
) -> BattlePlacementResult:
	var battle_validation: BattlePlacementResult = _validate_battle_for_placement(battle)
	if not battle_validation.succeeded():
		return battle_validation
	if definition == null:
		return BattlePlacementResult.failure(
				GameEnums.BattlePlacementCode.INVALID_UNIT
		)

	var cell_validation: GridOperationResult = battle.grid.can_place_at(coordinate)
	if not cell_validation.succeeded():
		return BattlePlacementResult.failure(_map_grid_code(cell_validation.code))

	var unit_id: int = battle._allocate_unit_id()
	var unit: UnitState = UnitState.create(unit_id, definition, side)
	return _commit_placement(battle, unit, coordinate)


func remove_unit(
		battle: BattleState,
		unit_id: int
) -> BattlePlacementResult:
	if battle == null or battle.grid == null:
		return BattlePlacementResult.failure(GameEnums.BattlePlacementCode.INVALID_BATTLE)
	var unit: UnitState = battle.get_unit(unit_id)
	if unit == null:
		return BattlePlacementResult.failure(
				GameEnums.BattlePlacementCode.UNIT_NOT_FOUND
		)

	var grid_result: GridOperationResult = battle.grid.remove_occupant(
			GameEnums.GridOccupantKind.UNIT,
			unit_id
	)
	if not grid_result.succeeded():
		return BattlePlacementResult.failure(
				GameEnums.BattlePlacementCode.GRID_STATE_REJECTED
		)

	battle._remove_unit(unit_id)
	return BattlePlacementResult.success(unit_id)


func remove_defeated_units(battle: BattleState) -> Array[int]:
	var removed_unit_ids: Array[int] = []
	if battle == null:
		return removed_unit_ids

	for unit: UnitState in battle.get_units():
		if not unit.is_defeated():
			continue
		var removal: BattlePlacementResult = remove_unit(battle, unit.instance_id)
		if removal.succeeded():
			removed_unit_ids.append(unit.instance_id)
	return removed_unit_ids


func get_unit_position(
		battle: BattleState,
		unit_id: int
) -> GridCoordinate:
	if battle == null or battle.grid == null or battle.get_unit(unit_id) == null:
		return null
	return battle.grid.find_occupant(GameEnums.GridOccupantKind.UNIT, unit_id)


func _commit_placement(
		battle: BattleState,
		unit: UnitState,
		coordinate: Vector2i
) -> BattlePlacementResult:
	var occupant: GridOccupant = GridOccupant.unit(unit.instance_id)
	var grid_result: GridOperationResult = battle.grid.place_occupant(
			occupant,
			coordinate
	)
	if not grid_result.succeeded():
		return BattlePlacementResult.failure(_map_grid_code(grid_result.code))
	if not battle._register_unit(unit):
		battle.grid.remove_occupant_at(coordinate, occupant)
		return BattlePlacementResult.failure(
				GameEnums.BattlePlacementCode.GRID_STATE_REJECTED
		)
	return BattlePlacementResult.success(unit.instance_id)


func _validate_battle_for_placement(
		battle: BattleState
) -> BattlePlacementResult:
	if battle == null or battle.grid == null or not battle.grid.is_valid():
		return BattlePlacementResult.failure(GameEnums.BattlePlacementCode.INVALID_BATTLE)
	if battle.phase != GameEnums.BattlePhase.SETUP:
		return BattlePlacementResult.failure(
				GameEnums.BattlePlacementCode.BATTLE_NOT_IN_SETUP
		)
	return BattlePlacementResult.success(0)


func _map_grid_code(
		code: GameEnums.GridOperationCode
) -> GameEnums.BattlePlacementCode:
	match code:
		GameEnums.GridOperationCode.OUT_OF_BOUNDS:
			return GameEnums.BattlePlacementCode.OUT_OF_BOUNDS
		GameEnums.GridOperationCode.TERRAIN_BLOCKED:
			return GameEnums.BattlePlacementCode.TERRAIN_BLOCKED
		GameEnums.GridOperationCode.CELL_OCCUPIED:
			return GameEnums.BattlePlacementCode.CELL_OCCUPIED
		_:
			return GameEnums.BattlePlacementCode.GRID_STATE_REJECTED

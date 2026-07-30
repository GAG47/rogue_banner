class_name GridStateTest
extends RefCounted


static func run(suite: TestSuite) -> void:
	_test_coordinates_and_cells(suite)
	_test_terrain_and_occupancy(suite)
	_test_weighted_pathfinding(suite)
	_test_unreachable_path(suite)


static func _test_coordinates_and_cells(suite: TestSuite) -> void:
	var terrain: TerrainDefinition = _create_terrain(&"floor", 1, false)
	var grid: GridState = GridState.create(3, 3, terrain)

	suite.assert_true(grid.is_valid(), "Positive Grid dimensions must create a valid Grid.")
	suite.assert_int_equal(3, grid.width, "Grid width must be retained.")
	suite.assert_int_equal(3, grid.height, "Grid height must be retained.")
	suite.assert_true(
			grid.is_in_bounds(Vector2i(2, 2)),
			"The final configured coordinate must be in bounds."
	)
	suite.assert_false(
			grid.is_in_bounds(Vector2i(3, 2)),
			"Coordinates outside width must be rejected."
	)
	suite.assert_true(
			grid.get_cell(Vector2i(1, 1)) != null,
			"In-bounds Cell queries must return CellState."
	)
	suite.assert_true(
			grid.get_cell(Vector2i(-1, 0)) == null,
			"Out-of-bounds Cell queries must return null."
	)
	suite.assert_int_equal(
			4,
			grid.get_neighbors(Vector2i(1, 1)).size(),
			"Interior cells must have four cardinal neighbors."
	)
	suite.assert_int_equal(
			2,
			grid.get_neighbors(Vector2i.ZERO).size(),
			"Corner cells must have two cardinal neighbors."
	)
	suite.assert_int_equal(
			4,
			grid.get_distance(Vector2i.ZERO, Vector2i(2, 2)),
			"Grid distance must use Manhattan distance."
	)
	suite.assert_int_equal(
			-1,
			grid.get_distance(Vector2i.ZERO, Vector2i(3, 0)),
			"Distance queries with invalid coordinates must fail explicitly."
	)

	var first: GridCoordinate = GridCoordinate.new(Vector2i(1, 1))
	var second: GridCoordinate = GridCoordinate.new(Vector2i(2, 1))
	suite.assert_true(
			first.is_cardinally_adjacent_to(second),
			"GridCoordinate adjacency must use cardinal distance."
	)


static func _test_terrain_and_occupancy(suite: TestSuite) -> void:
	var floor: TerrainDefinition = _create_terrain(&"floor", 1, false)
	var wall: TerrainDefinition = _create_terrain(&"wall", 1, true)
	var difficult: TerrainDefinition = _create_terrain(&"mud", 3, false)
	var grid: GridState = GridState.create(3, 2, floor)

	suite.assert_true(
			grid.set_terrain(Vector2i(1, 0), wall).succeeded(),
			"Terrain replacement must succeed in bounds."
	)
	suite.assert_false(
			grid.is_cell_passable(Vector2i(1, 0)),
			"Blocking Terrain must make a Cell impassable."
	)
	suite.assert_true(
			grid.set_terrain(Vector2i(2, 0), difficult).succeeded(),
			"Difficult Terrain must be assignable."
	)
	suite.assert_int_equal(
			3,
			grid.get_movement_cost(Vector2i(2, 0)),
			"Movement cost must come from TerrainDefinition."
	)

	var unit_occupant: GridOccupant = GridOccupant.unit(1)
	suite.assert_true(
			grid.place_occupant(unit_occupant, Vector2i.ZERO).succeeded(),
			"A valid Unit occupant must be placeable."
	)
	var duplicate: GridOperationResult = grid.place_occupant(
			unit_occupant,
			Vector2i(0, 1)
	)
	suite.assert_int_equal(
			GameEnums.GridOperationCode.OCCUPANT_ALREADY_PLACED,
			duplicate.code,
			"The same occupant cannot be placed twice."
	)

	var object_occupant: GridOccupant = GridOccupant.scene_object(1)
	var occupied_result: GridOperationResult = grid.place_occupant(
			object_occupant,
			Vector2i.ZERO
	)
	suite.assert_int_equal(
			GameEnums.GridOperationCode.CELL_OCCUPIED,
			occupied_result.code,
			"Units and scene objects share one exclusive occupancy source."
	)
	suite.assert_true(
			grid.place_occupant(object_occupant, Vector2i(0, 1)).succeeded(),
			"Scene object occupancy must use the same Grid interface."
	)
	suite.assert_int_equal(2, grid.occupant_count(), "Grid must count all occupants.")

	var unit_position: GridCoordinate = grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			1
	)
	suite.assert_true(unit_position != null, "Placed Units must have a Grid position.")
	if unit_position != null:
		suite.assert_vector_equal(
				Vector2i.ZERO,
				unit_position.value,
				"Unit position queries must resolve from Grid occupancy."
		)

	var blocked_move: GridOperationResult = grid.move_occupant(
			unit_occupant,
			Vector2i.ZERO,
			Vector2i(0, 1)
	)
	suite.assert_int_equal(
			GameEnums.GridOperationCode.CELL_OCCUPIED,
			blocked_move.code,
			"Movement cannot overwrite an occupied Cell."
	)
	suite.assert_true(
			grid.remove_occupant(
					GameEnums.GridOccupantKind.SCENE_OBJECT,
					1
			).succeeded(),
			"Scene object removal must release Grid occupancy."
	)
	suite.assert_true(
			grid.move_occupant(
					unit_occupant,
					Vector2i.ZERO,
					Vector2i(0, 1)
			).succeeded(),
			"Movement must update the authoritative occupancy entry."
	)
	suite.assert_true(
			grid.get_occupant(Vector2i.ZERO) == null,
			"Moving an occupant must clear its source Cell."
	)


static func _test_weighted_pathfinding(suite: TestSuite) -> void:
	var floor: TerrainDefinition = _create_terrain(&"floor", 1, false)
	var expensive: TerrainDefinition = _create_terrain(&"deep_mud", 5, false)
	var grid: GridState = GridState.create(3, 3, floor)
	grid.set_terrain(Vector2i(1, 1), expensive)

	var path: GridPathResult = GridPathfinder.new().find_path(
			grid,
			Vector2i(0, 1),
			Vector2i(2, 1)
	)
	suite.assert_true(path.succeeded(), "A reachable destination must produce a path.")
	suite.assert_int_equal(
			4,
			path.total_cost,
			"Pathfinding must minimize total Terrain movement cost."
	)
	suite.assert_false(
			path.path.has(Vector2i(1, 1)),
			"Weighted pathfinding must avoid a more expensive route."
	)


static func _test_unreachable_path(suite: TestSuite) -> void:
	var floor: TerrainDefinition = _create_terrain(&"floor", 1, false)
	var wall: TerrainDefinition = _create_terrain(&"wall", 1, true)
	var grid: GridState = GridState.create(3, 3, floor)
	for y: int in range(3):
		grid.set_terrain(Vector2i(1, y), wall)

	var path: GridPathResult = GridPathfinder.new().find_path(
			grid,
			Vector2i(0, 1),
			Vector2i(2, 1)
	)
	suite.assert_false(path.succeeded(), "Blocking Terrain must prevent paths.")
	suite.assert_int_equal(
			GameEnums.GridPathStatus.NO_PATH,
			path.status,
			"Unreachable destinations must return a typed path failure."
	)


static func _create_terrain(
		content_id: StringName,
		movement_cost: int,
		blocks_movement: bool
) -> TerrainDefinition:
	var terrain: TerrainDefinition = TerrainDefinition.new()
	terrain.content_id = content_id
	terrain.movement_cost = movement_cost
	terrain.blocks_movement = blocks_movement
	return terrain

class_name GridState
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

var _width: int = 0
var _height: int = 0
var _cells: Array[CellState] = []
var _occupants: Dictionary[Vector2i, GridOccupant] = {}

var width: int:
	get:
		return _width

var height: int:
	get:
		return _height


static func create(
		grid_width: int,
		grid_height: int,
		default_terrain: TerrainDefinition
) -> GridState:
	var state: GridState = GridState.new()
	state._width = grid_width
	state._height = grid_height

	if grid_width <= 0 or grid_height <= 0:
		return state

	for y: int in range(grid_height):
		for x: int in range(grid_width):
			state._cells.append(CellState.new(Vector2i(x, y), default_terrain))
	return state


func is_valid() -> bool:
	return (
			_width > 0
			and _height > 0
			and _cells.size() == _width * _height
	)


func is_in_bounds(coordinate: Vector2i) -> bool:
	return (
			coordinate.x >= 0
			and coordinate.y >= 0
			and coordinate.x < _width
			and coordinate.y < _height
	)


func get_cell(coordinate: Vector2i) -> CellState:
	if not is_in_bounds(coordinate):
		return null
	return _cells[_cell_index(coordinate)]


func set_terrain(
		coordinate: Vector2i,
		terrain: TerrainDefinition
) -> GridOperationResult:
	if not is_valid():
		return GridOperationResult.failure(GameEnums.GridOperationCode.INVALID_GRID)
	if not is_in_bounds(coordinate):
		return GridOperationResult.failure(GameEnums.GridOperationCode.OUT_OF_BOUNDS)
	if terrain == null:
		return GridOperationResult.failure(GameEnums.GridOperationCode.NULL_TERRAIN)

	_cells[_cell_index(coordinate)]._replace_terrain(terrain)
	return GridOperationResult.success()


func get_neighbors(coordinate: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	if not is_in_bounds(coordinate):
		return neighbors

	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = coordinate + direction
		if is_in_bounds(neighbor):
			neighbors.append(neighbor)
	return neighbors


func get_distance(from_coordinate: Vector2i, to_coordinate: Vector2i) -> int:
	if not is_in_bounds(from_coordinate) or not is_in_bounds(to_coordinate):
		return -1
	return (
			absi(from_coordinate.x - to_coordinate.x)
			+ absi(from_coordinate.y - to_coordinate.y)
	)


func is_cell_passable(coordinate: Vector2i) -> bool:
	var cell: CellState = get_cell(coordinate)
	return (
			cell != null
			and cell.terrain != null
			and not cell.terrain.blocks_movement
			and not _occupants.has(coordinate)
	)


func get_movement_cost(coordinate: Vector2i) -> int:
	var cell: CellState = get_cell(coordinate)
	if cell == null or cell.terrain == null or cell.terrain.blocks_movement:
		return 0
	return cell.terrain.movement_cost


func get_occupant(coordinate: Vector2i) -> GridOccupant:
	if not _occupants.has(coordinate):
		return null
	return _occupants[coordinate]


func find_occupant(
		kind: GameEnums.GridOccupantKind,
		runtime_id: int
) -> GridCoordinate:
	for coordinate: Vector2i in _occupants:
		var occupant: GridOccupant = _occupants[coordinate]
		if occupant.kind == kind and occupant.runtime_id == runtime_id:
			return GridCoordinate.new(coordinate)
	return null


func can_place_occupant(
		occupant: GridOccupant,
		coordinate: Vector2i
) -> GridOperationResult:
	if not is_valid():
		return GridOperationResult.failure(GameEnums.GridOperationCode.INVALID_GRID)
	if occupant == null or not occupant.is_valid():
		return GridOperationResult.failure(GameEnums.GridOperationCode.INVALID_OCCUPANT)
	if find_occupant(occupant.kind, occupant.runtime_id) != null:
		return GridOperationResult.failure(
				GameEnums.GridOperationCode.OCCUPANT_ALREADY_PLACED
		)
	return can_place_at(coordinate)


func can_place_at(coordinate: Vector2i) -> GridOperationResult:
	if not is_valid():
		return GridOperationResult.failure(GameEnums.GridOperationCode.INVALID_GRID)
	if not is_in_bounds(coordinate):
		return GridOperationResult.failure(GameEnums.GridOperationCode.OUT_OF_BOUNDS)

	var cell: CellState = get_cell(coordinate)
	if cell == null or cell.terrain == null:
		return GridOperationResult.failure(GameEnums.GridOperationCode.NULL_TERRAIN)
	if cell.terrain.blocks_movement:
		return GridOperationResult.failure(GameEnums.GridOperationCode.TERRAIN_BLOCKED)
	if _occupants.has(coordinate):
		return GridOperationResult.failure(GameEnums.GridOperationCode.CELL_OCCUPIED)
	return GridOperationResult.success()


func place_occupant(
		occupant: GridOccupant,
		coordinate: Vector2i
) -> GridOperationResult:
	var validation: GridOperationResult = can_place_occupant(occupant, coordinate)
	if not validation.succeeded():
		return validation

	_occupants[coordinate] = occupant
	return GridOperationResult.success()


func move_occupant(
		occupant: GridOccupant,
		source: Vector2i,
		destination: Vector2i
) -> GridOperationResult:
	if occupant == null or not occupant.is_valid():
		return GridOperationResult.failure(GameEnums.GridOperationCode.INVALID_OCCUPANT)
	if source == destination:
		return GridOperationResult.failure(
				GameEnums.GridOperationCode.DESTINATION_UNCHANGED
		)
	if not is_in_bounds(source):
		return GridOperationResult.failure(GameEnums.GridOperationCode.OUT_OF_BOUNDS)

	var source_occupant: GridOccupant = get_occupant(source)
	if source_occupant == null:
		return GridOperationResult.failure(GameEnums.GridOperationCode.OCCUPANT_NOT_FOUND)
	if not source_occupant.matches(occupant):
		return GridOperationResult.failure(GameEnums.GridOperationCode.SOURCE_MISMATCH)

	if not is_in_bounds(destination):
		return GridOperationResult.failure(GameEnums.GridOperationCode.OUT_OF_BOUNDS)
	var destination_cell: CellState = get_cell(destination)
	if destination_cell == null or destination_cell.terrain == null:
		return GridOperationResult.failure(GameEnums.GridOperationCode.NULL_TERRAIN)
	if destination_cell.terrain.blocks_movement:
		return GridOperationResult.failure(GameEnums.GridOperationCode.TERRAIN_BLOCKED)
	if _occupants.has(destination):
		return GridOperationResult.failure(GameEnums.GridOperationCode.CELL_OCCUPIED)

	_occupants.erase(source)
	_occupants[destination] = occupant
	return GridOperationResult.success()


func remove_occupant_at(
		coordinate: Vector2i,
		expected_occupant: GridOccupant = null
) -> GridOperationResult:
	if not is_in_bounds(coordinate):
		return GridOperationResult.failure(GameEnums.GridOperationCode.OUT_OF_BOUNDS)
	var occupant: GridOccupant = get_occupant(coordinate)
	if occupant == null:
		return GridOperationResult.failure(GameEnums.GridOperationCode.OCCUPANT_NOT_FOUND)
	if expected_occupant != null and not occupant.matches(expected_occupant):
		return GridOperationResult.failure(GameEnums.GridOperationCode.SOURCE_MISMATCH)

	_occupants.erase(coordinate)
	return GridOperationResult.success()


func remove_occupant(
		kind: GameEnums.GridOccupantKind,
		runtime_id: int
) -> GridOperationResult:
	var coordinate: GridCoordinate = find_occupant(kind, runtime_id)
	if coordinate == null:
		return GridOperationResult.failure(GameEnums.GridOperationCode.OCCUPANT_NOT_FOUND)
	return remove_occupant_at(coordinate.value, GridOccupant.new(kind, runtime_id))


func occupant_count() -> int:
	return _occupants.size()


func duplicate_state() -> GridState:
	var state: GridState = GridState.new()
	state._width = _width
	state._height = _height
	for cell: CellState in _cells:
		state._cells.append(
				CellState.new(cell.coordinate, cell.terrain)
				if cell != null
				else null
		)
	for coordinate: Vector2i in _occupants:
		var occupant: GridOccupant = _occupants[coordinate]
		state._occupants[coordinate] = GridOccupant.new(
				occupant.kind,
				occupant.runtime_id
		)
	return state


func _copy_from(source: GridState) -> bool:
	if (
		source == null
		or not source.is_valid()
		or _width != source.width
		or _height != source.height
	):
		return false
	for index: int in range(_cells.size()):
		if _cells[index] == null or source._cells[index] == null:
			return false
	for index: int in range(_cells.size()):
		_cells[index]._replace_terrain(source._cells[index].terrain)

	_occupants.clear()
	for coordinate: Vector2i in source._occupants:
		var occupant: GridOccupant = source._occupants[coordinate]
		_occupants[coordinate] = GridOccupant.new(
				occupant.kind,
				occupant.runtime_id
		)
	return true


func _cell_index(coordinate: Vector2i) -> int:
	return coordinate.y * _width + coordinate.x

class_name GridPathfinder
extends RefCounted


func find_path(
		grid: GridState,
		start: Vector2i,
		destination: Vector2i
) -> GridPathResult:
	if grid == null or not grid.is_valid():
		return GridPathResult.failure(GameEnums.GridPathStatus.INVALID_GRID)
	if not grid.is_in_bounds(start) or not grid.is_in_bounds(destination):
		return GridPathResult.failure(GameEnums.GridPathStatus.OUT_OF_BOUNDS)
	if start == destination:
		var stationary_path: Array[Vector2i] = [start]
		return GridPathResult.found(stationary_path, 0)
	if not grid.is_cell_passable(destination):
		return GridPathResult.failure(GameEnums.GridPathStatus.DESTINATION_BLOCKED)

	var frontier: Array[Vector2i] = [start]
	var costs: Dictionary[Vector2i, int] = {}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	costs[start] = 0

	while not frontier.is_empty():
		var current: Vector2i = _take_lowest_cost(frontier, costs)
		if current == destination:
			break

		for neighbor: Vector2i in grid.get_neighbors(current):
			if not grid.is_cell_passable(neighbor):
				continue
			var movement_cost: int = grid.get_movement_cost(neighbor)
			if movement_cost <= 0:
				continue
			var new_cost: int = costs[current] + movement_cost
			if not costs.has(neighbor) or new_cost < costs[neighbor]:
				costs[neighbor] = new_cost
				came_from[neighbor] = current
				if not frontier.has(neighbor):
					frontier.append(neighbor)

	if not costs.has(destination):
		return GridPathResult.failure(GameEnums.GridPathStatus.NO_PATH)

	var path: Array[Vector2i] = [destination]
	var cursor: Vector2i = destination
	while cursor != start:
		cursor = came_from[cursor]
		path.append(cursor)
	path.reverse()
	return GridPathResult.found(path, costs[destination])


func _take_lowest_cost(
		frontier: Array[Vector2i],
		costs: Dictionary[Vector2i, int]
) -> Vector2i:
	var lowest_index: int = 0
	var lowest_cost: int = costs[frontier[0]]
	for index: int in range(1, frontier.size()):
		var candidate_cost: int = costs[frontier[index]]
		if candidate_cost < lowest_cost:
			lowest_index = index
			lowest_cost = candidate_cost
	return frontier.pop_at(lowest_index)

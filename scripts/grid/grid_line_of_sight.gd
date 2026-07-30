class_name GridLineOfSight
extends RefCounted


func has_line_of_sight(
		grid: GridState,
		origin: Vector2i,
		target: Vector2i
) -> bool:
	if (
		grid == null
		or not grid.is_valid()
		or not grid.is_in_bounds(origin)
		or not grid.is_in_bounds(target)
	):
		return false
	if origin == target:
		return true

	var line: Array[Vector2i] = _get_supercover_line(origin, target)
	for index: int in range(1, line.size()):
		var coordinate: Vector2i = line[index]
		var cell: CellState = grid.get_cell(coordinate)
		if cell == null or cell.terrain == null:
			return false
		if coordinate != target and cell.terrain.blocks_line_of_sight:
			return false
	return true


func _get_supercover_line(origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [origin]
	var delta_x: int = target.x - origin.x
	var delta_y: int = target.y - origin.y
	var step_x: int = signi(delta_x)
	var step_y: int = signi(delta_y)
	var absolute_x: int = absi(delta_x)
	var absolute_y: int = absi(delta_y)
	var x: int = origin.x
	var y: int = origin.y
	var crossed_x: int = 0
	var crossed_y: int = 0

	while crossed_x < absolute_x or crossed_y < absolute_y:
		var left_value: int = (1 + 2 * crossed_x) * absolute_y
		var right_value: int = (1 + 2 * crossed_y) * absolute_x
		if left_value == right_value:
			x += step_x
			y += step_y
			crossed_x += 1
			crossed_y += 1
		elif left_value < right_value:
			x += step_x
			crossed_x += 1
		else:
			y += step_y
			crossed_y += 1
		result.append(Vector2i(x, y))
	return result

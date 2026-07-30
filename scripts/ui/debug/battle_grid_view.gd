class_name BattleGridView
extends Node2D

const GROUND_COLOR: Color = Color("263444")
const DIFFICULT_COLOR: Color = Color("72583b")
const BLOCKED_COLOR: Color = Color("3a4250")
const INVALID_COLOR: Color = Color("7a3153")
const GRID_LINE_COLOR: Color = Color("8190a5")
const COORDINATE_COLOR: Color = Color("aebdce")
const SCENE_OBJECT_COLOR: Color = Color("d49345")

@export_range(32.0, 128.0, 1.0) var cell_size: float = 76.0

var _grid: GridState


func present(grid_state: GridState) -> void:
	_grid = grid_state
	queue_redraw()


func screen_to_coordinate(screen_position: Vector2) -> GridCoordinate:
	if _grid == null:
		return null

	var local_position: Vector2 = to_local(screen_position)
	var coordinate: Vector2i = Vector2i(
			floori(local_position.x / cell_size),
			floori(local_position.y / cell_size)
	)
	if not _grid.is_in_bounds(coordinate):
		return null
	return GridCoordinate.new(coordinate)


func coordinate_center(coordinate: Vector2i) -> Vector2:
	return (
		Vector2(coordinate) * cell_size
		+ Vector2.ONE * cell_size * 0.5
	)


func _draw() -> void:
	if _grid == null:
		return

	for y: int in range(_grid.height):
		for x: int in range(_grid.width):
			_draw_cell(Vector2i(x, y))


func _draw_cell(coordinate: Vector2i) -> void:
	var cell: CellState = _grid.get_cell(coordinate)
	var cell_rect: Rect2 = Rect2(
			Vector2(coordinate) * cell_size,
			Vector2.ONE * cell_size
	)
	var fill_color: Color = _terrain_color(cell)
	draw_rect(cell_rect, fill_color, true)
	draw_rect(cell_rect.grow(-1.0), GRID_LINE_COLOR, false, 2.0)

	var coordinate_text: String = "%d,%d" % [coordinate.x, coordinate.y]
	draw_string(
			ThemeDB.fallback_font,
			cell_rect.position + Vector2(7.0, 18.0),
			coordinate_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			13,
			COORDINATE_COLOR
	)

	if cell != null and cell.terrain != null and cell.terrain.movement_cost > 1:
		var cost_text: String = "消耗 %d" % cell.terrain.movement_cost
		draw_string(
				ThemeDB.fallback_font,
				cell_rect.position + Vector2(7.0, cell_size - 8.0),
				cost_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				12,
				COORDINATE_COLOR
		)

	var occupant: GridOccupant = _grid.get_occupant(coordinate)
	if (
		occupant != null
		and occupant.kind == GameEnums.GridOccupantKind.SCENE_OBJECT
	):
		_draw_scene_object(cell_rect)


func _terrain_color(cell: CellState) -> Color:
	if cell == null or cell.terrain == null:
		return INVALID_COLOR
	if cell.terrain.blocks_movement:
		return BLOCKED_COLOR
	if cell.terrain.movement_cost > 1:
		return DIFFICULT_COLOR
	return GROUND_COLOR


func _draw_scene_object(cell_rect: Rect2) -> void:
	var object_rect: Rect2 = cell_rect.grow(-cell_size * 0.24)
	draw_rect(object_rect, SCENE_OBJECT_COLOR, true)
	draw_rect(object_rect, Color("ffe0a6"), false, 3.0)
	draw_line(
			object_rect.position,
			object_rect.end,
			Color("ffe0a6"),
			3.0
	)
	draw_line(
			Vector2(object_rect.end.x, object_rect.position.y),
			Vector2(object_rect.position.x, object_rect.end.y),
			Color("ffe0a6"),
			3.0
	)

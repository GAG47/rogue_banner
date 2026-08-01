class_name BattleScreenGridView
extends Node2D

const GROUND_COLOR: Color = Color("233345")
const DIFFICULT_COLOR: Color = Color("725638")
const BLOCKED_COLOR: Color = Color("3c4656")
const INVALID_COLOR: Color = Color("7a3153")
const GRID_LINE_COLOR: Color = Color("8293a8")
const COORDINATE_COLOR: Color = Color("b9c6d5")
const SCENE_OBJECT_COLOR: Color = Color("d49345")

@export_range(32.0, 128.0, 1.0) var cell_size: float = 82.0

var _model: BattleReadModel


func present(model: BattleReadModel) -> void:
	_model = model
	queue_redraw()


func screen_to_coordinate(screen_position: Vector2) -> GridCoordinate:
	if _model == null:
		return null
	var local_position: Vector2 = to_local(screen_position)
	var coordinate: Vector2i = Vector2i(
		floori(local_position.x / cell_size),
		floori(local_position.y / cell_size)
	)
	if not _model.is_in_bounds(coordinate):
		return null
	return GridCoordinate.new(coordinate)


func coordinate_center(coordinate: Vector2i) -> Vector2:
	return (
		Vector2(coordinate) * cell_size
		+ Vector2.ONE * cell_size * 0.5
	)


func _draw() -> void:
	if _model == null:
		return
	for y: int in range(_model.grid_height):
		for x: int in range(_model.grid_width):
			_draw_cell(Vector2i(x, y))


func _draw_cell(coordinate: Vector2i) -> void:
	var cell: BattleCellReadModel = _model.get_cell(coordinate)
	var cell_rect: Rect2 = Rect2(
		Vector2(coordinate) * cell_size,
		Vector2.ONE * cell_size
	)
	draw_rect(cell_rect, _terrain_color(cell), true)
	draw_rect(cell_rect.grow(-1.0), GRID_LINE_COLOR, false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		cell_rect.position + Vector2(7.0, 18.0),
		"%d,%d" % [coordinate.x, coordinate.y],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		COORDINATE_COLOR
	)
	if cell != null and cell.movement_cost > 1:
		draw_string(
			ThemeDB.fallback_font,
			cell_rect.position + Vector2(7.0, cell_size - 9.0),
			"消耗 %d" % cell.movement_cost,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			COORDINATE_COLOR
		)
	if cell != null and cell.has_scene_object():
		_draw_scene_object(cell_rect)


func _terrain_color(cell: BattleCellReadModel) -> Color:
	if cell == null or cell.movement_cost <= 0:
		return INVALID_COLOR
	if cell.blocks_movement:
		return BLOCKED_COLOR
	if cell.movement_cost > 1:
		return DIFFICULT_COLOR
	return GROUND_COLOR


func _draw_scene_object(cell_rect: Rect2) -> void:
	var object_rect: Rect2 = cell_rect.grow(-cell_size * 0.24)
	draw_rect(object_rect, SCENE_OBJECT_COLOR, true)
	draw_rect(object_rect, Color("ffe0a6"), false, 3.0)
	draw_line(object_rect.position, object_rect.end, Color("ffe0a6"), 3.0)
	draw_line(
		Vector2(object_rect.end.x, object_rect.position.y),
		Vector2(object_rect.position.x, object_rect.end.y),
		Color("ffe0a6"),
		3.0
	)

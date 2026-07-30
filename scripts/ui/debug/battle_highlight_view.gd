class_name BattleHighlightView
extends Node2D

const REACHABLE_COLOR: Color = Color(0.18, 0.78, 0.68, 0.28)
const REACHABLE_BORDER_COLOR: Color = Color("43d6bc")
const SELECTED_COLOR: Color = Color("ffd166")
const HOVER_COLOR: Color = Color("f4f7fb")

@export_range(32.0, 128.0, 1.0) var cell_size: float = 76.0

var _selected_coordinate: GridCoordinate
var _hovered_coordinate: GridCoordinate
var _reachable_cells: Dictionary[Vector2i, int] = {}


func present(
		selected_coordinate: GridCoordinate,
		hovered_coordinate: GridCoordinate,
		reachable_cells: Dictionary[Vector2i, int]
) -> void:
	_selected_coordinate = selected_coordinate
	_hovered_coordinate = hovered_coordinate
	_reachable_cells.clear()
	for coordinate: Vector2i in reachable_cells:
		_reachable_cells[coordinate] = reachable_cells[coordinate]
	queue_redraw()


func _draw() -> void:
	for coordinate: Vector2i in _reachable_cells:
		var cell_rect: Rect2 = _cell_rect(coordinate).grow(-4.0)
		draw_rect(cell_rect, REACHABLE_COLOR, true)
		draw_rect(cell_rect, REACHABLE_BORDER_COLOR, false, 2.0)
		draw_string(
				ThemeDB.fallback_font,
				cell_rect.position + Vector2(7.0, cell_rect.size.y - 7.0),
				"%d 行动点" % _reachable_cells[coordinate],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				13,
				REACHABLE_BORDER_COLOR
		)

	if _selected_coordinate != null:
		draw_rect(
				_cell_rect(_selected_coordinate.value).grow(-4.0),
				SELECTED_COLOR,
				false,
				4.0
		)

	if _hovered_coordinate != null:
		draw_rect(
				_cell_rect(_hovered_coordinate.value).grow(-8.0),
				HOVER_COLOR,
				false,
				2.0
		)


func _cell_rect(coordinate: Vector2i) -> Rect2:
	return Rect2(
			Vector2(coordinate) * cell_size,
			Vector2.ONE * cell_size
	)

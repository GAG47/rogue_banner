class_name BattleScreenHighlightView
extends Node2D

const DEPLOYMENT_COLOR: Color = Color(0.18, 0.68, 0.92, 0.28)
const DEPLOYMENT_BORDER_COLOR: Color = Color("55bde8")
const REACHABLE_COLOR: Color = Color(0.18, 0.78, 0.68, 0.28)
const REACHABLE_BORDER_COLOR: Color = Color("43d6bc")
const ART_RANGE_COLOR: Color = Color(0.45, 0.3, 0.68, 0.18)
const ART_RANGE_BORDER_COLOR: Color = Color(0.64, 0.47, 0.82, 0.72)
const TARGETABLE_COLOR: Color = Color(0.68, 0.35, 0.92, 0.34)
const TARGETABLE_BORDER_COLOR: Color = Color("c78cff")
const AFFECTED_COLOR: Color = Color(0.78, 0.25, 0.95, 0.35)
const AFFECTED_BORDER_COLOR: Color = Color("e0a1ff")
const INTENT_DANGER_COLOR: Color = Color(0.92, 0.2, 0.26, 0.28)
const INTENT_DANGER_BORDER_COLOR: Color = Color("f05b68")
const INTENT_MOVE_COLOR: Color = Color(0.95, 0.62, 0.2, 0.22)
const INTENT_MOVE_BORDER_COLOR: Color = Color("f2a640")
const SELECTED_COLOR: Color = Color("ffd166")
const HOVER_COLOR: Color = Color("f4f7fb")

@export_range(32.0, 128.0, 1.0) var cell_size: float = 82.0

var _selected_coordinate: GridCoordinate
var _hovered_coordinate: GridCoordinate
var _deployment_cells: Dictionary[Vector2i, bool] = {}
var _reachable_cells: Dictionary[Vector2i, int] = {}
var _art_range_cells: Dictionary[Vector2i, bool] = {}
var _targetable_cells: Dictionary[Vector2i, bool] = {}
var _art_affected_cells: Dictionary[Vector2i, bool] = {}
var _intent_danger_cells: Dictionary[Vector2i, bool] = {}
var _intent_move_cells: Dictionary[Vector2i, bool] = {}


func present(
		selected_coordinate: GridCoordinate,
		hovered_coordinate: GridCoordinate,
		deployment_cells: Dictionary[Vector2i, bool],
		reachable_cells: Dictionary[Vector2i, int],
		art_range_cells: Dictionary[Vector2i, bool],
		targetable_cells: Dictionary[Vector2i, bool],
		art_affected_cells: Dictionary[Vector2i, bool],
		intent_danger_cells: Dictionary[Vector2i, bool],
		intent_move_cells: Dictionary[Vector2i, bool]
) -> void:
	_selected_coordinate = selected_coordinate
	_hovered_coordinate = hovered_coordinate
	_copy_bool_dictionary(deployment_cells, _deployment_cells)
	_reachable_cells.clear()
	for coordinate: Vector2i in reachable_cells:
		_reachable_cells[coordinate] = reachable_cells[coordinate]
	_copy_bool_dictionary(art_range_cells, _art_range_cells)
	_copy_bool_dictionary(targetable_cells, _targetable_cells)
	_copy_bool_dictionary(art_affected_cells, _art_affected_cells)
	_copy_bool_dictionary(intent_danger_cells, _intent_danger_cells)
	_copy_bool_dictionary(intent_move_cells, _intent_move_cells)
	queue_redraw()


func _copy_bool_dictionary(
		source: Dictionary[Vector2i, bool],
		destination: Dictionary[Vector2i, bool]
) -> void:
	destination.clear()
	for coordinate: Vector2i in source:
		destination[coordinate] = source[coordinate]


func _draw() -> void:
	_draw_cells(
		_deployment_cells,
		DEPLOYMENT_COLOR,
		DEPLOYMENT_BORDER_COLOR,
		5.0,
		2.0
	)
	_draw_cells(
		_intent_danger_cells,
		INTENT_DANGER_COLOR,
		INTENT_DANGER_BORDER_COLOR,
		5.0,
		2.0
	)
	_draw_cells(
		_intent_move_cells,
		INTENT_MOVE_COLOR,
		INTENT_MOVE_BORDER_COLOR,
		9.0,
		2.0
	)
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
	_draw_cells(
		_art_range_cells,
		ART_RANGE_COLOR,
		ART_RANGE_BORDER_COLOR,
		4.0,
		1.0
	)
	_draw_cells(
		_targetable_cells,
		TARGETABLE_COLOR,
		TARGETABLE_BORDER_COLOR,
		4.0,
		3.0
	)
	_draw_cells(
		_art_affected_cells,
		AFFECTED_COLOR,
		AFFECTED_BORDER_COLOR,
		11.0,
		3.0
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


func _draw_cells(
		cells: Dictionary[Vector2i, bool],
		fill_color: Color,
		border_color: Color,
		margin: float,
		border_width: float
) -> void:
	for coordinate: Vector2i in cells:
		var cell_rect: Rect2 = _cell_rect(coordinate).grow(-margin)
		draw_rect(cell_rect, fill_color, true)
		draw_rect(cell_rect, border_color, false, border_width)


func _cell_rect(coordinate: Vector2i) -> Rect2:
	return Rect2(
		Vector2(coordinate) * cell_size,
		Vector2.ONE * cell_size
	)

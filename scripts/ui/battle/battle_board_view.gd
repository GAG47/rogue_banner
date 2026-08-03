class_name BattleBoardView
extends Control

signal cell_pressed(coordinate: Vector2i)
signal cell_hovered(coordinate: GridCoordinate)
signal targeting_cancel_requested

const BOARD_MARGIN: float = 10.0
const MINIMUM_CELL_SIZE: float = 44.0
const MAXIMUM_CELL_SIZE: float = 220.0
const MINIMUM_VISIBLE_BOARD_SIZE: float = 80.0
const MINIMUM_ZOOM: float = 0.65
const MAXIMUM_ZOOM: float = 2.0
const ZOOM_STEP: float = 1.15

@export var battle_board: Node2D
@export var grid_view: BattleScreenGridView
@export var highlight_view: BattleScreenHighlightView
@export var unit_view: BattleScreenUnitView
@export_range(0.0, 240.0, 1.0) var bottom_safe_area: float = 0.0

var _grid_width: int = 0
var _grid_height: int = 0
var _hovered_coordinate: GridCoordinate
var _pan_offset: Vector2 = Vector2.ZERO
var _base_board_position: Vector2 = Vector2.ZERO
var _board_size: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _pan_button: MouseButton = MOUSE_BUTTON_NONE
var _space_pan_held: bool = false
var _zoom_factor: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_fit_board)
	_fit_board.call_deferred()


func present_battle(model: BattleReadModel) -> void:
	_set_grid_size(
		model.grid_width if model != null else 0,
		model.grid_height if model != null else 0
	)
	grid_view.present(model)
	unit_view.present(model)
	_fit_board()


func present_deployment(
	model: DeploymentReadModel,
	assignments: Dictionary[Vector2i, int],
	selected_unit_id: int
) -> void:
	_set_grid_size(
		model.width if model != null else 0,
		model.height if model != null else 0
	)
	grid_view.present_deployment(model)
	unit_view.present_deployment(model, assignments)
	var selected_coordinate: GridCoordinate
	for coordinate: Vector2i in assignments:
		if assignments[coordinate] == selected_unit_id:
			selected_coordinate = GridCoordinate.new(coordinate)
			break
	var deployment_cells: Dictionary[Vector2i, bool] = {}
	var empty_costs: Dictionary[Vector2i, int] = {}
	var empty_cells: Dictionary[Vector2i, bool] = {}
	if model != null:
		for cell: DeploymentCellReadModel in model.cells:
			if (
				cell != null
				and cell.allows_player_deployment
				and not assignments.has(cell.coordinate)
			):
				deployment_cells[cell.coordinate] = true
	highlight_view.present(
		selected_coordinate,
		_hovered_coordinate,
		deployment_cells,
		empty_costs,
		empty_cells,
		empty_cells,
		empty_cells,
		empty_cells,
		empty_cells
	)
	_fit_board()


func present_highlights(
	selected_coordinate: GridCoordinate,
	reachable_cells: Dictionary[Vector2i, int],
	art_range_cells: Dictionary[Vector2i, bool],
	targetable_cells: Dictionary[Vector2i, bool],
	art_affected_cells: Dictionary[Vector2i, bool],
	intent_danger_cells: Dictionary[Vector2i, bool],
	intent_move_cells: Dictionary[Vector2i, bool]
) -> void:
	var empty_deployment_cells: Dictionary[Vector2i, bool] = {}
	highlight_view.present(
		selected_coordinate,
		_hovered_coordinate,
		empty_deployment_cells,
		reachable_cells,
		art_range_cells,
		targetable_cells,
		art_affected_cells,
		intent_danger_cells,
		intent_move_cells
	)


func get_rendered_cell_count() -> int:
	return _grid_width * _grid_height


func get_pan_offset() -> Vector2:
	return _pan_offset


func get_zoom_factor() -> float:
	return _zoom_factor


func zoom_in(focus_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	_set_zoom(_zoom_factor * ZOOM_STEP, focus_position)


func zoom_out(focus_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	_set_zoom(_zoom_factor / ZOOM_STEP, focus_position)


func reset_zoom() -> void:
	_zoom_factor = 1.0
	_pan_offset = Vector2.ZERO
	_fit_board()


func reset_pan() -> void:
	_pan_offset = Vector2.ZERO
	_apply_board_position()


func coordinate_center_global(coordinate: Vector2i) -> Vector2:
	return grid_view.to_global(grid_view.coordinate_center(coordinate))


func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode != KEY_SPACE and key_event.physical_keycode != KEY_SPACE:
		return
	_space_pan_held = key_event.pressed
	if not _space_pan_held and _is_panning and _pan_button == MOUSE_BUTTON_LEFT:
		_end_pan()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_panning:
			_pan_offset += motion.relative
			_clamp_pan_offset()
			_apply_board_position()
			accept_event()
			return
		_set_hovered_coordinate(_coordinate_at(motion.position))
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in(button.position)
			accept_event()
			return
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out(button.position)
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			targeting_cancel_requested.emit()
			accept_event()
			return
		if _is_pan_button(button):
			if button.pressed:
				_begin_pan(button.button_index)
			elif _is_panning and button.button_index == _pan_button:
				_end_pan()
			accept_event()
			return
		if (
			not button.pressed
			and _is_panning
			and button.button_index == _pan_button
		):
			_end_pan()
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			var coordinate: GridCoordinate = _coordinate_at(button.position)
			if coordinate != null:
				cell_pressed.emit(coordinate.value)
				accept_event()


func _coordinate_at(local_position: Vector2) -> GridCoordinate:
	if _grid_width <= 0 or _grid_height <= 0:
		return null
	var board_position: Vector2 = local_position - battle_board.position
	var coordinate: Vector2i = Vector2i(
		floori(board_position.x / grid_view.cell_size),
		floori(board_position.y / grid_view.cell_size)
	)
	if (
		coordinate.x < 0
		or coordinate.y < 0
		or coordinate.x >= _grid_width
		or coordinate.y >= _grid_height
	):
		return null
	return GridCoordinate.new(coordinate)


func _is_pan_button(button: InputEventMouseButton) -> bool:
	return (
		button.button_index == MOUSE_BUTTON_MIDDLE
		or (
			button.button_index == MOUSE_BUTTON_LEFT
			and (
				_space_pan_held
				or (_is_panning and _pan_button == MOUSE_BUTTON_LEFT)
			)
		)
	)


func _begin_pan(button: MouseButton) -> void:
	_is_panning = true
	_pan_button = button
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_set_hovered_coordinate(null)


func _end_pan() -> void:
	_is_panning = false
	_pan_button = MOUSE_BUTTON_NONE
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _set_hovered_coordinate(coordinate: GridCoordinate) -> void:
	if _coordinates_match(_hovered_coordinate, coordinate):
		return
	_hovered_coordinate = coordinate
	cell_hovered.emit(coordinate)


func _on_mouse_exited() -> void:
	_set_hovered_coordinate(null)


func _fit_board() -> void:
	if (
		battle_board == null
		or grid_view == null
		or _grid_width <= 0
		or _grid_height <= 0
		or size.x <= 0.0
		or size.y <= 0.0
	):
		return
	var available_size: Vector2 = Vector2(
		maxf(0.0, size.x - BOARD_MARGIN * 2.0),
		maxf(0.0, size.y - BOARD_MARGIN * 2.0 - bottom_safe_area)
	)
	var fitted_cell_size: float = minf(
		available_size.x / float(_grid_width),
		available_size.y / float(_grid_height)
	)
	var cell_size: float = clampf(
		fitted_cell_size * _zoom_factor,
		MINIMUM_CELL_SIZE,
		MAXIMUM_CELL_SIZE
	)
	grid_view.cell_size = cell_size
	highlight_view.cell_size = cell_size
	unit_view.cell_size = cell_size
	_board_size = Vector2(
		float(_grid_width) * cell_size,
		float(_grid_height) * cell_size
	)
	_base_board_position = Vector2(
		BOARD_MARGIN + (available_size.x - _board_size.x) * 0.5,
		BOARD_MARGIN + (available_size.y - _board_size.y) * 0.5
	)
	_clamp_pan_offset()
	_apply_board_position()
	grid_view.queue_redraw()
	highlight_view.queue_redraw()
	unit_view.queue_redraw()


func _set_grid_size(width: int, height: int) -> void:
	if width == _grid_width and height == _grid_height:
		return
	_grid_width = width
	_grid_height = height
	_pan_offset = Vector2.ZERO
	_zoom_factor = 1.0


func _set_zoom(next_zoom: float, focus_position: Vector2) -> void:
	if _grid_width <= 0 or _grid_height <= 0:
		return
	var clamped_zoom: float = clampf(
		next_zoom,
		MINIMUM_ZOOM,
		MAXIMUM_ZOOM
	)
	if is_equal_approx(clamped_zoom, _zoom_factor):
		return
	var focus: Vector2 = focus_position
	if focus.x < 0.0 or focus.y < 0.0:
		focus = size * 0.5
	var previous_cell_size: float = maxf(1.0, grid_view.cell_size)
	var focused_board_position: Vector2 = (
		focus - battle_board.position
	) / previous_cell_size
	_zoom_factor = clamped_zoom
	_fit_board()
	var desired_board_position: Vector2 = (
		focus - focused_board_position * grid_view.cell_size
	)
	_pan_offset = desired_board_position - _base_board_position
	_clamp_pan_offset()
	_apply_board_position()


func _clamp_pan_offset() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var maximum_pan: Vector2 = Vector2(
		maxf(size.x * 0.2, (_board_size.x - size.x) * 0.5 + size.x * 0.15),
		maxf(size.y * 0.2, (_board_size.y - size.y) * 0.5 + size.y * 0.15)
	)
	maximum_pan.x = maxf(maximum_pan.x, MINIMUM_VISIBLE_BOARD_SIZE)
	maximum_pan.y = maxf(maximum_pan.y, MINIMUM_VISIBLE_BOARD_SIZE)
	_pan_offset.x = clampf(_pan_offset.x, -maximum_pan.x, maximum_pan.x)
	_pan_offset.y = clampf(_pan_offset.y, -maximum_pan.y, maximum_pan.y)


func _apply_board_position() -> void:
	if battle_board != null:
		battle_board.position = _base_board_position + _pan_offset


func _coordinates_match(
	left: GridCoordinate,
	right: GridCoordinate
) -> bool:
	if left == null or right == null:
		return left == null and right == null
	return left.value == right.value

class_name BattleScreenGridView
extends Node2D

const GROUND_COLOR: Color = Color("18262f")
const GROUND_ACCENT_COLOR: Color = Color("243944")
const DIFFICULT_COLOR: Color = Color("4b4030")
const DIFFICULT_ACCENT_COLOR: Color = Color("716042")
const BLOCKED_COLOR: Color = Color("151c21")
const BLOCKED_ACCENT_COLOR: Color = Color("34414a")
const INVALID_COLOR: Color = Color("472735")
const GRID_LINE_COLOR: Color = Color("4b606c")
const SCENE_OBJECT_COLOR: Color = Color("9a6337")

@export_range(32.0, 128.0, 1.0) var cell_size: float = 82.0

var _battle_model: BattleReadModel
var _deployment_model: DeploymentReadModel


func present(model: BattleReadModel) -> void:
	_battle_model = model
	_deployment_model = null
	queue_redraw()


func present_deployment(model: DeploymentReadModel) -> void:
	_battle_model = null
	_deployment_model = model
	queue_redraw()


func screen_to_coordinate(screen_position: Vector2) -> GridCoordinate:
	var local_position: Vector2 = to_local(screen_position)
	var coordinate: Vector2i = Vector2i(
		floori(local_position.x / cell_size),
		floori(local_position.y / cell_size)
	)
	if not _is_in_bounds(coordinate):
		return null
	return GridCoordinate.new(coordinate)


func coordinate_center(coordinate: Vector2i) -> Vector2:
	return (
		Vector2(coordinate) * cell_size
		+ Vector2.ONE * cell_size * 0.5
	)


func _draw() -> void:
	var grid_size: Vector2i = _grid_size()
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			_draw_cell(Vector2i(x, y))


func _draw_cell(coordinate: Vector2i) -> void:
	var cell_rect: Rect2 = Rect2(
		Vector2(coordinate) * cell_size,
		Vector2.ONE * cell_size
	)
	var movement_cost: int = 0
	var blocks_movement: bool = false
	var has_scene_object: bool = false
	if _battle_model != null:
		var battle_cell: BattleCellReadModel = _battle_model.get_cell(coordinate)
		if battle_cell != null:
			movement_cost = battle_cell.movement_cost
			blocks_movement = battle_cell.blocks_movement
			has_scene_object = battle_cell.has_scene_object()
	elif _deployment_model != null:
		var deployment_cell: DeploymentCellReadModel = (
			_deployment_model.get_cell(coordinate)
		)
		if deployment_cell != null:
			movement_cost = deployment_cell.movement_cost
			blocks_movement = deployment_cell.blocks_movement
	var fill: Color = _terrain_color(movement_cost, blocks_movement)
	draw_rect(cell_rect, fill, true)
	draw_rect(cell_rect.grow(-1.0), GRID_LINE_COLOR, false, 1.5)
	_draw_terrain_detail(cell_rect, movement_cost, blocks_movement)
	if has_scene_object:
		_draw_scene_object(cell_rect)


func _draw_terrain_detail(
	cell_rect: Rect2,
	movement_cost: int,
	blocks_movement: bool
) -> void:
	if blocks_movement:
		var stone_rect: Rect2 = cell_rect.grow(-cell_size * 0.18)
		draw_rect(stone_rect, BLOCKED_ACCENT_COLOR, true)
		draw_line(
			stone_rect.position,
			stone_rect.end,
			Color(BLOCKED_COLOR, 0.8),
			3.0
		)
		draw_line(
			Vector2(stone_rect.end.x, stone_rect.position.y),
			Vector2(stone_rect.position.x, stone_rect.end.y),
			Color(BLOCKED_COLOR, 0.8),
			3.0
		)
		return
	if movement_cost > 1:
		for line_index: int in range(3):
			var y_offset: float = cell_size * (0.3 + 0.2 * line_index)
			draw_line(
				cell_rect.position + Vector2(cell_size * 0.2, y_offset),
				cell_rect.position + Vector2(cell_size * 0.8, y_offset - 5.0),
				DIFFICULT_ACCENT_COLOR,
				2.0,
				true
			)
		return
	var inset: Rect2 = cell_rect.grow(-cell_size * 0.12)
	draw_rect(inset, Color(GROUND_ACCENT_COLOR, 0.22), false, 1.0)


func _terrain_color(movement_cost: int, blocks_movement: bool) -> Color:
	if movement_cost <= 0:
		return INVALID_COLOR
	if blocks_movement:
		return BLOCKED_COLOR
	if movement_cost > 1:
		return DIFFICULT_COLOR
	return GROUND_COLOR


func _draw_scene_object(cell_rect: Rect2) -> void:
	var object_rect: Rect2 = cell_rect.grow(-cell_size * 0.27)
	draw_rect(object_rect, SCENE_OBJECT_COLOR, true)
	draw_rect(object_rect, Color("e6b66f"), false, 2.0)


func _grid_size() -> Vector2i:
	if _battle_model != null:
		return Vector2i(_battle_model.grid_width, _battle_model.grid_height)
	if _deployment_model != null:
		return Vector2i(_deployment_model.width, _deployment_model.height)
	return Vector2i.ZERO


func _is_in_bounds(coordinate: Vector2i) -> bool:
	var grid_size: Vector2i = _grid_size()
	return (
		coordinate.x >= 0
		and coordinate.y >= 0
		and coordinate.x < grid_size.x
		and coordinate.y < grid_size.y
	)

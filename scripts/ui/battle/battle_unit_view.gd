class_name BattleScreenUnitView
extends Node2D

const PLAYER_COLOR: Color = Color("348fca")
const PLAYER_RING_COLOR: Color = Color("64c7ff")
const ENEMY_COLOR: Color = Color("b94450")
const ENEMY_RING_COLOR: Color = Color("f06b73")
const UNIT_BORDER_COLOR: Color = Color("e8f0f4")
const HEALTH_COLOR: Color = Color("55cf83")
const HEALTH_BACKGROUND_COLOR: Color = Color("101820")
const SHIELD_COLOR: Color = Color("6aa9e8")
const TEXT_COLOR: Color = Color("f0f5f7")
const INTENT_BADGE_COLOR: Color = Color("e9b84b")
const INTENT_BADGE_TEXT_COLOR: Color = Color("18212d")
const BUFF_BADGE_COLOR: Color = Color("80d8ff")

@export_range(32.0, 128.0, 1.0) var cell_size: float = 82.0

var _battle_model: BattleReadModel
var _deployment_model: DeploymentReadModel
var _deployment_assignments: Dictionary[Vector2i, int] = {}


func present(model: BattleReadModel) -> void:
	_battle_model = model
	_deployment_model = null
	_deployment_assignments.clear()
	queue_redraw()


func present_deployment(
	model: DeploymentReadModel,
	assignments: Dictionary[Vector2i, int]
) -> void:
	_battle_model = null
	_deployment_model = model
	_deployment_assignments.clear()
	for coordinate: Vector2i in assignments:
		_deployment_assignments[coordinate] = assignments[coordinate]
	queue_redraw()


func _draw() -> void:
	if _battle_model != null:
		for unit: BattleUnitReadModel in _battle_model.units:
			if unit != null and unit.has_coordinate:
				_draw_battle_unit(unit)
		return
	_draw_deployment_units()


func _draw_battle_unit(unit: BattleUnitReadModel) -> void:
	var center: Vector2 = _coordinate_center(unit.coordinate)
	var player_unit: bool = unit.side == GameEnums.BattleSide.PLAYER
	_draw_unit_marker(
		center,
		unit.display_name,
		PLAYER_COLOR if player_unit else ENEMY_COLOR,
		PLAYER_RING_COLOR if player_unit else ENEMY_RING_COLOR
	)
	_draw_health_bar(unit.current_health, unit.maximum_health, center)
	if unit.current_shield > 0:
		_draw_badge(
			center + Vector2(-cell_size * 0.27, -cell_size * 0.18),
			"盾%d" % unit.current_shield,
			SHIELD_COLOR
		)
	if player_unit:
		_draw_ap(unit.current_ap, unit.maximum_ap, center)
	var intent: BattleIntentReadModel = _find_intent(unit.instance_id)
	if intent != null:
		_draw_intent_badge(intent, center)
	if not unit.buffs.is_empty():
		_draw_badge(
			center + Vector2(-cell_size * 0.27, cell_size * 0.02),
			str(unit.buffs.size()),
			BUFF_BADGE_COLOR
		)


func _draw_deployment_units() -> void:
	if _deployment_model == null:
		return
	for cell: DeploymentCellReadModel in _deployment_model.cells:
		if cell != null and not cell.enemy_name.is_empty():
			_draw_unit_marker(
				_coordinate_center(cell.coordinate),
				cell.enemy_name,
				ENEMY_COLOR,
				ENEMY_RING_COLOR
			)
	for coordinate: Vector2i in _deployment_assignments:
		var unit: RunUnitReadModel = _deployment_unit(
			_deployment_assignments[coordinate]
		)
		if unit == null:
			continue
		var center: Vector2 = _coordinate_center(coordinate)
		_draw_unit_marker(
			center,
			unit.display_name,
			PLAYER_COLOR,
			PLAYER_RING_COLOR
		)
		_draw_health_bar(unit.current_health, unit.maximum_health, center)


func _draw_unit_marker(
	center: Vector2,
	display_name: String,
	fill_color: Color,
	ring_color: Color
) -> void:
	var radius: float = cell_size * 0.25
	draw_circle(center, radius, fill_color)
	draw_arc(center, radius + 2.0, 0.0, TAU, 32, ring_color, 3.0)
	draw_arc(center, radius - 5.0, 0.0, TAU, 32, UNIT_BORDER_COLOR, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-cell_size * 0.46, -cell_size * 0.34),
		display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		cell_size * 0.92,
		maxi(12, floori(cell_size * 0.15)),
		TEXT_COLOR
	)


func _draw_health_bar(
	current_health: int,
	maximum_health: int,
	center: Vector2
) -> void:
	if maximum_health <= 0:
		return
	var bar_rect: Rect2 = Rect2(
		center + Vector2(-cell_size * 0.3, cell_size * 0.31),
		Vector2(cell_size * 0.6, maxf(5.0, cell_size * 0.065))
	)
	var ratio: float = clampf(
		float(current_health) / float(maximum_health),
		0.0,
		1.0
	)
	draw_rect(bar_rect, HEALTH_BACKGROUND_COLOR, true)
	draw_rect(
		Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)),
		HEALTH_COLOR,
		true
	)


func _draw_ap(current_ap: int, maximum_ap: int, center: Vector2) -> void:
	var shown_maximum: int = mini(maximum_ap, 7)
	var dot_gap: float = 7.0
	var start_x: float = center.x - dot_gap * float(shown_maximum - 1) * 0.5
	for index: int in range(shown_maximum):
		draw_circle(
			Vector2(start_x + dot_gap * float(index), center.y + cell_size * 0.43),
			2.4,
			Color("6abaff") if index < current_ap else Color("344653")
		)


func _draw_badge(center: Vector2, text: String, color: Color) -> void:
	draw_circle(center, maxf(9.0, cell_size * 0.11), color)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-cell_size * 0.12, 4.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		cell_size * 0.24,
		10,
		INTENT_BADGE_TEXT_COLOR
	)


func _draw_intent_badge(
	intent: BattleIntentReadModel,
	center: Vector2
) -> void:
	var badge_text: String = "锁"
	if intent.kind == GameEnums.IntentKind.PATTERN:
		badge_text = "图"
	elif intent.kind == GameEnums.IntentKind.ENHANCE:
		badge_text = "强"
	_draw_badge(
		center + Vector2(cell_size * 0.27, -cell_size * 0.18),
		badge_text,
		INTENT_BADGE_COLOR
	)


func _find_intent(unit_id: int) -> BattleIntentReadModel:
	if _battle_model == null:
		return null
	for intent: BattleIntentReadModel in _battle_model.intents:
		if intent != null and intent.actor_unit_id == unit_id:
			return intent
	return null


func _deployment_unit(unit_id: int) -> RunUnitReadModel:
	if _deployment_model == null:
		return null
	for unit: RunUnitReadModel in _deployment_model.available_units:
		if unit != null and unit.instance_id == unit_id:
			return unit
	return null


func _coordinate_center(coordinate: Vector2i) -> Vector2:
	return Vector2(coordinate) * cell_size + Vector2.ONE * cell_size * 0.5

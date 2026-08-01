class_name BattleScreenUnitView
extends Node2D

const PLAYER_COLOR: Color = Color("43a9e6")
const ENEMY_COLOR: Color = Color("df6472")
const UNIT_BORDER_COLOR: Color = Color("f2f5f8")
const HEALTH_COLOR: Color = Color("64d38b")
const HEALTH_BACKGROUND_COLOR: Color = Color("18212d")
const TEXT_COLOR: Color = Color("f7f9fb")
const INTENT_BADGE_COLOR: Color = Color("f6c453")
const INTENT_BADGE_TEXT_COLOR: Color = Color("18212d")
const BUFF_BADGE_COLOR: Color = Color("80d8ff")

@export_range(32.0, 128.0, 1.0) var cell_size: float = 82.0

var _model: BattleReadModel


func present(model: BattleReadModel) -> void:
	_model = model
	queue_redraw()


func _draw() -> void:
	if _model == null:
		return
	for unit: BattleUnitReadModel in _model.units:
		if unit == null or not unit.has_coordinate:
			continue
		_draw_unit(unit)


func _draw_unit(unit: BattleUnitReadModel) -> void:
	var center: Vector2 = (
		Vector2(unit.coordinate) * cell_size
		+ Vector2.ONE * cell_size * 0.5
	)
	var unit_color: Color = (
		PLAYER_COLOR
		if unit.side == GameEnums.BattleSide.PLAYER
		else ENEMY_COLOR
	)
	draw_circle(center, cell_size * 0.28, unit_color)
	draw_arc(
		center,
		cell_size * 0.28,
		0.0,
		TAU,
		32,
		UNIT_BORDER_COLOR,
		3.0
	)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-cell_size * 0.4, -cell_size * 0.34),
		"%s · %d" % [unit.display_name, unit.instance_id],
		HORIZONTAL_ALIGNMENT_CENTER,
		cell_size * 0.8,
		13,
		TEXT_COLOR
	)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-cell_size * 0.4, 5.0),
		"生命%d  护盾%d  行动点%d" % [
			unit.current_health,
			unit.current_shield,
			unit.current_ap,
		],
		HORIZONTAL_ALIGNMENT_CENTER,
		cell_size * 0.8,
		12,
		TEXT_COLOR
	)
	_draw_health_bar(unit, center)
	var intent: BattleIntentReadModel = _find_intent(unit.instance_id)
	if intent != null:
		_draw_intent_badge(intent, center)
	if not unit.buffs.is_empty():
		_draw_buff_badge(unit, center)


func _draw_health_bar(unit: BattleUnitReadModel, center: Vector2) -> void:
	if unit.maximum_health <= 0:
		return
	var bar_rect: Rect2 = Rect2(
		center + Vector2(-cell_size * 0.31, cell_size * 0.34),
		Vector2(cell_size * 0.62, 7.0)
	)
	var health_ratio: float = clampf(
		float(unit.current_health) / float(unit.maximum_health),
		0.0,
		1.0
	)
	draw_rect(bar_rect, HEALTH_BACKGROUND_COLOR, true)
	draw_rect(
		Rect2(
			bar_rect.position,
			Vector2(bar_rect.size.x * health_ratio, bar_rect.size.y)
		),
		HEALTH_COLOR,
		true
	)


func _find_intent(unit_id: int) -> BattleIntentReadModel:
	if _model == null:
		return null
	for intent: BattleIntentReadModel in _model.intents:
		if intent != null and intent.actor_unit_id == unit_id:
			return intent
	return null


func _draw_intent_badge(
		intent: BattleIntentReadModel,
		center: Vector2
) -> void:
	var badge_center: Vector2 = (
		center + Vector2(cell_size * 0.27, -cell_size * 0.2)
	)
	draw_circle(badge_center, 12.0, INTENT_BADGE_COLOR)
	var badge_text: String = "锁"
	if intent.kind == GameEnums.IntentKind.PATTERN:
		badge_text = "图"
	elif intent.kind == GameEnums.IntentKind.ENHANCE:
		badge_text = "强"
	draw_string(
		ThemeDB.fallback_font,
		badge_center + Vector2(-8.0, 5.0),
		badge_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		16.0,
		12,
		INTENT_BADGE_TEXT_COLOR
	)


func _draw_buff_badge(
		unit: BattleUnitReadModel,
		center: Vector2
) -> void:
	var badge_center: Vector2 = (
		center + Vector2(-cell_size * 0.27, -cell_size * 0.2)
	)
	draw_circle(badge_center, 10.0, BUFF_BADGE_COLOR)
	draw_string(
		ThemeDB.fallback_font,
		badge_center + Vector2(-6.0, 4.0),
		str(unit.buffs.size()),
		HORIZONTAL_ALIGNMENT_CENTER,
		12.0,
		10,
		INTENT_BADGE_TEXT_COLOR
	)

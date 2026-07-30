class_name BattleUnitView
extends Node2D

const PLAYER_COLOR: Color = Color("43a9e6")
const ENEMY_COLOR: Color = Color("df6472")
const UNIT_BORDER_COLOR: Color = Color("f2f5f8")
const HEALTH_COLOR: Color = Color("64d38b")
const HEALTH_BACKGROUND_COLOR: Color = Color("18212d")
const TEXT_COLOR: Color = Color("f7f9fb")

@export_range(32.0, 128.0, 1.0) var cell_size: float = 76.0

var _battle: BattleState
var _attribute_calculator: AttributeCalculator = AttributeCalculator.new()


func present(battle_state: BattleState) -> void:
	_battle = battle_state
	queue_redraw()


func _draw() -> void:
	if _battle == null or _battle.grid == null:
		return

	for unit: UnitState in _battle.get_units():
		var position: GridCoordinate = _battle.grid.find_occupant(
				GameEnums.GridOccupantKind.UNIT,
				unit.instance_id
		)
		if position == null:
			continue
		_draw_unit(unit, position.value)


func _draw_unit(unit: UnitState, coordinate: Vector2i) -> void:
	var center: Vector2 = (
		Vector2(coordinate) * cell_size
		+ Vector2.ONE * cell_size * 0.5
	)
	var unit_color: Color = PLAYER_COLOR
	if unit.side == GameEnums.BattleSide.ENEMY:
		unit_color = ENEMY_COLOR

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

	var unit_name: String = "单位"
	if unit.definition != null and not unit.definition.display_name.is_empty():
		unit_name = unit.definition.display_name
	draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-cell_size * 0.38, -cell_size * 0.34),
			"%s 编号%d" % [unit_name, unit.instance_id],
			HORIZONTAL_ALIGNMENT_CENTER,
			cell_size * 0.76,
			12,
			TEXT_COLOR
	)

	var health_text: String = "生命%d  护盾%d  行动点%d" % [
		unit.current_health,
		unit.current_shield,
		unit.current_ap,
	]
	draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-cell_size * 0.4, 5.0),
			health_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			cell_size * 0.8,
			12,
			TEXT_COLOR
	)
	_draw_health_bar(unit, center)


func _draw_health_bar(unit: UnitState, center: Vector2) -> void:
	if unit.definition == null:
		return
	var maximum_health: int = _attribute_calculator.calculate(
			unit,
			GameEnums.AttributeType.MAX_HEALTH
	)
	if maximum_health <= 0:
		return

	var bar_rect: Rect2 = Rect2(
			center + Vector2(-cell_size * 0.31, cell_size * 0.34),
			Vector2(cell_size * 0.62, 6.0)
	)
	var health_ratio: float = clampf(
			float(unit.current_health) / float(maximum_health),
			0.0,
			1.0
	)
	draw_rect(bar_rect, HEALTH_BACKGROUND_COLOR, true)
	draw_rect(
			Rect2(bar_rect.position, Vector2(bar_rect.size.x * health_ratio, 6.0)),
			HEALTH_COLOR,
			true
	)

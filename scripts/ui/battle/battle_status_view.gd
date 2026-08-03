class_name BattleScreenStatusView
extends Control

signal deployment_start_requested
signal deployment_reset_requested
signal art_selected(slot_index: int)
signal art_use_requested
signal end_turn_requested

@export var deployment_panel: Control
@export var deployment_progress_label: Label
@export var deployment_next_unit_label: Label
@export var start_battle_button: Button
@export var reset_deployment_button: Button
@export var unit_hud: Control
@export var unit_portrait: TextureRect
@export var unit_name_label: Label
@export var health_bar: ProgressBar
@export var status_bar: HBoxContainer
@export var art_list: HBoxContainer
@export var ap_label: Label
@export var art_detail_label: Label
@export var turn_control: Control
@export var end_turn_button: Button

var _listed_art_slots: Array[int] = []
var _art_buttons: Dictionary[int, Button] = {}
var _listed_unit_id: int = 0


func get_art_button_count() -> int:
	return _art_buttons.size()


func _ready() -> void:
	start_battle_button.pressed.connect(
		func() -> void: deployment_start_requested.emit()
	)
	reset_deployment_button.pressed.connect(
		func() -> void: deployment_reset_requested.emit()
	)
	end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())


func present(
	model: BattleReadModel,
	selected_unit_id: int,
	selected_art_slot_index: int,
	pending_art_slot_index: int,
	deployed_count: int,
	deployment_total: int,
	next_deployment_name: String
) -> int:
	var in_setup: bool = (
		model != null and model.phase == GameEnums.BattlePhase.SETUP
	)
	deployment_panel.visible = in_setup
	turn_control.visible = (
		model != null and not in_setup and not model.is_terminal()
	)
	if in_setup:
		unit_hud.visible = false
		_present_deployment(
			deployed_count,
			deployment_total,
			next_deployment_name
		)
		return -1
	return _present_battle(
		model,
		selected_unit_id,
		selected_art_slot_index,
		pending_art_slot_index
	)


func _present_deployment(
	deployed_count: int,
	deployment_total: int,
	next_deployment_name: String
) -> void:
	deployment_progress_label.text = "已部署  %d/%d" % [
		deployed_count,
		deployment_total,
	]
	deployment_next_unit_label.text = (
		"下一名：%s" % next_deployment_name
		if deployed_count < deployment_total
		else "部署完成，可以开始战斗"
	)
	start_battle_button.disabled = (
		deployment_total <= 0 or deployed_count != deployment_total
	)


func _present_battle(
	model: BattleReadModel,
	selected_unit_id: int,
	selected_art_slot_index: int,
	pending_art_slot_index: int
) -> int:
	end_turn_button.disabled = (
		model == null
		or model.phase != GameEnums.BattlePhase.PLAYER_TURN
		or model.active_side != GameEnums.BattleSide.PLAYER
	)
	if model == null:
		_hide_unit_hud()
		return -1
	var selected_unit: BattleUnitReadModel = model.get_unit(selected_unit_id)
	if (
		selected_unit == null
		or selected_unit.side != GameEnums.BattleSide.PLAYER
	):
		_hide_unit_hud()
		return -1
	unit_hud.visible = true
	_present_selected_unit(selected_unit)
	var resolved_slot: int = _resolve_art_slot(
		selected_unit,
		selected_art_slot_index
	)
	var can_submit_action: bool = (
		model.phase == GameEnums.BattlePhase.PLAYER_TURN
		and model.active_side == GameEnums.BattleSide.PLAYER
	)
	_present_art_buttons(selected_unit, resolved_slot, can_submit_action)
	_present_art(selected_unit, resolved_slot, pending_art_slot_index)
	return resolved_slot


func _hide_unit_hud() -> void:
	unit_hud.visible = false
	_rebuild_art_buttons(null)
	_clear_children(status_bar)


func _present_selected_unit(unit: BattleUnitReadModel) -> void:
	unit_name_label.text = unit.display_name
	unit_portrait.tooltip_text = unit.display_name
	health_bar.max_value = maxf(1.0, float(unit.maximum_health))
	health_bar.value = float(unit.current_health)
	health_bar.tooltip_text = "生命：%d/%d" % [
		unit.current_health,
		unit.maximum_health,
	]
	ap_label.text = "行动点  %d/%d" % [unit.current_ap, unit.maximum_ap]
	_present_status_slots(unit)


func _present_status_slots(unit: BattleUnitReadModel) -> void:
	_clear_children(status_bar)
	if unit.current_shield > 0:
		_add_status_slot("盾%d" % unit.current_shield, "当前护盾")
	for buff: BattleBuffReadModel in unit.buffs:
		_add_status_slot(
			"%s×%d" % [buff.display_name.left(2), buff.stacks],
			"%s，%d层" % [buff.display_name, buff.stacks]
		)
	for art: BattleArtReadModel in unit.arts:
		if art.is_passive():
			_add_status_slot(art.display_name.left(2), "被动：%s" % art.display_name)


func _add_status_slot(text: String, tooltip: String) -> void:
	var slot: Label = Label.new()
	slot.custom_minimum_size = Vector2(40.0, 28.0)
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.text = text
	slot.tooltip_text = tooltip
	slot.add_theme_font_size_override("font_size", 11)
	slot.add_theme_color_override("font_color", Color("c8e7ef"))
	slot.add_theme_stylebox_override("normal", _status_style())
	status_bar.add_child(slot)


func _resolve_art_slot(
	unit: BattleUnitReadModel,
	preferred_slot: int
) -> int:
	if unit == null or unit.arts.is_empty():
		return -1
	for art: BattleArtReadModel in unit.arts:
		if art.slot_index == preferred_slot:
			return preferred_slot
	for art: BattleArtReadModel in unit.arts:
		if not art.is_passive():
			return art.slot_index
	return unit.arts[0].slot_index


func _present_art_buttons(
	unit: BattleUnitReadModel,
	selected_slot: int,
	can_submit_action: bool
) -> void:
	var unit_id: int = unit.instance_id if unit != null else 0
	var slots: Array[int] = []
	if unit != null:
		for art: BattleArtReadModel in unit.arts:
			slots.append(art.slot_index)
	if unit_id != _listed_unit_id or slots != _listed_art_slots:
		_rebuild_art_buttons(unit)
	if unit == null:
		return
	for art: BattleArtReadModel in unit.arts:
		var button: Button = _art_buttons.get(art.slot_index) as Button
		if button == null:
			continue
		button.text = _art_button_text(art)
		button.tooltip_text = _art_tooltip(art)
		button.disabled = (
			not can_submit_action
			or art.is_passive()
			or art.current_cooldown > 0
			or unit.current_ap < art.ap_cost
		)
		_apply_art_button_style(button, art, art.slot_index == selected_slot)


func _rebuild_art_buttons(unit: BattleUnitReadModel) -> void:
	_clear_children(art_list)
	_art_buttons.clear()
	_listed_art_slots.clear()
	_listed_unit_id = unit.instance_id if unit != null else 0
	if unit == null:
		return
	for art: BattleArtReadModel in unit.arts:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(132.0, 58.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_art_button_pressed.bind(art.slot_index))
		art_list.add_child(button)
		_art_buttons[art.slot_index] = button
		_listed_art_slots.append(art.slot_index)


func _art_button_text(art: BattleArtReadModel) -> String:
	if art.is_passive():
		return "%s\n被动" % art.display_name
	var state: String = (
		"冷却%d" % art.current_cooldown
		if art.current_cooldown > 0
		else "AP %d" % art.ap_cost
	)
	return "%s\n%s" % [art.display_name, state]


func _art_tooltip(art: BattleArtReadModel) -> String:
	return "%s\n射程：%d—%d　基础冷却：%d" % [
		art.display_name,
		art.minimum_range,
		art.maximum_range,
		art.base_cooldown,
	]


func _apply_art_button_style(
	button: Button,
	art: BattleArtReadModel,
	selected: bool
) -> void:
	var border: Color = Color("40515d")
	var fill: Color = Color("14212a")
	var text_color: Color = Color("cdd9df")
	if selected:
		border = Color("43cabb")
		fill = Color("18333a")
		text_color = Color("efffff")
	elif art.current_cooldown > 0 or art.is_passive():
		text_color = Color("7d8c95")
	button.add_theme_stylebox_override(
		"normal",
		_art_style(fill, border, 2 if selected else 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		_art_style(fill.lightened(0.08), border.lightened(0.1), 2)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_art_style(fill.darkened(0.08), border, 2)
	)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override(
		"font_hover_color",
		text_color.lightened(0.08)
	)


func _present_art(
	unit: BattleUnitReadModel,
	selected_slot: int,
	pending_slot: int
) -> void:
	var art: BattleArtReadModel = unit.get_art(selected_slot)
	if art == null:
		art_detail_label.text = "没有可用技艺"
		return
	var status: String = "可用"
	if art.is_passive():
		status = "持续生效"
	elif art.current_cooldown > 0:
		status = "冷却%d回合" % art.current_cooldown
	elif unit.current_ap < art.ap_cost:
		status = "行动点不足"
	elif pending_slot == selected_slot:
		status = "选择目标中，右键取消"
	art_detail_label.text = "%s · %s · 射程%d—%d" % [
		BattleUiTextFormatter.art_category_text(art.category),
		status,
		art.minimum_range,
		art.maximum_range,
	]


func _on_art_button_pressed(slot_index: int) -> void:
	art_selected.emit(slot_index)
	art_use_requested.emit()


func _art_style(
	fill: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style


func _status_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("172630")
	style.border_color = Color("3d5e69")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

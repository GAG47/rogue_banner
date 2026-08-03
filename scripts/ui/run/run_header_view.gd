class_name RunHeaderView
extends HBoxContainer

signal map_requested
signal build_requested
signal settings_requested
signal scroll_use_requested(stack_instance_id: int)
signal scroll_discard_requested(stack_instance_id: int)

@export var hero_portrait: TextureRect
@export var gold_label: Label
@export var scroll_slot_row: HBoxContainer
@export var map_button: Button
@export var build_button: Button
@export var settings_button: Button
@export var scroll_detail_popup: PanelContainer
@export var scroll_detail_name_label: Label
@export var scroll_detail_effect_label: Label
@export var scroll_detail_meta_label: Label
@export var scroll_action_popup: PanelContainer
@export var scroll_use_button: Button
@export var scroll_discard_button: Button

var _selected_scroll_stack_id: int = 0
var _selected_scroll_source_button: Button
var _hovered_scroll_slot: Button
var _current_route: RunSessionRoute.Value = RunSessionRoute.Value.MAP


func _ready() -> void:
	if not map_button.pressed.is_connected(_on_map_pressed):
		map_button.pressed.connect(_on_map_pressed)
	if not build_button.pressed.is_connected(_on_build_pressed):
		build_button.pressed.connect(_on_build_pressed)
	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if not scroll_use_button.pressed.is_connected(_on_scroll_use_pressed):
		scroll_use_button.pressed.connect(_on_scroll_use_pressed)
	if not scroll_discard_button.pressed.is_connected(
		_on_scroll_discard_pressed
	):
		scroll_discard_button.pressed.connect(_on_scroll_discard_pressed)


func _input(event: InputEvent) -> void:
	if not scroll_action_popup.visible:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not _is_pointer_over_open_scroll_controls(motion.position):
			_hovered_scroll_slot = null
			close_scroll_action()
		return
	if event is not InputEventMouseButton:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	if _is_pointer_over_open_scroll_controls(button.position):
		return
	_hovered_scroll_slot = null
	close_scroll_action()


func _is_pointer_over_open_scroll_controls(global_position: Vector2) -> bool:
	if (
		_selected_scroll_source_button != null
		and is_instance_valid(_selected_scroll_source_button)
		and _selected_scroll_source_button.get_global_rect().has_point(
			global_position
		)
	):
		return true
	if (
		scroll_detail_popup.visible
		and scroll_detail_popup.get_global_rect().has_point(global_position)
	):
		return true
	return (
		scroll_action_popup.visible
		and scroll_action_popup.get_global_rect().has_point(global_position)
	)


func present(
	summary: RunSummaryReadModel,
	inventory: InventoryReadModel,
	route: RunSessionRoute.Value,
	map_visible: bool
) -> void:
	if summary == null:
		return
	_current_route = route
	_reset_scroll_popups()
	hero_portrait.texture = summary.hero_portrait
	hero_portrait.tooltip_text = "英雄：%s" % summary.hero_name
	gold_label.text = "金币  %d" % summary.gold
	gold_label.tooltip_text = "当前拥有%d金币" % summary.gold
	_present_scroll_slots(inventory, summary.scroll_capacity)
	map_button.set_pressed_no_signal(map_visible)
	map_button.disabled = route == RunSessionRoute.Value.RESULT
	build_button.disabled = route == RunSessionRoute.Value.RESULT


func present_battle_scrolls(
	scrolls: Array[BattleScrollReadModel],
	capacity: int
) -> void:
	_reset_scroll_popups()
	_clear_children(scroll_slot_row)
	for slot_index: int in range(capacity):
		var scroll: BattleScrollReadModel
		if slot_index < scrolls.size():
			scroll = scrolls[slot_index]
		if scroll == null or scroll.quantity <= 0:
			_add_empty_scroll_slot()
			continue
		_add_scroll_slot(
			scroll.stack_instance_id,
			scroll.display_name,
			scroll.quantity,
			scroll.minimum_range,
			scroll.maximum_range,
			scroll.effect_summary
		)


func _present_scroll_slots(
	inventory: InventoryReadModel,
	capacity: int
) -> void:
	_clear_children(scroll_slot_row)
	for slot_index: int in range(capacity):
		var scroll: RunScrollReadModel
		if inventory != null and slot_index < inventory.scrolls.size():
			scroll = inventory.scrolls[slot_index]
		if scroll == null:
			_add_empty_scroll_slot()
			continue
		_add_scroll_slot(
			scroll.stack_instance_id,
			scroll.display_name,
			scroll.quantity,
			scroll.minimum_range,
			scroll.maximum_range,
			scroll.effect_summary
		)


func close_scroll_action() -> void:
	_selected_scroll_stack_id = 0
	_selected_scroll_source_button = null
	if scroll_action_popup != null:
		scroll_action_popup.visible = false
	if _hovered_scroll_slot == null and scroll_detail_popup != null:
		scroll_detail_popup.visible = false


func _add_empty_scroll_slot() -> void:
	var slot: Button = _create_scroll_slot_button(false)
	slot.text = "□"
	slot.disabled = true
	scroll_slot_row.add_child(slot)


func _add_scroll_slot(
	stack_instance_id: int,
	display_name: String,
	quantity: int,
	minimum_range: int,
	maximum_range: int,
	effect_summary: String
) -> void:
	var slot: Button = _create_scroll_slot_button(true)
	slot.text = "卷" if quantity == 1 else "卷%d" % quantity
	slot.disabled = quantity <= 0
	slot.mouse_entered.connect(
		_on_scroll_slot_mouse_entered.bind(
			slot,
			display_name,
			quantity,
			minimum_range,
			maximum_range,
			effect_summary
		)
	)
	slot.mouse_exited.connect(_on_scroll_slot_mouse_exited.bind(slot))
	slot.pressed.connect(
		_on_scroll_slot_pressed.bind(
			stack_instance_id,
			slot,
			display_name,
			quantity,
			minimum_range,
			maximum_range,
			effect_summary
		)
	)
	scroll_slot_row.add_child(slot)


func _create_scroll_slot_button(occupied: bool) -> Button:
	var slot: Button = Button.new()
	slot.custom_minimum_size = Vector2(42.0, 38.0)
	slot.focus_mode = Control.FOCUS_NONE
	var normal: StyleBoxFlat = _scroll_slot_style(occupied)
	slot.add_theme_stylebox_override("normal", normal)
	slot.add_theme_stylebox_override(
		"hover",
		_scroll_slot_style(occupied, true)
	)
	slot.add_theme_stylebox_override(
		"pressed",
		_scroll_slot_style(occupied, true)
	)
	slot.add_theme_stylebox_override("disabled", normal)
	slot.add_theme_color_override(
		"font_color",
		Color("d7f1e8") if occupied else Color("74828c")
	)
	return slot


func _on_scroll_slot_pressed(
	stack_instance_id: int,
	source_button: Button,
	display_name: String,
	quantity: int,
	minimum_range: int,
	maximum_range: int,
	effect_summary: String
) -> void:
	if (
		scroll_action_popup.visible
		and _selected_scroll_stack_id == stack_instance_id
	):
		close_scroll_action()
		return
	_selected_scroll_stack_id = stack_instance_id
	_selected_scroll_source_button = source_button
	_show_scroll_detail(
		source_button,
		display_name,
		quantity,
		minimum_range,
		maximum_range,
		effect_summary
	)
	scroll_use_button.disabled = _current_route != RunSessionRoute.Value.BATTLE
	scroll_use_button.tooltip_text = (
		"选择当前我方单位作为使用者"
		if _current_route == RunSessionRoute.Value.BATTLE
		else "只能在战斗中使用卷轴"
	)
	scroll_discard_button.disabled = not _can_discard_in_route()
	scroll_discard_button.tooltip_text = (
		"丢弃一张该卷轴"
		if _can_discard_in_route()
		else "当前流程不能丢弃卷轴"
	)
	scroll_action_popup.visible = true
	_position_scroll_action_popup(source_button)


func _position_scroll_action_popup(source_button: Button) -> void:
	var popup_parent: Control = scroll_action_popup.get_parent() as Control
	if popup_parent == null:
		return
	var target: Vector2
	if scroll_detail_popup.visible:
		target = scroll_detail_popup.position
		target.y += scroll_detail_popup.size.y - 1.0
	else:
		target = source_button.global_position - popup_parent.global_position
		target.y += source_button.size.y
	var maximum_x: float = maxf(
		8.0,
		popup_parent.size.x - scroll_action_popup.size.x - 8.0
	)
	scroll_action_popup.position = Vector2(
		clampf(target.x, 8.0, maximum_x),
		target.y
	)


func _on_scroll_slot_mouse_entered(
	source_button: Button,
	display_name: String,
	quantity: int,
	minimum_range: int,
	maximum_range: int,
	effect_summary: String
) -> void:
	_hovered_scroll_slot = source_button
	_show_scroll_detail(
		source_button,
		display_name,
		quantity,
		minimum_range,
		maximum_range,
		effect_summary
	)


func _on_scroll_slot_mouse_exited(source_button: Button) -> void:
	if _hovered_scroll_slot == source_button:
		_hovered_scroll_slot = null
	if _selected_scroll_source_button != source_button:
		scroll_detail_popup.visible = false


func _show_scroll_detail(
	source_button: Button,
	display_name: String,
	quantity: int,
	minimum_range: int,
	maximum_range: int,
	effect_summary: String
) -> void:
	scroll_detail_name_label.text = display_name
	scroll_detail_effect_label.text = effect_summary
	scroll_detail_meta_label.text = "数量 %d　射程 %d—%d" % [
		quantity,
		minimum_range,
		maximum_range,
	]
	scroll_detail_popup.visible = true
	scroll_detail_popup.reset_size()
	_position_scroll_detail_popup(source_button)


func _position_scroll_detail_popup(source_button: Button) -> void:
	var popup_parent: Control = scroll_detail_popup.get_parent() as Control
	if popup_parent == null:
		return
	var target: Vector2 = (
		source_button.global_position - popup_parent.global_position
	)
	target.y += source_button.size.y
	var maximum_x: float = maxf(
		8.0,
		popup_parent.size.x - scroll_detail_popup.size.x - 8.0
	)
	scroll_detail_popup.position = Vector2(
		clampf(target.x, 8.0, maximum_x),
		target.y
	)


func _reset_scroll_popups() -> void:
	_selected_scroll_stack_id = 0
	_selected_scroll_source_button = null
	_hovered_scroll_slot = null
	if scroll_action_popup != null:
		scroll_action_popup.visible = false
	if scroll_detail_popup != null:
		scroll_detail_popup.visible = false


func _on_scroll_use_pressed() -> void:
	if _selected_scroll_stack_id <= 0:
		return
	var stack_instance_id: int = _selected_scroll_stack_id
	close_scroll_action()
	scroll_use_requested.emit(stack_instance_id)


func _on_scroll_discard_pressed() -> void:
	if _selected_scroll_stack_id <= 0:
		return
	var stack_instance_id: int = _selected_scroll_stack_id
	close_scroll_action()
	scroll_discard_requested.emit(stack_instance_id)


func _on_map_pressed() -> void:
	close_scroll_action()
	map_requested.emit()


func _on_build_pressed() -> void:
	close_scroll_action()
	build_requested.emit()


func _on_settings_pressed() -> void:
	close_scroll_action()
	settings_requested.emit()


func _can_discard_in_route() -> bool:
	return _current_route in [
		RunSessionRoute.Value.MAP,
		RunSessionRoute.Value.BATTLE,
		RunSessionRoute.Value.REWARD,
	]


func _scroll_slot_style(
	occupied: bool,
	highlighted: bool = false
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("20313a") if highlighted else (
		Color("18242d") if occupied else Color("111921")
	)
	style.border_color = Color("83d8c7") if highlighted else (
		Color("6cae9e") if occupied else Color("46535d")
	)
	style.set_border_width_all(2 if occupied else 1)
	style.set_corner_radius_all(6)
	return style


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

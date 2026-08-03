class_name RunHeaderView
extends HBoxContainer

signal map_requested
signal build_requested
signal settings_requested

@export var hero_portrait: TextureRect
@export var gold_label: Label
@export var scroll_slot_row: HBoxContainer
@export var map_button: Button
@export var build_button: Button
@export var settings_button: Button


func _ready() -> void:
	map_button.pressed.connect(func() -> void: map_requested.emit())
	build_button.pressed.connect(func() -> void: build_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())


func present(
	summary: RunSummaryReadModel,
	inventory: InventoryReadModel,
	route: RunSessionRoute.Value,
	map_visible: bool
) -> void:
	if summary == null:
		return
	hero_portrait.texture = summary.hero_portrait
	hero_portrait.tooltip_text = "英雄：%s" % summary.hero_name
	gold_label.text = "金币  %d" % summary.gold
	gold_label.tooltip_text = "当前拥有%d金币" % summary.gold
	_present_scroll_slots(inventory, summary.scroll_capacity)
	map_button.set_pressed_no_signal(map_visible)
	map_button.disabled = route == RunSessionRoute.Value.RESULT
	build_button.disabled = route == RunSessionRoute.Value.RESULT


func _present_scroll_slots(
	inventory: InventoryReadModel,
	capacity: int
) -> void:
	_clear_children(scroll_slot_row)
	for slot_index: int in range(capacity):
		var scroll: RunScrollReadModel
		if inventory != null and slot_index < inventory.scrolls.size():
			scroll = inventory.scrolls[slot_index]
		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = Vector2(42.0, 38.0)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_theme_stylebox_override(
			"panel",
			_scroll_slot_style(scroll != null)
		)
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if scroll == null:
			label.text = "□"
			label.add_theme_color_override("font_color", Color("74828c"))
			slot.tooltip_text = "空卷轴槽"
		else:
			label.text = "卷" if scroll.quantity == 1 else "卷%d" % scroll.quantity
			label.add_theme_color_override("font_color", Color("d7f1e8"))
			slot.tooltip_text = "%s × %d" % [
				scroll.display_name,
				scroll.quantity,
			]
		slot.add_child(label)
		scroll_slot_row.add_child(slot)


func _scroll_slot_style(occupied: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("18242d") if occupied else Color("111921")
	style.border_color = Color("6cae9e") if occupied else Color("46535d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

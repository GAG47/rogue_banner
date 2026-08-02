class_name InventoryOverlayView
extends ColorRect

signal command_requested(command: RunCommand)
signal closed

@export var summary_label: Label
@export var relic_label: Label
@export var unit_selector: OptionButton
@export var art_selector: OptionButton
@export var slot_selector: OptionButton
@export var scroll_selector: OptionButton
@export var install_button: Button
@export var uninstall_button: Button
@export var upgrade_button: Button
@export var forget_button: Button
@export var discard_scroll_button: Button
@export var close_button: Button

var _inventory: InventoryReadModel


func _ready() -> void:
	unit_selector.item_selected.connect(
		func(_index: int) -> void: _rebuild_slots()
	)
	install_button.pressed.connect(_on_install_pressed)
	uninstall_button.pressed.connect(_on_uninstall_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	forget_button.pressed.connect(_on_forget_pressed)
	discard_scroll_button.pressed.connect(_on_discard_scroll_pressed)
	close_button.pressed.connect(func() -> void: closed.emit())


func present(inventory: InventoryReadModel) -> void:
	_inventory = inventory
	visible = true
	unit_selector.clear()
	art_selector.clear()
	scroll_selector.clear()
	if inventory == null:
		return
	for unit: RunUnitReadModel in inventory.units:
		unit_selector.add_item("%s · %d/%d" % [
			unit.display_name,
			unit.current_health,
			unit.maximum_health,
		])
		unit_selector.set_item_metadata(unit_selector.item_count - 1, unit.instance_id)
	for art: RunArtReadModel in inventory.arts:
		art_selector.add_item("%s%s" % [
			art.display_name,
			"（已安装）" if art.owner_unit_id > 0 else "",
		])
		art_selector.set_item_metadata(art_selector.item_count - 1, art.instance_id)
	for scroll: RunScrollReadModel in inventory.scrolls:
		scroll_selector.add_item("%s × %d" % [scroll.display_name, scroll.quantity])
		scroll_selector.set_item_metadata(
			scroll_selector.item_count - 1,
			scroll.stack_instance_id
		)
	summary_label.text = "单位 %d/%d · 技艺 %d · 遗物 %d · 卷轴 %d/%d" % [
		inventory.units.size(),
		inventory.team_capacity,
		inventory.arts.size(),
		inventory.relics.size(),
		inventory.scrolls.size(),
		inventory.scroll_capacity,
	]
	var relic_names: Array[String] = []
	for relic: RunRelicReadModel in inventory.relics:
		relic_names.append(relic.display_name)
	relic_label.text = "遗物：%s" % (
		"、".join(relic_names) if not relic_names.is_empty() else "无"
	)
	_rebuild_slots()


func _rebuild_slots() -> void:
	slot_selector.clear()
	var unit: RunUnitReadModel = _selected_unit()
	if unit == null:
		return
	for index: int in range(unit.slot_count):
		var name: String = (
			unit.installed_art_names[index]
			if index < unit.installed_art_names.size()
			else "空插槽"
		)
		slot_selector.add_item("插槽%d · %s" % [index + 1, name])
		slot_selector.set_item_metadata(index, index)


func _selected_unit() -> RunUnitReadModel:
	if _inventory == null or unit_selector.selected < 0:
		return null
	return _inventory.get_unit(int(unit_selector.get_selected_metadata()))


func _on_install_pressed() -> void:
	var unit: RunUnitReadModel = _selected_unit()
	if unit == null or art_selector.selected < 0 or slot_selector.selected < 0:
		return
	command_requested.emit(InstallArtCommand.create(
		unit.instance_id,
		int(art_selector.get_selected_metadata()),
		int(slot_selector.get_selected_metadata())
	))


func _on_uninstall_pressed() -> void:
	var unit: RunUnitReadModel = _selected_unit()
	if unit != null and slot_selector.selected >= 0:
		command_requested.emit(UninstallArtCommand.create(
			unit.instance_id,
			int(slot_selector.get_selected_metadata())
		))


func _on_upgrade_pressed() -> void:
	if art_selector.selected >= 0:
		command_requested.emit(UpgradeArtCommand.create(
			int(art_selector.get_selected_metadata())
		))


func _on_forget_pressed() -> void:
	if art_selector.selected >= 0:
		command_requested.emit(ForgetArtCommand.create(
			int(art_selector.get_selected_metadata())
		))


func _on_discard_scroll_pressed() -> void:
	if scroll_selector.selected >= 0:
		command_requested.emit(ConsumeScrollCommand.create(
			int(scroll_selector.get_selected_metadata()),
			1
		))

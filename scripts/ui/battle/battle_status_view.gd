class_name BattleScreenStatusView
extends VBoxContainer

signal deployment_start_requested
signal deployment_reset_requested
signal art_selected(slot_index: int)
signal art_use_requested
signal scroll_selected(stack_instance_id: int)
signal scroll_use_requested
signal end_turn_requested
signal battle_restart_requested

@export var deployment_panel: Control
@export var deployment_progress_label: Label
@export var deployment_next_unit_label: Label
@export var start_battle_button: Button
@export var reset_deployment_button: Button
@export var battle_panel: Control
@export var selected_unit_label: Label
@export var status_effects_label: Label
@export var art_selector: OptionButton
@export var art_detail_label: Label
@export var use_art_button: Button
@export var intent_label: Label
@export var relic_label: Label
@export var scroll_selector: OptionButton
@export var scroll_detail_label: Label
@export var use_scroll_button: Button
@export var end_turn_button: Button
@export var restart_battle_button: Button

var _listed_art_slots: Array[int] = []
var _listed_scroll_ids: Array[int] = []


func set_restart_available(available: bool) -> void:
	restart_battle_button.visible = available


func _ready() -> void:
	if not start_battle_button.pressed.is_connected(_on_start_battle_pressed):
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if not reset_deployment_button.pressed.is_connected(
		_on_reset_deployment_pressed
	):
		reset_deployment_button.pressed.connect(
			_on_reset_deployment_pressed
		)
	if not art_selector.item_selected.is_connected(_on_art_item_selected):
		art_selector.item_selected.connect(_on_art_item_selected)
	if not use_art_button.pressed.is_connected(_on_use_art_pressed):
		use_art_button.pressed.connect(_on_use_art_pressed)
	if not scroll_selector.item_selected.is_connected(_on_scroll_item_selected):
		scroll_selector.item_selected.connect(_on_scroll_item_selected)
	if not use_scroll_button.pressed.is_connected(_on_use_scroll_pressed):
		use_scroll_button.pressed.connect(_on_use_scroll_pressed)
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if not restart_battle_button.pressed.is_connected(
		_on_restart_battle_pressed
	):
		restart_battle_button.pressed.connect(_on_restart_battle_pressed)


func present(
		model: BattleReadModel,
		selected_unit_id: int,
		selected_art_slot_index: int,
		pending_art_slot_index: int,
		selected_scroll_stack_id: int,
		pending_scroll_stack_id: int,
		deployed_count: int,
		deployment_total: int,
		next_deployment_name: String
) -> int:
	var in_setup: bool = (
		model != null and model.phase == GameEnums.BattlePhase.SETUP
	)
	deployment_panel.visible = in_setup
	battle_panel.visible = not in_setup
	if in_setup:
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
		pending_art_slot_index,
		selected_scroll_stack_id,
		pending_scroll_stack_id
	)


func _present_deployment(
		deployed_count: int,
		deployment_total: int,
		next_deployment_name: String
) -> void:
	deployment_progress_label.text = "部署进度：%d / %d" % [
		deployed_count,
		deployment_total,
	]
	deployment_next_unit_label.text = (
		"下一名单位：%s\n点击蓝色部署格放置单位。"
		% next_deployment_name
		if deployed_count < deployment_total
		else "所有单位已经部署，可以开始战斗。"
	)
	start_battle_button.disabled = (
		deployment_total <= 0 or deployed_count != deployment_total
	)


func _present_battle(
		model: BattleReadModel,
		selected_unit_id: int,
		selected_art_slot_index: int,
		pending_art_slot_index: int,
		selected_scroll_stack_id: int,
		pending_scroll_stack_id: int
) -> int:
	if model == null:
		_present_unavailable()
		return -1
	var selected_unit: BattleUnitReadModel = model.get_unit(selected_unit_id)
	_present_selected_unit(selected_unit)
	var resolved_slot: int = _rebuild_art_options(
		selected_unit,
		selected_art_slot_index
	)
	_present_art(
		model,
		selected_unit,
		resolved_slot,
		pending_art_slot_index
	)
	_present_intents(model)
	_present_run_items(
		model,
		selected_unit,
		selected_scroll_stack_id,
		pending_scroll_stack_id
	)
	end_turn_button.disabled = (
		model.phase != GameEnums.BattlePhase.PLAYER_TURN
		or model.active_side != GameEnums.BattleSide.PLAYER
	)
	return resolved_slot


func _present_run_items(
	model: BattleReadModel,
	selected_unit: BattleUnitReadModel,
	selected_scroll_stack_id: int,
	pending_scroll_stack_id: int
) -> void:
	var relic_names: Array[String] = []
	for relic: BattleRelicReadModel in model.relics:
		relic_names.append(relic.display_name)
	relic_label.text = "遗物：%s" % (
		"、".join(relic_names) if not relic_names.is_empty() else "无"
	)
	_listed_scroll_ids.clear()
	scroll_selector.set_block_signals(true)
	scroll_selector.clear()
	var selected_item: int = -1
	for scroll: BattleScrollReadModel in model.scrolls:
		scroll_selector.add_item("%s × %d" % [
			scroll.display_name,
			scroll.quantity,
		])
		_listed_scroll_ids.append(scroll.stack_instance_id)
		if scroll.stack_instance_id == selected_scroll_stack_id:
			selected_item = _listed_scroll_ids.size() - 1
	if selected_item < 0 and not _listed_scroll_ids.is_empty():
		selected_item = 0
	if selected_item >= 0:
		scroll_selector.select(selected_item)
	scroll_selector.disabled = _listed_scroll_ids.is_empty()
	scroll_selector.set_block_signals(false)
	var selected_scroll: BattleScrollReadModel
	if selected_item >= 0:
		selected_scroll = model.scrolls[selected_item]
	if selected_scroll == null:
		scroll_detail_label.text = "卷轴：无"
		use_scroll_button.disabled = true
		return
	scroll_detail_label.text = "%s · 数量%d · 射程%d—%d" % [
		selected_scroll.display_name,
		selected_scroll.quantity,
		selected_scroll.minimum_range,
		selected_scroll.maximum_range,
	]
	use_scroll_button.text = (
		"取消卷轴目标选择" if pending_scroll_stack_id > 0 else "使用卷轴"
	)
	use_scroll_button.disabled = (
		selected_unit == null
		or selected_unit.side != GameEnums.BattleSide.PLAYER
		or selected_scroll.quantity <= 0
		or model.phase != GameEnums.BattlePhase.PLAYER_TURN
		or model.active_side != GameEnums.BattleSide.PLAYER
	)


func _present_selected_unit(unit: BattleUnitReadModel) -> void:
	if unit == null:
		selected_unit_label.text = "当前单位\n未选择"
		status_effects_label.text = "状态与被动\n未选择单位"
		return
	selected_unit_label.text = (
		"%s · 编号%d\n生命：%d / %d　护盾：%d\n"
		+ "行动点：%d / %d　位置：%d,%d"
	) % [
		unit.display_name,
		unit.instance_id,
		unit.current_health,
		unit.maximum_health,
		unit.current_shield,
		unit.current_ap,
		unit.maximum_ap,
		unit.coordinate.x,
		unit.coordinate.y,
	]
	var status_lines: Array[String] = ["状态与被动"]
	var has_status: bool = false
	for buff: BattleBuffReadModel in unit.buffs:
		status_lines.append(
			"增益：%s · %d层 · 剩余%d回合" % [
				buff.display_name,
				buff.stacks,
				buff.remaining_turns,
			]
		)
		has_status = true
	for art: BattleArtReadModel in unit.arts:
		if art.is_passive():
			status_lines.append("被动：%s" % art.display_name)
			has_status = true
	if not has_status:
		status_lines.append("无")
	status_effects_label.text = "\n".join(status_lines)


func _rebuild_art_options(
		unit: BattleUnitReadModel,
		preferred_slot: int
) -> int:
	_listed_art_slots.clear()
	art_selector.set_block_signals(true)
	art_selector.clear()
	if unit == null:
		art_selector.disabled = true
		art_selector.set_block_signals(false)
		return -1
	var selected_item: int = -1
	var first_active_item: int = -1
	for art: BattleArtReadModel in unit.arts:
		var label: String = "%d　%s" % [
			art.slot_index + 1,
			art.display_name,
		]
		if art.is_passive():
			label += "（被动）"
		elif art.current_cooldown > 0:
			label += "（冷却%d）" % art.current_cooldown
		art_selector.add_item(label)
		_listed_art_slots.append(art.slot_index)
		var item_index: int = _listed_art_slots.size() - 1
		art_selector.set_item_metadata(item_index, art.slot_index)
		if art.slot_index == preferred_slot:
			selected_item = item_index
		if first_active_item < 0 and not art.is_passive():
			first_active_item = item_index
	if _listed_art_slots.is_empty():
		art_selector.disabled = true
		art_selector.set_block_signals(false)
		return -1
	if selected_item < 0:
		selected_item = first_active_item if first_active_item >= 0 else 0
	art_selector.select(selected_item)
	art_selector.disabled = false
	art_selector.set_block_signals(false)
	return _listed_art_slots[selected_item]


func _present_art(
		model: BattleReadModel,
		unit: BattleUnitReadModel,
		selected_slot: int,
		pending_slot: int
) -> void:
	var art: BattleArtReadModel
	if unit != null:
		art = unit.get_art(selected_slot)
	if art == null:
		art_detail_label.text = "技艺：未选择"
		use_art_button.disabled = true
		return
	var status: String = "可用"
	if art.is_passive():
		status = "持续生效"
	elif art.current_cooldown > 0:
		status = "冷却%d回合" % art.current_cooldown
	elif unit.current_ap < art.ap_cost:
		status = "行动点不足"
	art_detail_label.text = (
		"%s · %s\n消耗：%d　基础冷却：%d　状态：%s\n"
		+ "目标：%s　射程：%d—%d"
	) % [
		art.display_name,
		BattleUiTextFormatter.art_category_text(art.category),
		art.ap_cost,
		art.base_cooldown,
		status,
		BattleUiTextFormatter.target_kind_text(art.target_kind),
		art.minimum_range,
		art.maximum_range,
	]
	use_art_button.text = (
		"取消目标选择" if pending_slot >= 0 else "选择技艺目标"
	)
	use_art_button.disabled = (
		unit.side != GameEnums.BattleSide.PLAYER
		or
		art.is_passive()
		or art.current_cooldown > 0
		or unit.current_ap < art.ap_cost
		or model.phase != GameEnums.BattlePhase.PLAYER_TURN
		or model.active_side != GameEnums.BattleSide.PLAYER
	)


func _present_intents(model: BattleReadModel) -> void:
	var lines: Array[String] = []
	if model.intents.is_empty():
		lines.append("当前没有敌人意图。")
	for intent: BattleIntentReadModel in model.intents:
		var line: String = "%s · %s · %s" % [
			intent.actor_name,
			BattleUiTextFormatter.intent_kind_text(intent.kind),
			intent.intent_name,
		]
		if intent.has_move_destination:
			line += "\n  移动终点：%d,%d" % [
				intent.move_destination.x,
				intent.move_destination.y,
			]
		if not intent.locked_unit_ids.is_empty():
			var target: BattleUnitReadModel = model.get_unit(
				intent.locked_unit_ids[0]
			)
			line += "\n  锁定单位：%s" % (
				target.display_name if target != null else "已离场单位"
			)
		elif not intent.locked_cells.is_empty():
			line += "\n  锁定格子：%d,%d" % [
				intent.locked_cells[0].x,
				intent.locked_cells[0].y,
			]
		line += "\n  当前影响：%d格%s" % [
			intent.affected_cells.size(),
			"" if intent.currently_valid else "（可能落空）",
		]
		lines.append(line)
	intent_label.text = "\n\n".join(lines)


func _present_unavailable() -> void:
	selected_unit_label.text = "当前单位\n不可用"
	status_effects_label.text = "状态与被动\n不可用"
	art_selector.clear()
	art_selector.disabled = true
	art_detail_label.text = "技艺：不可用"
	intent_label.text = "意图：不可用"
	use_art_button.disabled = true
	scroll_selector.clear()
	scroll_selector.disabled = true
	scroll_detail_label.text = "卷轴：不可用"
	relic_label.text = "遗物：不可用"
	use_scroll_button.disabled = true
	end_turn_button.disabled = true


func _on_start_battle_pressed() -> void:
	deployment_start_requested.emit()


func _on_reset_deployment_pressed() -> void:
	deployment_reset_requested.emit()


func _on_art_item_selected(item_index: int) -> void:
	if item_index < 0 or item_index >= _listed_art_slots.size():
		art_selected.emit(-1)
		return
	art_selected.emit(_listed_art_slots[item_index])


func _on_use_art_pressed() -> void:
	art_use_requested.emit()


func _on_scroll_item_selected(item_index: int) -> void:
	if item_index < 0 or item_index >= _listed_scroll_ids.size():
		scroll_selected.emit(0)
		return
	scroll_selected.emit(_listed_scroll_ids[item_index])


func _on_use_scroll_pressed() -> void:
	scroll_use_requested.emit()


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()


func _on_restart_battle_pressed() -> void:
	battle_restart_requested.emit()

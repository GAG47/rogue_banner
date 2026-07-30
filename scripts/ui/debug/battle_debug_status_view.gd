class_name BattleDebugStatusView
extends VBoxContainer

signal art_selected(slot_index: int)
signal art_use_requested
signal end_turn_requested
signal battle_reset_requested

@export var phase_label: Label
@export var round_label: Label
@export var selected_unit_label: Label
@export var art_selector: OptionButton
@export var art_status_label: Label
@export var use_art_button: Button
@export var end_turn_button: Button
@export var reset_button: Button

var _listed_art_slots: Array[int] = []
var _attribute_calculator: AttributeCalculator = AttributeCalculator.new()


func _ready() -> void:
	if (
		art_selector != null
		and not art_selector.item_selected.is_connected(_on_art_item_selected)
	):
		art_selector.item_selected.connect(_on_art_item_selected)
	if (
		use_art_button != null
		and not use_art_button.pressed.is_connected(_on_use_art_pressed)
	):
		use_art_button.pressed.connect(_on_use_art_pressed)
	if (
		end_turn_button != null
		and not end_turn_button.pressed.is_connected(_on_end_turn_pressed)
	):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if (
		reset_button != null
		and not reset_button.pressed.is_connected(_on_reset_pressed)
	):
		reset_button.pressed.connect(_on_reset_pressed)


func rebuild_art_options(unit: UnitState, preferred_slot: int) -> int:
	_listed_art_slots.clear()
	if art_selector == null:
		return -1
	art_selector.clear()
	if unit == null:
		art_selector.disabled = true
		return -1

	var selected_item: int = -1
	var first_active_item: int = -1
	for slot_index: int in range(unit.arts.size()):
		var art_state: ArtState = unit.arts[slot_index]
		if art_state == null or art_state.definition == null:
			continue
		var label: String = "%d　%s" % [
			slot_index + 1,
			art_state.definition.display_name,
		]
		if art_state.definition.category == GameEnums.ArtCategory.PASSIVE:
			label += "（被动）"
		elif art_state.current_cooldown > 0:
			label += "（冷却%d）" % art_state.current_cooldown
		art_selector.add_item(label)
		_listed_art_slots.append(slot_index)
		var item_index: int = _listed_art_slots.size() - 1
		art_selector.set_item_metadata(item_index, slot_index)
		if slot_index == preferred_slot:
			selected_item = item_index
		if (
			first_active_item < 0
			and art_state.definition.category != GameEnums.ArtCategory.PASSIVE
		):
			first_active_item = item_index

	if _listed_art_slots.is_empty():
		art_selector.disabled = true
		return -1
	if selected_item < 0:
		selected_item = first_active_item if first_active_item >= 0 else 0
	art_selector.select(selected_item)
	art_selector.disabled = false
	return _listed_art_slots[selected_item]


func present(
	battle: BattleState,
	selected_unit_id: int,
	selected_art_slot_index: int,
	pending_art_slot_index: int
) -> void:
	if battle == null:
		_present_unavailable()
		return

	phase_label.text = "阶段：%s\n当前行动方：%s" % [
		BattleDebugTextFormatter.phase_text(battle.phase),
		BattleDebugTextFormatter.side_text(battle.active_side),
	]
	round_label.text = "轮次：%d" % battle.round_number
	end_turn_button.disabled = (
		battle.phase == GameEnums.BattlePhase.VICTORY
		or battle.phase == GameEnums.BattlePhase.FAILURE
	)
	end_turn_button.text = (
		"结束玩家回合"
		if battle.active_side == GameEnums.BattleSide.PLAYER
		else "推进敌方回合"
	)

	var selected_unit: UnitState = battle.get_unit(selected_unit_id)
	_present_selected_unit(battle, selected_unit)
	_present_art(
			battle,
			selected_unit,
			selected_art_slot_index,
			pending_art_slot_index
	)


func _present_unavailable() -> void:
	phase_label.text = "阶段：不可用"
	round_label.text = "轮次：--"
	selected_unit_label.text = "当前单位\n未选择"
	art_status_label.text = "技艺：不可用"
	_listed_art_slots.clear()
	art_selector.clear()
	art_selector.disabled = true
	use_art_button.disabled = true
	end_turn_button.disabled = true


func _present_selected_unit(
	battle: BattleState,
	selected_unit: UnitState
) -> void:
	if selected_unit == null:
		selected_unit_label.text = "当前单位\n未选择"
		return
	var position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			selected_unit.instance_id
	)
	var position_text: String = "--"
	if position != null:
		position_text = "%d, %d" % [position.value.x, position.value.y]
	var maximum_health: int = _attribute_calculator.calculate(
			selected_unit,
			GameEnums.AttributeType.MAX_HEALTH
	)
	var maximum_ap: int = _attribute_calculator.calculate(
			selected_unit,
			GameEnums.AttributeType.MAX_AP
	)
	selected_unit_label.text = (
		"当前单位\n"
		+ "%s，编号%d\n" % [
			selected_unit.definition.display_name,
			selected_unit.instance_id,
		]
		+ "生命：%d / %d\n" % [
			selected_unit.current_health,
			maximum_health,
		]
		+ "行动点：%d / %d\n" % [
			selected_unit.current_ap,
			maximum_ap,
		]
		+ "护盾：%d　增益：%d\n" % [
			selected_unit.current_shield,
			selected_unit.get_buffs().size(),
		]
		+ "格子：%s" % position_text
	)


func _present_art(
	battle: BattleState,
	unit: UnitState,
	selected_art_slot_index: int,
	pending_art_slot_index: int
) -> void:
	if unit == null:
		_listed_art_slots.clear()
		art_selector.clear()
		art_selector.disabled = true
	var art_state: ArtState
	if (
		unit != null
		and selected_art_slot_index >= 0
		and selected_art_slot_index < unit.arts.size()
	):
		art_state = unit.arts[selected_art_slot_index]

	if art_state == null or art_state.definition == null:
		art_status_label.text = "技艺：未选择"
	else:
		var art: ArtDefinition = art_state.definition
		var status: String = "可用"
		if art.category == GameEnums.ArtCategory.PASSIVE:
			status = "持续生效"
		elif art_state.current_cooldown > 0:
			status = "冷却%d回合" % art_state.current_cooldown
		art_status_label.text = "消耗：%d　冷却：%d　状态：%s" % [
			art.ap_cost,
			art.cooldown,
			status,
		]

	use_art_button.text = (
		"取消选择目标"
		if pending_art_slot_index >= 0
		else "使用技艺"
	)
	use_art_button.disabled = (
		unit == null
		or art_state == null
		or art_state.definition == null
		or art_state.definition.category == GameEnums.ArtCategory.PASSIVE
		or art_state.current_cooldown > 0
		or battle.phase != GameEnums.BattlePhase.PLAYER_TURN
		or battle.active_side != GameEnums.BattleSide.PLAYER
	)


func _on_art_item_selected(item_index: int) -> void:
	if item_index < 0 or item_index >= _listed_art_slots.size():
		art_selected.emit(-1)
		return
	art_selected.emit(_listed_art_slots[item_index])


func _on_use_art_pressed() -> void:
	art_use_requested.emit()


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()


func _on_reset_pressed() -> void:
	battle_reset_requested.emit()

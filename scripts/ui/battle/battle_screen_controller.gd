class_name BattleScreenController
extends Control

signal battle_read_model_changed(model: BattleReadModel)
signal feedback_changed(message: String)
signal external_battle_continue_requested

const BATTLE_SEED: int = 20260802

@export_category("Views")
@export var board_view: BattleBoardView
@export var grid_view: BattleScreenGridView
@export var highlight_view: BattleScreenHighlightView
@export var unit_view: BattleScreenUnitView
@export var status_view: BattleScreenStatusView

@export_category("Hud")
@export var round_label: Label

@export_category("Result")
@export var result_overlay: Control
@export var result_title_label: Label
@export var result_detail_label: Label
@export var result_restart_button: Button

@export_category("Scenario")
@export var encounter_definition: EncounterDefinition
@export var player_unit_definitions: Array[UnitDefinition] = []

var _battle: BattleState
var _read_model: BattleReadModel
var _placement_service: BattlePlacementService = BattlePlacementService.new()
var _turn_service: BattleTurnService = BattleTurnService.new()
var _action_service: BattleActionService
var _flow_service: BattleFlowService
var _read_model_service: BattleReadModelService = BattleReadModelService.new()
var _targeting_service: BattleTargetingReadService = (
	BattleTargetingReadService.new()
)
var _selected_unit_id: int = 0
var _inspected_unit_id: int = 0
var _selected_art_slot_index: int = -1
var _pending_art_slot_index: int = -1
var _selected_scroll_stack_id: int = 0
var _pending_scroll_stack_id: int = 0
var _hovered_coordinate: GridCoordinate
var _deployed_count: int = 0
var _deployment_cells: Dictionary[Vector2i, bool] = {}
var _reachable_cells: Dictionary[Vector2i, int] = {}
var _art_range_cells: Dictionary[Vector2i, bool] = {}
var _targetable_cells: Dictionary[Vector2i, bool] = {}
var _art_affected_cells: Dictionary[Vector2i, bool] = {}
var _external_battle_mode: bool = false


func _init() -> void:
	_action_service = BattleActionService.new(
		GridPathfinder.new(),
		_turn_service
	)
	_flow_service = BattleFlowService.new(_action_service)


func _ready() -> void:
	_connect_interface()
	if not _external_battle_mode:
		rebuild_battle()


func present_external_battle(battle: BattleState) -> bool:
	if battle == null or battle.grid == null:
		return false
	_external_battle_mode = true
	_battle = battle
	_deployed_count = battle.get_units_for_side(
		GameEnums.BattleSide.PLAYER
	).size()
	_deployment_cells.clear()
	_reset_interaction_state()
	_set_feedback("战斗已载入。阅读敌人意图后提交行动。", false)
	_refresh_view()
	return true


func clear_external_battle() -> void:
	_external_battle_mode = false
	_battle = null
	_reset_interaction_state()
	_refresh_view()


func rebuild_battle() -> bool:
	_reset_interaction_state()
	_deployed_count = 0
	_deployment_cells.clear()
	if not _has_complete_configuration():
		_battle = null
		_set_feedback("战斗场景配置不完整。")
		_refresh_view()
		return false
	var validation: DefinitionValidationResult = (
		DefinitionValidator.new().validate(encounter_definition)
	)
	if not validation.is_valid():
		_battle = null
		_set_feedback("战斗配置没有通过数据校验。")
		_refresh_view()
		return false
	var battlefield: BattlefieldDefinition = encounter_definition.battlefield
	var grid: GridState = GridState.create(
		battlefield.width,
		battlefield.height,
		battlefield.default_terrain
	)
	for terrain_placement: BattlefieldTerrainPlacement in (
		battlefield.terrain_overrides
	):
		if terrain_placement == null or not grid.set_terrain(
			terrain_placement.coordinate,
			terrain_placement.terrain
		).succeeded():
			return _fail_rebuild("地形配置无法创建战场。")
	for coordinate: Vector2i in battlefield.player_deployment_cells:
		_deployment_cells[coordinate] = true
	var battle: BattleState = BattleState.create(grid, BATTLE_SEED)
	for spawn: EnemySpawnDefinition in encounter_definition.enemy_spawns:
		var placement: BattlePlacementResult = (
			_placement_service.place_enemy_definition(
				battle,
				spawn.enemy_definition,
				spawn.coordinate
			)
		)
		if not placement.succeeded():
			return _fail_rebuild("敌人配置无法放置到战场。")
	_battle = battle
	_set_feedback("点击蓝色部署格，依次放置我方单位。", false)
	_refresh_view()
	return true


func request_cell_action(coordinate: Vector2i) -> void:
	if _battle == null or _battle.grid == null:
		_set_feedback("战斗尚未准备完成。")
		return
	if _battle.phase == GameEnums.BattlePhase.SETUP:
		request_deploy_at(coordinate)
		return
	if _battle.phase != GameEnums.BattlePhase.PLAYER_TURN:
		_set_feedback("当前不能提交玩家行动。")
		return
	if _pending_art_slot_index >= 0:
		_execute_pending_art(coordinate)
		return
	if _pending_scroll_stack_id > 0:
		_execute_pending_scroll(coordinate)
		return
	var occupant: GridOccupant = _battle.grid.get_occupant(coordinate)
	if occupant != null and occupant.kind == GameEnums.GridOccupantKind.UNIT:
		var clicked_unit: UnitState = _battle.get_unit(occupant.runtime_id)
		if clicked_unit != null:
			request_inspect_unit(clicked_unit.instance_id)
			return
	if _selected_unit_id <= 0:
		_set_feedback("请先选择一个蓝色玩家单位。")
		return
	var request: MoveActionRequest = MoveActionRequest.create(
		GameEnums.BattleSide.PLAYER,
		_selected_unit_id,
		coordinate
	)
	var result: ActionExecutionResult = _action_service.execute(
		_battle,
		request
	)
	if result.is_successful:
		_set_feedback("移动完成，消耗%d点行动点。" % result.ap_spent)
	else:
		_set_feedback(
			"无法移动：%s。" % BattleUiTextFormatter.failure_code_text(
				result.failure_code
			)
		)
	_refresh_reachable_cells()
	_refresh_view()


func request_deploy_at(coordinate: Vector2i) -> bool:
	if (
		_battle == null
		or _battle.phase != GameEnums.BattlePhase.SETUP
		or _deployed_count >= player_unit_definitions.size()
	):
		_set_feedback("当前不能继续部署单位。")
		return false
	if not _deployment_cells.has(coordinate):
		_set_feedback("只能把单位放在蓝色部署格。")
		return false
	var definition: UnitDefinition = player_unit_definitions[_deployed_count]
	var result: BattlePlacementResult = (
		_placement_service.place_unit_definition(
			_battle,
			definition,
			GameEnums.BattleSide.PLAYER,
			coordinate
		)
	)
	if not result.succeeded():
		_set_feedback("该部署格不可用，请选择另一个蓝色格子。")
		return false
	_deployed_count += 1
	if _deployed_count == player_unit_definitions.size():
		_set_feedback("部署完成。确认站位后开始战斗。")
	else:
		_set_feedback(
			"已部署%s，请放置下一名单位。" % definition.display_name
		)
	_refresh_view()
	return true


func request_start_battle() -> bool:
	if (
		_battle == null
		or _battle.phase != GameEnums.BattlePhase.SETUP
		or _deployed_count != player_unit_definitions.size()
		or _deployed_count <= 0
	):
		_set_feedback("请先完成全部单位部署。")
		return false
	var result: BattleFlowResult = _flow_service.start_battle(_battle)
	if not result.succeeded:
		_set_feedback(
			"无法开始战斗：%s。" % BattleUiTextFormatter.failure_code_text(
				result.failure_code
			)
		)
		return false
	_set_feedback("敌人已经公布第一批意图。请选择我方单位行动。")
	_refresh_view()
	return true


func request_reset_deployment() -> bool:
	if _battle != null and _battle.phase != GameEnums.BattlePhase.SETUP:
		_set_feedback("战斗开始后不能重置部署。")
		return false
	return rebuild_battle()


func request_select_unit(unit_id: int) -> bool:
	if (
		_battle == null
		or _battle.phase != GameEnums.BattlePhase.PLAYER_TURN
	):
		return false
	var unit: UnitState = _battle.get_unit(unit_id)
	if unit == null or unit.side != GameEnums.BattleSide.PLAYER:
		_set_feedback("只能选择我方存活单位。")
		return false
	_selected_unit_id = unit_id
	_inspected_unit_id = unit_id
	_selected_art_slot_index = _first_active_art_slot(unit)
	_pending_art_slot_index = -1
	_pending_scroll_stack_id = 0
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	_set_feedback("已选择%s。绿色格子表示当前可移动范围。" % (
		unit.definition.display_name
	))
	_refresh_reachable_cells()
	_refresh_view()
	return true


func request_inspect_unit(unit_id: int) -> bool:
	if _battle == null or _battle.phase == GameEnums.BattlePhase.SETUP:
		return false
	var unit: UnitState = _battle.get_unit(unit_id)
	if unit == null:
		_set_feedback("该单位已经不在战场上。")
		return false
	if unit.side == GameEnums.BattleSide.PLAYER:
		return request_select_unit(unit_id)
	_inspected_unit_id = unit_id
	_selected_unit_id = 0
	_selected_art_slot_index = _first_active_art_slot(unit)
	_pending_art_slot_index = -1
	_pending_scroll_stack_id = 0
	_reachable_cells.clear()
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	_set_feedback("正在查看%s。敌方单位只能查看，不能提交玩家行动。" % (
		unit.definition.display_name
	))
	_refresh_view()
	return true


func request_select_art(slot_index: int) -> void:
	_selected_art_slot_index = slot_index
	_pending_art_slot_index = -1
	_pending_scroll_stack_id = 0
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	_refresh_reachable_cells()
	_refresh_view()


func request_toggle_art_targeting() -> bool:
	if _pending_art_slot_index >= 0:
		_pending_art_slot_index = -1
		_art_range_cells.clear()
		_targetable_cells.clear()
		_art_affected_cells.clear()
		_refresh_reachable_cells()
		_set_feedback("已取消技艺目标选择。")
		_refresh_view()
		return true
	if _battle == null or _selected_unit_id <= 0:
		_set_feedback("请先选择一个蓝色玩家单位。")
		return false
	var art_state: ArtState = _targeting_service.get_art_state(
		_battle,
		_selected_unit_id,
		_selected_art_slot_index
	)
	if art_state == null or art_state.definition == null:
		_set_feedback("请选择一个可以使用的技艺。")
		return false
	var targeting: TargetingDefinition = art_state.definition.targeting
	if targeting == null:
		_set_feedback("该技艺缺少目标配置。")
		return false
	if targeting.minimum_targets != 1 or targeting.maximum_targets != 1:
		_set_feedback("当前战斗内容需要一次选择一个目标。")
		return false
	_pending_art_slot_index = _selected_art_slot_index
	_reachable_cells.clear()
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	if targeting.target_kind == GameEnums.TargetKind.BATTLE:
		var selection: TargetSelection = TargetSelection.new()
		selection.targets_battle = true
		_execute_art(selection)
		return true
	_refresh_targetable_cells()
	if _targetable_cells.is_empty():
		_set_feedback("已显示技艺射程，但当前没有合法落点。")
	_refresh_view()
	return true


func request_select_scroll(stack_instance_id: int) -> void:
	_selected_scroll_stack_id = stack_instance_id
	_pending_scroll_stack_id = 0
	_pending_art_slot_index = -1
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	_refresh_reachable_cells()
	_refresh_view()


func request_toggle_scroll_targeting() -> bool:
	if _pending_scroll_stack_id > 0:
		_pending_scroll_stack_id = 0
		_art_range_cells.clear()
		_targetable_cells.clear()
		_art_affected_cells.clear()
		_refresh_reachable_cells()
		_set_feedback("已取消卷轴目标选择。")
		_refresh_view()
		return true
	if _battle == null or _selected_unit_id <= 0 or _selected_scroll_stack_id <= 0:
		_set_feedback("请先选择我方单位和一张卷轴。")
		return false
	var stack: BattleScrollStackState = _battle.get_scroll(
		_selected_scroll_stack_id
	)
	if stack == null or stack.quantity <= 0 or stack.definition.targeting == null:
		_set_feedback("该卷轴当前不可用。")
		return false
	_pending_art_slot_index = -1
	_pending_scroll_stack_id = _selected_scroll_stack_id
	_reachable_cells.clear()
	_art_range_cells = _targeting_service.find_scroll_range_cells(
		_battle,
		_selected_unit_id,
		_pending_scroll_stack_id
	)
	_targetable_cells = _targeting_service.find_scroll_targetable_cells(
		_battle,
		_action_service,
		_selected_unit_id,
		_pending_scroll_stack_id
	)
	if stack.definition.targeting.target_kind == GameEnums.TargetKind.BATTLE:
		var selection: TargetSelection = TargetSelection.new()
		selection.targets_battle = true
		_execute_scroll(selection)
		return true
	_refresh_view()
	return true


func request_use_scroll(stack_instance_id: int) -> bool:
	if _battle == null or _selected_unit_id <= 0:
		_set_feedback("请先选择使用卷轴的我方单位。")
		return false
	request_select_scroll(stack_instance_id)
	return request_toggle_scroll_targeting()


func request_discard_scroll(stack_instance_id: int) -> bool:
	if _battle == null:
		_set_feedback("战斗尚未准备完成。")
		return false
	var result: ActionExecutionResult = _action_service.execute(
		_battle,
		DiscardScrollActionRequest.create(stack_instance_id)
	)
	if not result.is_successful:
		_set_feedback("无法丢弃卷轴：%s。" % (
			BattleUiTextFormatter.failure_code_text(result.failure_code)
		))
		return false
	_pending_scroll_stack_id = 0
	_selected_scroll_stack_id = 0
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	_refresh_reachable_cells()
	_set_feedback("已经丢弃一张卷轴。")
	_refresh_view()
	return true


func request_cancel_targeting() -> bool:
	if _pending_art_slot_index < 0 and _pending_scroll_stack_id <= 0:
		return false
	_pending_art_slot_index = -1
	_pending_scroll_stack_id = 0
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	_refresh_reachable_cells()
	_set_feedback("已取消目标选择，可以继续移动。")
	_refresh_view()
	return true


func request_end_turn() -> bool:
	if (
		_battle == null
		or _battle.phase != GameEnums.BattlePhase.PLAYER_TURN
		or _battle.active_side != GameEnums.BattleSide.PLAYER
	):
		_set_feedback("当前不能结束玩家回合。")
		return false
	var result: BattleFlowResult = _flow_service.end_player_turn(_battle)
	if not result.succeeded:
		_set_feedback(
			"无法推进回合：%s。" % BattleUiTextFormatter.failure_code_text(
				result.failure_code
			)
		)
		_refresh_view()
		return false
	_reset_interaction_state()
	_set_feedback(BattleUiTextFormatter.battle_flow_text(result))
	_refresh_view()
	return true


func request_restart_battle() -> bool:
	if _external_battle_mode:
		_set_feedback("整局战斗不能重新开始。")
		return false
	return rebuild_battle()


func get_read_model() -> BattleReadModel:
	return _read_model


func get_deployed_count() -> int:
	return _deployed_count


func get_selected_unit_id() -> int:
	return _selected_unit_id


func get_reachable_cells() -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	for coordinate: Vector2i in _reachable_cells:
		result[coordinate] = _reachable_cells[coordinate]
	return result


func get_targetable_cells() -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for coordinate: Vector2i in _targetable_cells:
		result[coordinate] = true
	return result


func _execute_pending_art(coordinate: Vector2i) -> void:
	if not _targetable_cells.has(coordinate):
		_set_feedback("该格子不是当前技艺的合法落点。")
		return
	var selection: TargetSelection = _targeting_service.selection_for_coordinate(
		_battle,
		_selected_unit_id,
		_pending_art_slot_index,
		coordinate
	)
	if selection == null:
		_set_feedback("无法从该格子建立目标选择。")
		return
	_execute_art(selection)


func _execute_art(selection: TargetSelection) -> void:
	var request: UseArtActionRequest = UseArtActionRequest.create(
		GameEnums.BattleSide.PLAYER,
		_selected_unit_id,
		_pending_art_slot_index,
		selection
	)
	var result: ActionExecutionResult = _action_service.execute(
		_battle,
		request
	)
	_pending_art_slot_index = -1
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	if result.is_successful:
		_set_feedback(BattleUiTextFormatter.action_result_text(result))
	else:
		_set_feedback(
			"无法使用技艺：%s。" % BattleUiTextFormatter.failure_code_text(
				result.failure_code
			)
		)
	_refresh_reachable_cells()
	_refresh_view()


func _execute_pending_scroll(coordinate: Vector2i) -> void:
	if not _targetable_cells.has(coordinate):
		_set_feedback("该格子不是当前卷轴的合法落点。")
		return
	var selection: TargetSelection = (
		_targeting_service.scroll_selection_for_coordinate(
			_battle,
			_pending_scroll_stack_id,
			coordinate
		)
	)
	if selection == null:
		_set_feedback("无法从该格子建立卷轴目标。")
		return
	_execute_scroll(selection)


func _execute_scroll(selection: TargetSelection) -> void:
	var request: UseScrollActionRequest = UseScrollActionRequest.create(
		_selected_unit_id,
		_pending_scroll_stack_id,
		selection
	)
	var result: ActionExecutionResult = _action_service.execute(_battle, request)
	_pending_scroll_stack_id = 0
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()
	if result.is_successful:
		_set_feedback(BattleUiTextFormatter.action_result_text(result))
	else:
		_set_feedback("无法使用卷轴：%s。" % (
			BattleUiTextFormatter.failure_code_text(result.failure_code)
		))
	_refresh_reachable_cells()
	_refresh_view()


func _refresh_reachable_cells() -> void:
	_reachable_cells.clear()
	if (
		_battle == null
		or _battle.phase != GameEnums.BattlePhase.PLAYER_TURN
		or _selected_unit_id <= 0
		or _pending_art_slot_index >= 0
		or _pending_scroll_stack_id > 0
	):
		return
	for y: int in range(_battle.grid.height):
		for x: int in range(_battle.grid.width):
			var coordinate: Vector2i = Vector2i(x, y)
			var request: MoveActionRequest = MoveActionRequest.create(
				GameEnums.BattleSide.PLAYER,
				_selected_unit_id,
				coordinate
			)
			var validation: ActionValidationResult = _action_service.validate(
				_battle,
				request
			)
			if validation.is_valid and validation.plan != null:
				_reachable_cells[coordinate] = validation.plan.ap_cost


func _refresh_targetable_cells() -> void:
	_art_range_cells = _targeting_service.find_range_cells(
		_battle,
		_selected_unit_id,
		_pending_art_slot_index
	)
	_targetable_cells = _targeting_service.find_targetable_cells(
		_battle,
		_action_service,
		_selected_unit_id,
		_pending_art_slot_index
	)


func _on_board_cell_hovered(next_coordinate: GridCoordinate) -> void:
	if _coordinates_match(_hovered_coordinate, next_coordinate):
		return
	_hovered_coordinate = next_coordinate
	_refresh_art_affected_cells()
	_refresh_highlights()


func _refresh_art_affected_cells() -> void:
	_art_affected_cells.clear()
	if (
		_battle == null
		or _hovered_coordinate == null
		or (
			_pending_art_slot_index < 0
			and _pending_scroll_stack_id <= 0
		)
		or not _targetable_cells.has(_hovered_coordinate.value)
	):
		return
	if _pending_scroll_stack_id > 0:
		_art_affected_cells = _targeting_service.find_scroll_affected_cells(
			_battle,
			_selected_unit_id,
			_pending_scroll_stack_id,
			_hovered_coordinate.value
		)
	else:
		_art_affected_cells = _targeting_service.find_affected_cells(
			_battle,
			_selected_unit_id,
			_pending_art_slot_index,
			_hovered_coordinate.value
		)


func _refresh_view() -> void:
	_read_model = _read_model_service.build(_battle)
	if board_view != null:
		board_view.present_battle(_read_model)
	if status_view != null:
		_selected_art_slot_index = status_view.present(
			_read_model,
			_inspected_unit_id,
			_selected_art_slot_index,
			_pending_art_slot_index,
			_deployed_count,
			player_unit_definitions.size(),
			_next_deployment_name()
		)
	_refresh_turn_control()
	_refresh_highlights()
	_refresh_result()
	battle_read_model_changed.emit(_read_model)


func _refresh_turn_control() -> void:
	if _read_model == null:
		round_label.text = "回合  --"
		return
	round_label.text = "回合  %d" % _read_model.round_number


func _refresh_highlights() -> void:
	if board_view == null:
		return
	var selected_coordinate: GridCoordinate
	if _read_model != null and _inspected_unit_id > 0:
		var selected: BattleUnitReadModel = _read_model.get_unit(
			_inspected_unit_id
		)
		if selected != null and selected.has_coordinate:
			selected_coordinate = GridCoordinate.new(selected.coordinate)
	var shown_deployment_cells: Dictionary[Vector2i, bool] = {}
	if _read_model != null and _read_model.phase == GameEnums.BattlePhase.SETUP:
		for coordinate: Vector2i in _deployment_cells:
			var cell: BattleCellReadModel = _read_model.get_cell(coordinate)
			if cell != null and not cell.has_occupant():
				shown_deployment_cells[coordinate] = true
	var intent_danger_cells: Dictionary[Vector2i, bool] = {}
	var intent_move_cells: Dictionary[Vector2i, bool] = {}
	if _read_model != null:
		for intent: BattleIntentReadModel in _read_model.intents:
			for coordinate: Vector2i in intent.affected_cells:
				intent_danger_cells[coordinate] = true
			for coordinate: Vector2i in intent.movement_path:
				intent_move_cells[coordinate] = true
	board_view.present_highlights(
		selected_coordinate,
		_reachable_cells,
		_art_range_cells,
		_targetable_cells,
		_art_affected_cells,
		intent_danger_cells,
		intent_move_cells
	)
	if _read_model != null and _read_model.phase == GameEnums.BattlePhase.SETUP:
		highlight_view.present(
			selected_coordinate,
			_hovered_coordinate,
			shown_deployment_cells,
			_reachable_cells,
			_art_range_cells,
			_targetable_cells,
			_art_affected_cells,
			intent_danger_cells,
			intent_move_cells
		)


func _refresh_result() -> void:
	var terminal: bool = _read_model != null and _read_model.is_terminal()
	result_overlay.visible = terminal
	if not terminal:
		return
	var victory: bool = (
		_read_model.phase == GameEnums.BattlePhase.VICTORY
	)
	result_title_label.text = "战斗胜利" if victory else "战斗失败"
	result_detail_label.text = (
		"全部敌人已经被击败。继续后结算战斗并返回远征流程。"
		if victory
		else "我方单位全部倒下。继续后结算本次远征。"
	)
	result_restart_button.text = (
		"继续" if _external_battle_mode else "重新挑战"
	)


func _connect_interface() -> void:
	if not board_view.cell_pressed.is_connected(request_cell_action):
		board_view.cell_pressed.connect(request_cell_action)
	if not board_view.cell_hovered.is_connected(_on_board_cell_hovered):
		board_view.cell_hovered.connect(_on_board_cell_hovered)
	if not board_view.targeting_cancel_requested.is_connected(
		request_cancel_targeting
	):
		board_view.targeting_cancel_requested.connect(
			request_cancel_targeting
		)
	if not status_view.deployment_start_requested.is_connected(
		request_start_battle
	):
		status_view.deployment_start_requested.connect(request_start_battle)
	if not status_view.deployment_reset_requested.is_connected(
		request_reset_deployment
	):
		status_view.deployment_reset_requested.connect(
			request_reset_deployment
		)
	if not status_view.art_selected.is_connected(request_select_art):
		status_view.art_selected.connect(request_select_art)
	if not status_view.art_use_requested.is_connected(
		request_toggle_art_targeting
	):
		status_view.art_use_requested.connect(request_toggle_art_targeting)
	if not status_view.end_turn_requested.is_connected(request_end_turn):
		status_view.end_turn_requested.connect(request_end_turn)
	if not result_restart_button.pressed.is_connected(
		_on_result_action_pressed
	):
		result_restart_button.pressed.connect(_on_result_action_pressed)


func _on_result_action_pressed() -> void:
	if _external_battle_mode:
		external_battle_continue_requested.emit()
		return
	request_restart_battle()


func _reset_interaction_state() -> void:
	_selected_unit_id = 0
	_inspected_unit_id = 0
	_selected_art_slot_index = -1
	_pending_art_slot_index = -1
	_selected_scroll_stack_id = 0
	_pending_scroll_stack_id = 0
	_hovered_coordinate = null
	_reachable_cells.clear()
	_art_range_cells.clear()
	_targetable_cells.clear()
	_art_affected_cells.clear()


func _has_complete_configuration() -> bool:
	if (
		board_view == null
		or grid_view == null
		or highlight_view == null
		or unit_view == null
		or status_view == null
		or round_label == null
		or result_overlay == null
		or result_title_label == null
		or result_detail_label == null
		or result_restart_button == null
		or encounter_definition == null
		or player_unit_definitions.is_empty()
	):
		return false
	for definition: UnitDefinition in player_unit_definitions:
		if (
			definition == null
			or not DefinitionValidator.new().validate(definition).is_valid()
		):
			return false
	return true


func _next_deployment_name() -> String:
	if (
		_deployed_count < 0
		or _deployed_count >= player_unit_definitions.size()
	):
		return "--"
	var definition: UnitDefinition = player_unit_definitions[_deployed_count]
	return definition.display_name if definition != null else "--"


func _first_active_art_slot(unit: UnitState) -> int:
	if unit == null:
		return -1
	for slot_index: int in range(unit.arts.size()):
		var art: ArtState = unit.arts[slot_index]
		if (
			art != null
			and art.definition != null
			and art.definition.category != GameEnums.ArtCategory.PASSIVE
		):
			return slot_index
	return -1


func _coordinates_match(
		left: GridCoordinate,
		right: GridCoordinate
) -> bool:
	if left == null or right == null:
		return left == null and right == null
	return left.value == right.value


func _fail_rebuild(message: String) -> bool:
	_battle = null
	_set_feedback(message)
	_refresh_view()
	return false


func _set_feedback(message: String, _show_toast: bool = true) -> void:
	feedback_changed.emit(message)

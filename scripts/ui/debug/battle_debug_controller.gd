class_name BattleDebugController
extends Node2D

signal debug_battle_rebuilt

const GRID_SIZE: Vector2i = Vector2i(7, 5)
const SCENE_OBJECT_ID: int = 1
const DIFFICULT_CELLS: Array[Vector2i] = [
	Vector2i(2, 1),
	Vector2i(2, 2),
	Vector2i(2, 3),
	Vector2i(4, 0),
	Vector2i(4, 4),
]
const BLOCKED_CELLS: Array[Vector2i] = [
	Vector2i(3, 0),
	Vector2i(3, 4),
]

@export_category("Views")
@export var grid_view: BattleGridView
@export var highlight_view: BattleHighlightView
@export var unit_view: BattleUnitView

@export_category("Interface")
@export var status_view: BattleDebugStatusView
@export var feedback_label: Label

@export_category("Debug Content")
@export var ground_terrain: TerrainDefinition
@export var difficult_terrain: TerrainDefinition
@export var blocked_terrain: TerrainDefinition
@export var player_unit_definition: UnitDefinition
@export var enemy_unit_definition: UnitDefinition

var _battle: BattleState
var _placement_service: BattlePlacementService = BattlePlacementService.new()
var _turn_service: BattleTurnService = BattleTurnService.new()
var _action_service: BattleActionService
var _selected_unit_id: int = 0
var _selected_art_slot_index: int = -1
var _pending_art_slot_index: int = -1
var _hovered_coordinate: GridCoordinate
var _reachable_cells: Dictionary[Vector2i, int] = {}
var _art_range_cells: Dictionary[Vector2i, bool] = {}
var _targetable_cells: Dictionary[Vector2i, bool] = {}
var _art_targeting: BattleDebugArtTargeting = BattleDebugArtTargeting.new()


func _init() -> void:
	_action_service = BattleActionService.new(
			GridPathfinder.new(),
			_turn_service
	)


func _ready() -> void:
	if (
		status_view != null
		and not status_view.art_selected.is_connected(_on_art_selected)
	):
		status_view.art_selected.connect(_on_art_selected)
	if (
		status_view != null
		and not status_view.art_use_requested.is_connected(_on_use_art_pressed)
	):
		status_view.art_use_requested.connect(_on_use_art_pressed)
	if (
		status_view != null
		and not status_view.end_turn_requested.is_connected(_on_end_turn_pressed)
	):
		status_view.end_turn_requested.connect(_on_end_turn_pressed)
	if (
		status_view != null
		and not status_view.battle_reset_requested.is_connected(_on_reset_pressed)
	):
		status_view.battle_reset_requested.connect(_on_reset_pressed)
	rebuild_debug_battle()


func _unhandled_input(event: InputEvent) -> void:
	if _battle == null or grid_view == null:
		return

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_update_hovered_coordinate(motion_event.position)
		return

	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event as InputEventMouseButton
		if (
			button_event.button_index == MOUSE_BUTTON_LEFT
			and button_event.pressed
		):
			var coordinate: GridCoordinate = grid_view.screen_to_coordinate(
					button_event.position
			)
			if coordinate != null:
				_handle_coordinate_pressed(coordinate.value)
				get_viewport().set_input_as_handled()


func rebuild_debug_battle() -> bool:
	_selected_unit_id = 0
	_selected_art_slot_index = -1
	_pending_art_slot_index = -1
	_hovered_coordinate = null
	_reachable_cells.clear()
	_art_range_cells.clear()
	_targetable_cells.clear()

	if not _has_complete_scene_configuration():
		_battle = null
		_set_feedback("调试场景配置不完整。")
		_refresh_view()
		return false

	var grid: GridState = GridState.create(
			GRID_SIZE.x,
			GRID_SIZE.y,
			ground_terrain
	)
	for coordinate: Vector2i in DIFFICULT_CELLS:
		var difficult_result: GridOperationResult = grid.set_terrain(
				coordinate,
				difficult_terrain
		)
		if not difficult_result.succeeded():
			return _fail_rebuild("困难地形设置失败。")

	for coordinate: Vector2i in BLOCKED_CELLS:
		var blocked_result: GridOperationResult = grid.set_terrain(
				coordinate,
				blocked_terrain
		)
		if not blocked_result.succeeded():
			return _fail_rebuild("阻挡地形设置失败。")

	var object_result: GridOperationResult = grid.place_occupant(
			GridOccupant.scene_object(SCENE_OBJECT_ID),
			Vector2i(3, 2)
	)
	if not object_result.succeeded():
		return _fail_rebuild("场景物体设置失败。")

	var battle: BattleState = BattleState.create(grid)
	var placements: Array[BattlePlacementResult] = [
		_placement_service.place_unit_definition(
				battle,
				player_unit_definition,
				GameEnums.BattleSide.PLAYER,
				Vector2i(1, 1)
		),
		_placement_service.place_unit_definition(
				battle,
				player_unit_definition,
				GameEnums.BattleSide.PLAYER,
				Vector2i(1, 3)
		),
		_placement_service.place_unit_definition(
				battle,
				enemy_unit_definition,
				GameEnums.BattleSide.ENEMY,
				Vector2i(5, 1)
		),
		_placement_service.place_unit_definition(
				battle,
				enemy_unit_definition,
				GameEnums.BattleSide.ENEMY,
				Vector2i(5, 3)
		),
	]
	for placement: BattlePlacementResult in placements:
		if not placement.succeeded():
			return _fail_rebuild("单位放置失败。")

	var turn_result: TurnTransitionResult = _turn_service.start_battle(battle)
	if not turn_result.succeeded:
		return _fail_rebuild("战斗启动失败。")

	_battle = battle
	_set_feedback("选择蓝色单位后，可以移动或选择技艺。")
	_refresh_view()
	debug_battle_rebuilt.emit()
	return true


func get_battle_state() -> BattleState:
	return _battle


func _handle_coordinate_pressed(coordinate: Vector2i) -> void:
	if (
		_battle.phase != GameEnums.BattlePhase.PLAYER_TURN
		or _battle.active_side != GameEnums.BattleSide.PLAYER
	):
		_set_feedback("敌方决策尚未实现，请推进回合。")
		return

	if _pending_art_slot_index >= 0:
		_execute_pending_art(coordinate)
		return

	var occupant: GridOccupant = _battle.grid.get_occupant(coordinate)
	if occupant != null and occupant.kind == GameEnums.GridOccupantKind.UNIT:
		var clicked_unit: UnitState = _battle.get_unit(occupant.runtime_id)
		if (
			clicked_unit != null
			and clicked_unit.side == GameEnums.BattleSide.PLAYER
		):
			_select_unit(clicked_unit.instance_id)
			return

	if _selected_unit_id <= 0:
		_set_feedback("请先选择一个蓝色玩家单位。")
		return

	var request: MoveActionRequest = MoveActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			_selected_unit_id,
			coordinate
	)
	var result: ActionExecutionResult = _action_service.execute(_battle, request)
	if result.is_successful:
		_set_feedback("移动消耗了 %d 点行动点。" % result.ap_spent)
	else:
		_set_feedback(
				"无法移动：%s。"
				% BattleDebugTextFormatter.failure_code_text(result.failure_code)
		)
	_refresh_reachable_cells()
	_refresh_view()


func _select_unit(unit_id: int) -> void:
	_selected_unit_id = unit_id
	_pending_art_slot_index = -1
	_art_range_cells.clear()
	_targetable_cells.clear()
	var unit: UnitState = _battle.get_unit(unit_id)
	if unit != null:
		_set_feedback("已选择%s，单位编号%d。" % [
			unit.definition.display_name,
			unit.instance_id,
		])
	_populate_art_selector()
	_refresh_reachable_cells()
	_refresh_view()


func _refresh_reachable_cells() -> void:
	_reachable_cells.clear()
	if (
		_battle == null
		or _selected_unit_id <= 0
		or _pending_art_slot_index >= 0
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


func _update_hovered_coordinate(screen_position: Vector2) -> void:
	var next_coordinate: GridCoordinate = grid_view.screen_to_coordinate(
			screen_position
	)
	if _coordinates_match(_hovered_coordinate, next_coordinate):
		return
	_hovered_coordinate = next_coordinate
	_refresh_highlights()


func _coordinates_match(
		left: GridCoordinate,
		right: GridCoordinate
) -> bool:
	if left == null or right == null:
		return left == null and right == null
	return left.value == right.value


func _on_end_turn_pressed() -> void:
	if _battle == null:
		return
	var request: EndTurnActionRequest = EndTurnActionRequest.create(
			_battle.active_side
	)
	var result: ActionExecutionResult = _action_service.execute(_battle, request)
	if result.is_successful:
		_selected_unit_id = 0
		_selected_art_slot_index = -1
		_pending_art_slot_index = -1
		_reachable_cells.clear()
		_art_range_cells.clear()
		_targetable_cells.clear()
		_populate_art_selector()
		_set_feedback(
				"回合已推进至%s。"
				% BattleDebugTextFormatter.side_text(_battle.active_side)
		)
	else:
		_set_feedback(
				"无法推进回合：%s。"
				% BattleDebugTextFormatter.failure_code_text(result.failure_code)
		)
	_refresh_view()


func _on_reset_pressed() -> void:
	rebuild_debug_battle()


func _on_art_selected(slot_index: int) -> void:
	_selected_art_slot_index = slot_index
	_pending_art_slot_index = -1
	_art_range_cells.clear()
	_targetable_cells.clear()
	_refresh_reachable_cells()
	_refresh_view()


func _on_use_art_pressed() -> void:
	if _pending_art_slot_index >= 0:
		_pending_art_slot_index = -1
		_art_range_cells.clear()
		_targetable_cells.clear()
		_refresh_reachable_cells()
		_set_feedback("已取消技艺目标选择。")
		_refresh_view()
		return
	if _battle == null or _selected_unit_id <= 0:
		_set_feedback("请先选择一个蓝色玩家单位。")
		return
	var unit: UnitState = _battle.get_unit(_selected_unit_id)
	var art_state: ArtState = _get_selected_art_state(unit)
	if art_state == null or art_state.definition == null:
		_set_feedback("请选择一个可以使用的技艺。")
		return
	var targeting: TargetingDefinition = art_state.definition.targeting
	if targeting == null:
		_set_feedback("该技艺缺少目标配置。")
		return
	if targeting.minimum_targets != 1 or targeting.maximum_targets != 1:
		_set_feedback("当前调试界面只支持单目标技艺。")
		return

	_pending_art_slot_index = _selected_art_slot_index
	_reachable_cells.clear()
	_art_range_cells.clear()
	_targetable_cells.clear()
	if targeting.target_kind == GameEnums.TargetKind.BATTLE:
		var battle_selection: TargetSelection = TargetSelection.new()
		battle_selection.targets_battle = true
		_execute_art(battle_selection)
		return

	_refresh_targetable_cells()
	if _targetable_cells.is_empty():
		_set_feedback("已显示技艺射程，但当前没有合法落点。")
	else:
		_set_feedback("浅紫格子是射程，亮紫格子可以确认攻击。")
	_refresh_view()


func _execute_pending_art(coordinate: Vector2i) -> void:
	if not _targetable_cells.has(coordinate):
		_set_feedback("该格子不是当前技艺的合法目标。")
		return
	var selection: TargetSelection = _selection_for_coordinate(
			_pending_art_slot_index,
			coordinate
	)
	if selection == null:
		_set_feedback("无法从该格子构造目标。")
		return
	_execute_art(selection)


func _execute_art(selection: TargetSelection) -> void:
	var request: UseArtActionRequest = UseArtActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			_selected_unit_id,
			_pending_art_slot_index,
			selection
	)
	var result: ActionExecutionResult = _action_service.execute(_battle, request)
	_pending_art_slot_index = -1
	_art_range_cells.clear()
	_targetable_cells.clear()
	if result.is_successful:
		_set_feedback(BattleDebugTextFormatter.action_result_text(result))
		if (
			_battle.phase == GameEnums.BattlePhase.VICTORY
			or _battle.phase == GameEnums.BattlePhase.FAILURE
		):
			_selected_unit_id = 0
			_selected_art_slot_index = -1
	else:
		_set_feedback(
				"无法使用技艺：%s。"
				% BattleDebugTextFormatter.failure_code_text(result.failure_code)
		)
	_populate_art_selector()
	_refresh_reachable_cells()
	_refresh_view()


func _refresh_targetable_cells() -> void:
	_art_range_cells = _art_targeting.find_range_cells(
			_battle,
			_selected_unit_id,
			_pending_art_slot_index
	)
	_targetable_cells = _art_targeting.find_targetable_cells(
			_battle,
			_action_service,
			_selected_unit_id,
			_pending_art_slot_index
	)


func _selection_for_coordinate(
		slot_index: int,
		coordinate: Vector2i
) -> TargetSelection:
	return _art_targeting.selection_for_coordinate(
			_battle,
			_selected_unit_id,
			slot_index,
			coordinate
	)


func _refresh_view() -> void:
	if grid_view != null:
		grid_view.present(_battle.grid if _battle != null else null)
	if unit_view != null:
		unit_view.present(_battle)
	_refresh_highlights()
	_refresh_status()


func _refresh_highlights() -> void:
	if highlight_view == null:
		return
	var selected_coordinate: GridCoordinate
	if _battle != null and _selected_unit_id > 0:
		selected_coordinate = _battle.grid.find_occupant(
				GameEnums.GridOccupantKind.UNIT,
				_selected_unit_id
		)
	highlight_view.present(
			selected_coordinate,
			_hovered_coordinate,
			_reachable_cells,
			_art_range_cells,
			_targetable_cells
	)


func _refresh_status() -> void:
	if status_view != null:
		status_view.present(
				_battle,
				_selected_unit_id,
				_selected_art_slot_index,
				_pending_art_slot_index
		)


func _populate_art_selector() -> void:
	var unit: UnitState
	if _battle != null:
		unit = _battle.get_unit(_selected_unit_id)
	if status_view == null:
		_selected_art_slot_index = -1
		return
	_selected_art_slot_index = status_view.rebuild_art_options(
			unit,
			_selected_art_slot_index
	)


func _get_selected_art_state(unit: UnitState) -> ArtState:
	return _art_targeting.get_art_state(
			_battle,
			unit.instance_id if unit != null else 0,
			_selected_art_slot_index
	)


func _has_complete_scene_configuration() -> bool:
	return (
		grid_view != null
		and highlight_view != null
		and unit_view != null
		and status_view != null
		and ground_terrain != null
		and difficult_terrain != null
		and blocked_terrain != null
		and player_unit_definition != null
		and enemy_unit_definition != null
	)


func _fail_rebuild(message: String) -> bool:
	_battle = null
	_set_feedback(message)
	_refresh_view()
	return false


func _set_feedback(message: String) -> void:
	if feedback_label != null:
		feedback_label.text = message

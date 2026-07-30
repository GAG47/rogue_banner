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
@export var phase_label: Label
@export var round_label: Label
@export var selected_unit_label: Label
@export var feedback_label: Label
@export var end_turn_button: Button
@export var reset_button: Button

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
var _hovered_coordinate: GridCoordinate
var _reachable_cells: Dictionary[Vector2i, int] = {}


func _init() -> void:
	_action_service = BattleActionService.new(
			GridPathfinder.new(),
			_turn_service
	)


func _ready() -> void:
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
	_hovered_coordinate = null
	_reachable_cells.clear()

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
	_set_feedback("选择蓝色单位，然后点击高亮格子。")
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
				% _failure_code_text(result.failure_code)
		)
	_refresh_reachable_cells()
	_refresh_view()


func _select_unit(unit_id: int) -> void:
	_selected_unit_id = unit_id
	var unit: UnitState = _battle.get_unit(unit_id)
	if unit != null:
		_set_feedback("已选择%s，单位编号%d。" % [
			unit.definition.display_name,
			unit.instance_id,
		])
	_refresh_reachable_cells()
	_refresh_view()


func _refresh_reachable_cells() -> void:
	_reachable_cells.clear()
	if _battle == null or _selected_unit_id <= 0:
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
		_reachable_cells.clear()
		_set_feedback(
				"回合已推进至%s。"
				% _side_text(_battle.active_side)
		)
	else:
		_set_feedback(
				"无法推进回合：%s。"
				% _failure_code_text(result.failure_code)
		)
	_refresh_view()


func _on_reset_pressed() -> void:
	rebuild_debug_battle()


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
			_reachable_cells
	)


func _refresh_status() -> void:
	if _battle == null:
		if phase_label != null:
			phase_label.text = "阶段：不可用"
		if round_label != null:
			round_label.text = "轮次：--"
		if selected_unit_label != null:
			selected_unit_label.text = "当前单位\n未选择"
		if end_turn_button != null:
			end_turn_button.disabled = true
		return

	if phase_label != null:
		phase_label.text = "阶段：%s\n当前行动方：%s" % [
			_phase_text(_battle.phase),
			_side_text(_battle.active_side),
		]
	if round_label != null:
		round_label.text = "轮次：%d" % _battle.round_number
	if end_turn_button != null:
		end_turn_button.disabled = false
		if _battle.active_side == GameEnums.BattleSide.PLAYER:
			end_turn_button.text = "结束玩家回合"
		else:
			end_turn_button.text = "推进敌方回合"

	if selected_unit_label == null:
		return
	var selected_unit: UnitState = _battle.get_unit(_selected_unit_id)
	if selected_unit == null:
		selected_unit_label.text = "当前单位\n未选择"
		return
	var position: GridCoordinate = _battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			selected_unit.instance_id
	)
	var position_text: String = "--"
	if position != null:
		position_text = "%d, %d" % [position.value.x, position.value.y]
	selected_unit_label.text = (
		"当前单位\n"
		+ "%s，编号%d\n" % [
			selected_unit.definition.display_name,
			selected_unit.instance_id,
		]
		+ "生命：%d / %d\n" % [
			selected_unit.current_health,
			selected_unit.definition.max_health,
		]
		+ "行动点：%d / %d\n" % [
			selected_unit.current_ap,
			selected_unit.definition.max_ap,
		]
		+ "格子：%s" % position_text
	)


func _has_complete_scene_configuration() -> bool:
	return (
		grid_view != null
		and highlight_view != null
		and unit_view != null
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


func _phase_text(phase: GameEnums.BattlePhase) -> String:
	match phase:
		GameEnums.BattlePhase.SETUP:
			return "准备"
		GameEnums.BattlePhase.PLAYER_TURN:
			return "玩家回合"
		GameEnums.BattlePhase.ENEMY_TURN:
			return "敌方回合"
		GameEnums.BattlePhase.VICTORY:
			return "胜利"
		GameEnums.BattlePhase.FAILURE:
			return "失败"
	return "未知"


func _side_text(side: GameEnums.BattleSide) -> String:
	if side == GameEnums.BattleSide.PLAYER:
		return "玩家"
	return "敌方"


func _failure_code_text(code: GameEnums.ActionFailureCode) -> String:
	match code:
		GameEnums.ActionFailureCode.NONE:
			return "没有错误"
		GameEnums.ActionFailureCode.INVALID_REQUEST:
			return "行动请求无效"
		GameEnums.ActionFailureCode.INVALID_BATTLE:
			return "战斗状态无效"
		GameEnums.ActionFailureCode.INVALID_PHASE:
			return "当前阶段不允许此行动"
		GameEnums.ActionFailureCode.BATTLE_NOT_ACTIVE:
			return "战斗尚未进入行动阶段"
		GameEnums.ActionFailureCode.WRONG_TURN:
			return "当前不是该行动方的回合"
		GameEnums.ActionFailureCode.ACTOR_NOT_FOUND:
			return "找不到行动单位"
		GameEnums.ActionFailureCode.ACTOR_SIDE_MISMATCH:
			return "行动单位不属于请求方"
		GameEnums.ActionFailureCode.ACTOR_DEFEATED:
			return "行动单位已经被击败"
		GameEnums.ActionFailureCode.ACTOR_NOT_PLACED:
			return "行动单位尚未放置"
		GameEnums.ActionFailureCode.DESTINATION_OUT_OF_BOUNDS:
			return "目标格超出棋盘"
		GameEnums.ActionFailureCode.DESTINATION_BLOCKED:
			return "目标格不可通行"
		GameEnums.ActionFailureCode.DESTINATION_OCCUPIED:
			return "目标格已被占用"
		GameEnums.ActionFailureCode.DESTINATION_UNCHANGED:
			return "目标格就是当前位置"
		GameEnums.ActionFailureCode.NO_PATH:
			return "不存在可用路径"
		GameEnums.ActionFailureCode.INSUFFICIENT_AP:
			return "行动点不足"
		GameEnums.ActionFailureCode.ART_NOT_FOUND:
			return "找不到指定技艺"
		GameEnums.ActionFailureCode.ART_NOT_USABLE:
			return "该技艺无法主动使用"
		GameEnums.ActionFailureCode.ART_ON_COOLDOWN:
			return "该技艺仍在冷却"
		GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION:
			return "目标选择无效"
		GameEnums.ActionFailureCode.ART_EXECUTION_UNAVAILABLE:
			return "技艺执行尚未开放"
		GameEnums.ActionFailureCode.UNSUPPORTED_ACTION:
			return "当前不支持此类行动"
		GameEnums.ActionFailureCode.STATE_CHANGED:
			return "战斗状态已经发生变化"
	return "未知错误"

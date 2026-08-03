class_name RunScreenController
extends Control

const RUN_SEED: int = 20260802

@export_category("Views")
@export var shell_header: Control
@export var shell_content: Control
@export var header_view: RunHeaderView
@export var map_panel: MapPanelView
@export var deployment_panel: DeploymentPanelView
@export var battle_host: Control
@export var battle_screen: BattleScreenController
@export var reward_panel: RewardPanelView
@export var event_panel: EventPanelView
@export var result_panel: RunResultView
@export var inventory_overlay: InventoryOverlayView
@export var settings_overlay: SettingsOverlayView
@export var feedback_toast: Control
@export var feedback_label: Label
@export var feedback_timer: Timer

@export_category("Starting Content")
@export var hero_definition: HeroDefinition
@export var map_definition: MapDefinition
@export var starting_scrolls: Array[ScrollDefinition] = []

var _session: RunSessionController = RunSessionController.new()
var _snapshot: RunSessionSnapshot
var _bound_battle: BattleState
var _map_overlay_open: bool = false
var _tooltips_enabled: bool = true


func _ready() -> void:
	_connect_interface()
	start_new_run()


func start_new_run() -> bool:
	if hero_definition == null or map_definition == null:
		_show_feedback("v8 初始内容配置不完整。")
		return false
	var setup: RunSetup = RunSetup.create(
		hero_definition,
		RUN_SEED,
		4,
		3,
		40
	)
	var result: RunSessionResult = _session.start_new_run(
		setup,
		map_definition,
		starting_scrolls
	)
	_bound_battle = null
	_map_overlay_open = false
	inventory_overlay.visible = false
	settings_overlay.visible = false
	_present_result(result, "")
	return result.succeeded


func get_snapshot() -> RunSessionSnapshot:
	return _snapshot


func get_session() -> RunSessionController:
	return _session


func _refresh() -> void:
	_snapshot = _session.get_snapshot()
	if _snapshot == null:
		return
	var in_battle: bool = _snapshot.route == RunSessionRoute.Value.BATTLE
	if in_battle:
		_map_overlay_open = false
	var map_visible: bool = (
		_snapshot.route == RunSessionRoute.Value.MAP
		or _map_overlay_open
	)
	shell_header.visible = not in_battle
	shell_content.offset_top = 0.0 if in_battle else 64.0
	shell_content.offset_bottom = 0.0
	header_view.present(
		_snapshot.summary,
		_snapshot.inventory,
		_snapshot.route,
		map_visible
	)
	map_panel.visible = map_visible
	deployment_panel.visible = (
		not map_visible
		and _snapshot.route == RunSessionRoute.Value.DEPLOYMENT
	)
	battle_host.visible = in_battle
	reward_panel.visible = not map_visible and _snapshot.route in [
		RunSessionRoute.Value.REWARD,
		RunSessionRoute.Value.SHOP,
	]
	event_panel.visible = (
		not map_visible
		and _snapshot.route == RunSessionRoute.Value.EVENT
	)
	result_panel.visible = (
		not map_visible
		and _snapshot.route == RunSessionRoute.Value.RESULT
	)
	if map_panel.visible:
		map_panel.present(_snapshot.map)
	if deployment_panel.visible:
		deployment_panel.present(_snapshot.deployment)
	if reward_panel.visible:
		reward_panel.present(
			_snapshot.reward,
			_snapshot.inventory,
			_snapshot.route == RunSessionRoute.Value.SHOP
		)
	if event_panel.visible:
		event_panel.present(_snapshot.event, _snapshot.inventory)
	if result_panel.visible:
		result_panel.present(_snapshot.summary)
	if battle_host.visible:
		var battle: BattleState = _session.get_current_battle_for_host()
		if battle != null and battle != _bound_battle:
			_bound_battle = battle
			battle_screen.present_external_battle(battle)
	else:
		if _bound_battle != null:
			battle_screen.clear_external_battle()
		_bound_battle = null


func _connect_interface() -> void:
	header_view.map_requested.connect(_on_map_requested)
	header_view.build_requested.connect(_on_build_requested)
	header_view.settings_requested.connect(_on_settings_requested)
	map_panel.node_requested.connect(_on_node_requested)
	deployment_panel.battle_start_requested.connect(_on_battle_start_requested)
	battle_screen.external_battle_continue_requested.connect(
		_on_battle_continue_requested
	)
	reward_panel.option_claim_requested.connect(_on_reward_claim_requested)
	reward_panel.option_skip_requested.connect(_on_reward_skip_requested)
	reward_panel.offer_finish_requested.connect(_on_reward_finish_requested)
	reward_panel.offer_take_all_requested.connect(_on_reward_take_all_requested)
	reward_panel.shop_close_requested.connect(_on_shop_close_requested)
	reward_panel.scroll_discard_requested.connect(_on_reward_scroll_discard_requested)
	event_panel.choice_requested.connect(_on_event_choice_requested)
	event_panel.result_execute_requested.connect(_on_event_execute_requested)
	inventory_overlay.command_requested.connect(_on_inventory_command_requested)
	inventory_overlay.closed.connect(_on_inventory_closed)
	settings_overlay.closed.connect(_on_settings_closed)
	settings_overlay.abandon_requested.connect(_on_abandon_requested)
	settings_overlay.tooltips_changed.connect(_on_tooltips_changed)
	feedback_timer.timeout.connect(
		func() -> void: feedback_toast.visible = false
	)
	result_panel.new_run_requested.connect(start_new_run)


func _on_node_requested(node_instance_id: int) -> void:
	_present_result(
		_session.advance_to_node(node_instance_id),
		"已进入节点。"
	)


func _on_battle_start_requested(
	deployments: Array[RunUnitDeployment]
) -> void:
	_present_result(
		_session.start_current_battle(deployments),
		"战斗开始。敌人已经公布第一批意图。"
	)


func _on_battle_continue_requested() -> void:
	_present_result(
		_session.submit_current_battle_result(),
		"战斗结果已经写回远征。"
	)


func _on_reward_claim_requested(
	offer_id: int,
	option_id: int,
	destination: RewardGrantDestination
) -> void:
	_present_result(
		_session.claim_offer_option(offer_id, option_id, destination),
		"奖励已经领取。"
	)


func _on_reward_skip_requested(offer_id: int, option_id: int) -> void:
	_present_result(
		_session.skip_offer_option(offer_id, option_id),
		"该项奖励已经放弃。"
	)


func _on_reward_finish_requested(offer_id: int) -> void:
	_present_result(
		_session.finish_offer(offer_id),
		"奖励处理完成，节点已经结算。"
	)


func _on_reward_take_all_requested(offer_id: int) -> void:
	_present_result(
		_session.take_all_offer(offer_id),
		"全部奖励已经领取。"
	)


func _on_shop_close_requested(offer_id: int) -> void:
	_present_result(_session.close_shop(offer_id), "已经离开商店。")


func _on_reward_scroll_discard_requested(stack_id: int) -> void:
	_present_result(
		_session.discard_scroll_during_offer(stack_id),
		"已经丢弃一张卷轴。"
	)


func _on_event_choice_requested(choice_id: StringName) -> void:
	_present_result(_session.choose_event(choice_id), "事件结果已经确定。")


func _on_event_execute_requested(request: MapEventResolveRequest) -> void:
	_present_result(_session.execute_event(request), "事件已经结算。")


func _on_map_requested() -> void:
	if _snapshot == null:
		return
	if _snapshot.route == RunSessionRoute.Value.MAP:
		_map_overlay_open = false
		_refresh()
		return
	if _snapshot.route in [
		RunSessionRoute.Value.DEPLOYMENT,
		RunSessionRoute.Value.REWARD,
		RunSessionRoute.Value.SHOP,
		RunSessionRoute.Value.EVENT,
	]:
		_map_overlay_open = not _map_overlay_open
		_refresh()


func _on_build_requested() -> void:
	if _snapshot == null:
		return
	inventory_overlay.present(
		_snapshot.inventory,
		_snapshot.route == RunSessionRoute.Value.MAP
	)


func _on_settings_requested() -> void:
	if _snapshot == null:
		return
	settings_overlay.present(
		_tooltips_enabled,
		_snapshot.route != RunSessionRoute.Value.RESULT
	)


func _on_inventory_closed() -> void:
	inventory_overlay.visible = false


func _on_inventory_command_requested(command: RunCommand) -> void:
	var result: RunSessionResult = _session.execute_inventory_command(command)
	_present_result(result, "队伍配置已经更新。")
	if result.succeeded and _snapshot != null:
		inventory_overlay.present(_snapshot.inventory, true)


func _on_settings_closed() -> void:
	settings_overlay.visible = false


func _on_tooltips_changed(enabled: bool) -> void:
	_tooltips_enabled = enabled
	map_panel.set_tooltips_enabled(enabled)


func _on_abandon_requested() -> void:
	settings_overlay.visible = false
	_present_result(_session.abandon_run(), "远征已经放弃。")


func _present_result(result: RunSessionResult, _success_message: String) -> void:
	if result == null or not result.succeeded:
		_show_feedback(RunUiTextFormatter.result_text(result))
	else:
		_map_overlay_open = false
	_refresh()


func _show_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_toast.visible = true
	feedback_timer.start()

class_name RunDebugController
extends Control

const RUN_SEED: int = 20260801
const BATTLE_GRID_SIZE: Vector2i = Vector2i(5, 2)

@export_category("Interface")
@export var run_status: RichTextLabel
@export var battle_status: RichTextLabel
@export var offer_status: RichTextLabel
@export var feedback_label: Label
@export var primary_action_button: Button
@export var offer_option_button_1: Button
@export var offer_option_button_2: Button
@export var offer_option_button_3: Button
@export var reset_button: Button

@export_category("Debug Content")
@export var hero_definition: HeroDefinition
@export var starting_scroll: ScrollDefinition
@export var ground_terrain: TerrainDefinition
@export var enemy_definition: EnemyDefinition
@export var battle_reward_pool: RewardPoolDefinition
@export var shop_reward_pool: RewardPoolDefinition

var _run: RunState
var _battle: BattleState
var _run_flow_service: RunFlowService = RunFlowService.new()
var _offer_service: RewardOfferService = RewardOfferService.new()
var _command_service: RunCommandService = RunCommandService.new()
var _battle_flow_service: BattleFlowService = BattleFlowService.new()
var _action_service: BattleActionService = BattleActionService.new()
var _completed_battles: int = 0
var _battle_action_step: int = 0
var _shop_opened: bool = false
var _shop_closed: bool = false
var _reward_art_instance_id: int = 0


func _ready() -> void:
	if not primary_action_button.pressed.is_connected(
			_on_primary_action_pressed
	):
		primary_action_button.pressed.connect(_on_primary_action_pressed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	var buttons: Array[Button] = _offer_buttons()
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		if button != null and not button.pressed.is_connected(
			_on_offer_option_pressed.bind(index)
		):
			button.pressed.connect(_on_offer_option_pressed.bind(index))
	reset_run()


func reset_run() -> void:
	_battle = null
	_completed_battles = 0
	_battle_action_step = 0
	_shop_opened = false
	_shop_closed = false
	_reward_art_instance_id = 0
	if not _has_complete_configuration():
		_run = null
		_set_feedback("调试内容配置不完整。")
		_refresh()
		return
	var setup: RunSetup = RunSetup.create(
			hero_definition,
			RUN_SEED,
			4,
			3,
			60
	)
	_run = RunState.create_from_setup(setup)
	if _run == null:
		_set_feedback("局内状态创建失败。")
		_refresh()
		return
	var scroll_result: RunCommandResult = _command_service.execute(
			_run,
			GrantScrollCommand.create(starting_scroll, 1)
	)
	if not scroll_result.succeeded():
		_run = null
		_set_feedback("初始卷轴加入失败。")
		_refresh()
		return
	_set_feedback("局内状态已创建。开始第一场战斗。")
	_refresh()


func get_run_state() -> RunState:
	return _run


func get_battle_state() -> BattleState:
	return _battle


func _on_primary_action_pressed() -> void:
	if _run == null:
		return
	match _run.get_phase():
		GameEnums.RunPhase.READY:
			_handle_ready_action()
		GameEnums.RunPhase.IN_BATTLE:
			_handle_battle_action()
		GameEnums.RunPhase.CHOOSING_REWARD:
			_set_feedback("请从三个已确定的奖励中选择一个。")
		GameEnums.RunPhase.SHOPPING:
			_close_shop()
		GameEnums.RunPhase.ENDED:
			_set_feedback("本局已经结束，请重置调试流程。")
	_refresh()


func _handle_ready_action() -> void:
	if _completed_battles == 0:
		_start_battle()
		return
	if not _has_reward_art_installed():
		_install_reward_art()
		return
	if not _shop_opened:
		_open_shop()
		return
	if _shop_opened and not _shop_closed:
		_set_feedback("请先完成并关闭商店。")
		return
	if _completed_battles == 1:
		_start_battle()
		return
	_set_feedback("v5 调试循环已完成：构筑已跨越两场战斗。")


func _start_battle() -> void:
	var request: RunBattleStartRequest = RunBattleStartRequest.new()
	request.grid = GridState.create(
			BATTLE_GRID_SIZE.x,
			BATTLE_GRID_SIZE.y,
			ground_terrain
	)
	var deployment_row: int = 0
	for unit: RunUnitState in _run.get_units():
		if unit.is_defeated():
			continue
		request.player_deployments.append(
				RunUnitDeployment.create(
						unit.instance_id,
						Vector2i(0, deployment_row)
				)
		)
		deployment_row += 1
	request.enemy_deployments.append(
			EnemyDeployment.create(enemy_definition, Vector2i(4, 0))
	)
	request.floor_number = _completed_battles + 1
	request.reward_pool = battle_reward_pool
	var result: RunFlowResult = _run_flow_service.start_battle(
			_run,
			request
	)
	if not result.succeeded():
		_set_feedback("战斗启动失败，错误码：%d。" % result.code)
		return
	_battle = result.battle
	_battle_action_step = 0
	_set_feedback("敌人已公布意图。下一步让敌人执行射击。")


func _handle_battle_action() -> void:
	if _battle == null:
		_set_feedback("当前缺少战斗副本。")
		return
	if _battle_action_step == 0:
		var enemy_turn: BattleFlowResult = (
			_battle_flow_service.end_player_turn(_battle)
		)
		if not enemy_turn.succeeded:
			_set_feedback(
					"敌方回合执行失败，错误码：%d。"
					% enemy_turn.failure_code
			)
			return
		_battle_action_step = 1
		if _completed_battles == 0:
			_set_feedback("玩家受到伤害。下一步使用卷轴结束战斗。")
		else:
			_set_feedback("遗物已响应伤害并提供护盾。下一步使用新技艺。")
		return
	if _completed_battles == 0:
		_use_scroll_and_resolve()
	else:
		_use_reward_art_and_resolve()


func _use_scroll_and_resolve() -> void:
	var player_id: int = _first_battle_unit_id(GameEnums.BattleSide.PLAYER)
	var enemy_id: int = _first_battle_unit_id(GameEnums.BattleSide.ENEMY)
	var enemy_position: GridCoordinate = _battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			enemy_id
	)
	var scrolls: Array[BattleScrollStackState] = _battle.get_scrolls()
	if (
		player_id <= 0
		or enemy_id <= 0
		or enemy_position == null
		or scrolls.is_empty()
	):
		_set_feedback("卷轴行动缺少必要目标。")
		return
	var selection: TargetSelection = TargetSelection.new()
	selection.cells.append(enemy_position.value)
	var action: ActionExecutionResult = _action_service.execute(
			_battle,
			UseScrollActionRequest.create(
					player_id,
					scrolls[0].instance_id,
					selection
			)
	)
	if not action.is_successful:
		_set_feedback("卷轴使用失败，错误码：%d。" % action.failure_code)
		return
	_resolve_terminal_battle("卷轴已消耗，战斗结果已一次性写回。")


func _use_reward_art_and_resolve() -> void:
	var player_id: int = _first_battle_unit_id(GameEnums.BattleSide.PLAYER)
	var enemy_id: int = _first_battle_unit_id(GameEnums.BattleSide.ENEMY)
	var enemy_position: GridCoordinate = _battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			enemy_id
	)
	var player: UnitState = _battle.get_unit(player_id)
	if (
		player == null
		or enemy_position == null
		or player.arts.size() < 2
		or player.arts[1] == null
	):
		_set_feedback("新技艺尚未安装到先锋的第二个插槽。")
		return
	var selection: TargetSelection = TargetSelection.new()
	selection.cells.append(enemy_position.value)
	var action: ActionExecutionResult = _action_service.execute(
			_battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					player_id,
					1,
					selection
			)
	)
	if not action.is_successful:
		_set_feedback("新技艺使用失败，错误码：%d。" % action.failure_code)
		return
	_resolve_terminal_battle("新单位、技艺和遗物均已进入第二场战斗。")


func _resolve_terminal_battle(message: String) -> void:
	if _battle.phase != GameEnums.BattlePhase.VICTORY:
		_set_feedback("敌人仍然存活，战斗尚不能结算。")
		return
	var result: RunFlowResult = _run_flow_service.resolve_battle(
			_run,
			_battle
	)
	if not result.succeeded():
		_set_feedback("战斗结果写回失败，错误码：%d。" % result.code)
		return
	_completed_battles += 1
	_battle_action_step = 0
	_set_feedback(message + " 请选择奖励。")


func _on_offer_option_pressed(button_index: int) -> void:
	if _run == null:
		return
	var offer: RewardOffer = _run.get_active_offer()
	if (
		offer == null
		or button_index < 0
		or button_index >= offer.options.size()
	):
		return
	var option: RewardOption = offer.options[button_index]
	if option.status != GameEnums.RewardOptionStatus.AVAILABLE:
		_set_feedback("该选项已经不可用。")
		return
	var destination: RewardGrantDestination = RewardGrantDestination.none()
	if option.payload is HealingRewardDefinition:
		destination = RewardGrantDestination.unit(_run.get_units()[0].instance_id)
	var result: RunCommandResult = _offer_service.claim_option(
			_run,
			offer.offer_id,
			option.option_id,
			destination
	)
	if not result.succeeded():
		_set_feedback("领取或购买失败，错误码：%d。" % result.code)
		_refresh()
		return
	if option.payload is ArtRewardDefinition:
		_reward_art_instance_id = result.art_instance_id
	if offer.rule == GameEnums.RewardOfferRule.PICK_ONE:
		_set_feedback("奖励已领取。若选择了技艺，下一步将其安装。")
	else:
		_set_feedback("商品购买成功，仍可继续购买或关闭商店。")
	_refresh()


func _install_reward_art() -> void:
	var reward_art: RunArtState = _run.get_art(_reward_art_instance_id)
	if reward_art == null:
		_set_feedback("本调试流程需要选择“贯穿突击”奖励。")
		return
	var unit: RunUnitState = _run.get_units()[0]
	var result: RunCommandResult = _command_service.execute(
			_run,
			InstallArtCommand.create(
					unit.instance_id,
					reward_art.instance_id,
					1
			)
	)
	if not result.succeeded():
		_set_feedback("技艺安装失败，错误码：%d。" % result.code)
		return
	_set_feedback("贯穿突击已安装到先锋的第二个插槽。")


func _open_shop() -> void:
	var result: RunFlowResult = _run_flow_service.open_shop(
			_run,
			shop_reward_pool,
			1
	)
	if not result.succeeded():
		_set_feedback("商店打开失败，错误码：%d。" % result.code)
		return
	_shop_opened = true
	_set_feedback("商店库存已经固定。购买遗物和新单位后关闭商店。")


func _close_shop() -> void:
	var offer: RewardOffer = _run.get_active_offer()
	if offer == null:
		return
	var result: RunCommandResult = _offer_service.close_offer(
			_run,
			offer.offer_id
	)
	if not result.succeeded():
		_set_feedback("商店关闭失败，错误码：%d。" % result.code)
		return
	_shop_closed = true
	_set_feedback("商店已关闭。下一步进入第二场战斗。")


func _has_reward_art_installed() -> bool:
	if _run == null or _reward_art_instance_id <= 0:
		return false
	return _run.is_art_installed(_reward_art_instance_id)


func _first_battle_unit_id(side: GameEnums.BattleSide) -> int:
	if _battle == null:
		return 0
	var units: Array[UnitState] = _battle.get_units_for_side(side)
	return units[0].instance_id if not units.is_empty() else 0


func _refresh() -> void:
	_refresh_run_status()
	_refresh_battle_status()
	_refresh_offer_status()
	_refresh_actions()


func _refresh_run_status() -> void:
	if run_status == null:
		return
	if _run == null:
		run_status.text = "局内状态不可用"
		return
	var lines: Array[String] = [
		"阶段：%s" % _run_phase_text(_run.get_phase()),
		"金币：%d" % _run.get_gold(),
		"队伍：%d / %d" % [_run.get_units().size(), _run.team_capacity],
	]
	for unit: RunUnitState in _run.get_units():
		var art_names: Array[String] = []
		for art: RunArtState in _run.get_installed_art_states(unit):
			art_names.append(
					art.definition.display_name
					if art != null and art.definition != null
					else "空插槽"
			)
		lines.append(
				"• %s  生命 %d/%d\n  技艺：%s"
				% [
					unit.definition.display_name,
					unit.current_health,
					unit.definition.max_health,
					"、".join(art_names),
				]
		)
	var relic_names: Array[String] = []
	for relic: RunRelicState in _run.get_relics():
		relic_names.append(relic.definition.display_name)
	lines.append(
			"遗物：%s"
			% ("无" if relic_names.is_empty() else "、".join(relic_names))
	)
	var scroll_names: Array[String] = []
	for stack: ScrollStackState in _run.get_scrolls():
		scroll_names.append(
				"%s×%d" % [stack.definition.display_name, stack.quantity]
		)
	lines.append(
			"卷轴：%s"
			% ("无" if scroll_names.is_empty() else "、".join(scroll_names))
	)
	run_status.text = "\n".join(lines)


func _refresh_battle_status() -> void:
	if battle_status == null:
		return
	if _battle == null:
		battle_status.text = "尚未进入战斗。\n战斗只读取局内快照。"
		return
	var lines: Array[String] = [
		"战斗编号：%d" % _battle.battle_session_id,
		"阶段：%s" % _battle_phase_text(_battle.phase),
		"轮次：%d" % _battle.round_number,
	]
	for unit: UnitState in _battle.get_units():
		lines.append(
				"• %s（%s） 生命 %d  护盾 %d  行动点 %d"
				% [
					unit.definition.display_name,
					"玩家" if unit.side == GameEnums.BattleSide.PLAYER else "敌人",
					unit.current_health,
					unit.current_shield,
					unit.current_ap,
				]
		)
	battle_status.text = "\n".join(lines)


func _refresh_offer_status() -> void:
	if offer_status == null:
		return
	var offer: RewardOffer = _run.get_active_offer() if _run != null else null
	if offer == null:
		offer_status.text = "当前没有奖励或商品报价。"
		return
	var title: String = (
		"战斗奖励：选择一个"
		if offer.rule == GameEnums.RewardOfferRule.PICK_ONE
		else "商店：可购买多个"
	)
	var lines: Array[String] = [title, "报价编号：%d" % offer.offer_id]
	for option: RewardOption in offer.options:
		lines.append(
				"%d. %s%s（%s）"
				% [
					option.option_id,
					_reward_payload_text(option.payload),
					"  %d 金币" % option.price if option.price > 0 else "",
					_option_status_text(option.status),
				]
		)
	offer_status.text = "\n".join(lines)


func _refresh_actions() -> void:
	var offer: RewardOffer = _run.get_active_offer() if _run != null else null
	var buttons: Array[Button] = _offer_buttons()
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		var has_option: bool = offer != null and index < offer.options.size()
		button.visible = has_option
		if has_option:
			var option: RewardOption = offer.options[index]
			button.text = "%d  %s" % [
				option.option_id,
				_reward_payload_text(option.payload),
			]
			button.disabled = (
				option.status != GameEnums.RewardOptionStatus.AVAILABLE
			)
	if primary_action_button == null or _run == null:
		return
	primary_action_button.text = _primary_action_text()


func _offer_buttons() -> Array[Button]:
	return [
		offer_option_button_1,
		offer_option_button_2,
		offer_option_button_3,
	]


func _primary_action_text() -> String:
	match _run.get_phase():
		GameEnums.RunPhase.READY:
			if _completed_battles == 0:
				return "进入第一场战斗"
			if not _has_reward_art_installed():
				return "安装奖励技艺"
			if not _shop_opened:
				return "进入商店"
			if _completed_battles == 1:
				return "进入第二场战斗"
			return "v5 调试完成"
		GameEnums.RunPhase.IN_BATTLE:
			if _battle_action_step == 0:
				return "结束回合并执行敌人意图"
			return "使用卷轴" if _completed_battles == 0 else "使用新技艺"
		GameEnums.RunPhase.CHOOSING_REWARD:
			return "请选择下方奖励"
		GameEnums.RunPhase.SHOPPING:
			return "关闭商店"
		GameEnums.RunPhase.ENDED:
			return "本局已结束"
	return "继续"


func _reward_payload_text(payload: RewardPayloadDefinition) -> String:
	if payload is CurrencyRewardDefinition:
		return "获得 %d 金币" % (payload as CurrencyRewardDefinition).amount
	if payload is ArtRewardDefinition:
		return "技艺：%s" % (
			payload as ArtRewardDefinition
		).art_definition.display_name
	if payload is RelicRewardDefinition:
		return "遗物：%s" % (
			payload as RelicRewardDefinition
		).relic_definition.display_name
	if payload is ScrollRewardDefinition:
		var scroll: ScrollRewardDefinition = payload as ScrollRewardDefinition
		return "卷轴：%s×%d" % [
			scroll.scroll_definition.display_name,
			scroll.quantity,
		]
	if payload is UnitRewardDefinition:
		return "招募：%s" % (
			payload as UnitRewardDefinition
		).unit_definition.display_name
	if payload is HealingRewardDefinition:
		return "治疗 %d 点生命" % (payload as HealingRewardDefinition).amount
	if payload is ArtUpgradeRewardDefinition:
		return "升级一个技艺"
	return "未知奖励"


func _run_phase_text(phase: GameEnums.RunPhase) -> String:
	match phase:
		GameEnums.RunPhase.READY:
			return "整备"
		GameEnums.RunPhase.IN_BATTLE:
			return "战斗中"
		GameEnums.RunPhase.CHOOSING_REWARD:
			return "选择奖励"
		GameEnums.RunPhase.SHOPPING:
			return "商店"
		GameEnums.RunPhase.ENDED:
			return "本局结束"
	return "未知"


func _battle_phase_text(phase: GameEnums.BattlePhase) -> String:
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


func _option_status_text(status: GameEnums.RewardOptionStatus) -> String:
	match status:
		GameEnums.RewardOptionStatus.AVAILABLE:
			return "可用"
		GameEnums.RewardOptionStatus.CLAIMED:
			return "已领取"
		GameEnums.RewardOptionStatus.SOLD:
			return "已售出"
		GameEnums.RewardOptionStatus.CLOSED:
			return "已关闭"
	return "未知"


func _has_complete_configuration() -> bool:
	return (
		hero_definition != null
		and starting_scroll != null
		and ground_terrain != null
		and enemy_definition != null
		and battle_reward_pool != null
		and shop_reward_pool != null
	)


func _set_feedback(message: String) -> void:
	if feedback_label != null:
		feedback_label.text = message


func _on_reset_pressed() -> void:
	reset_run()

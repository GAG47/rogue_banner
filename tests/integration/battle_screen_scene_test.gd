class_name BattleScreenSceneTest
extends RefCounted

const SCENE_PATH: String = "res://scenes/battle/battle_screen.tscn"


static func run(suite: TestSuite) -> void:
	var packed_scene: PackedScene = load(SCENE_PATH) as PackedScene
	suite.assert_true(
		packed_scene != null,
		"The formal Battle Screen scene should load."
	)
	if packed_scene == null:
		return
	var controller: BattleScreenController = (
		packed_scene.instantiate() as BattleScreenController
	)
	suite.assert_true(
		controller != null,
		"The formal Battle Screen should instantiate its typed controller."
	)
	if controller == null:
		return
	suite.assert_true(
		controller.rebuild_battle(),
		"The formal Battle Screen should compose a valid setup state."
	)
	suite.assert_true(
		DefinitionValidator.new().validate(
			controller.encounter_definition
		).is_valid(),
		"The v7 Encounter should pass Definition validation."
	)
	var setup_model: BattleReadModel = controller.get_read_model()
	suite.assert_true(
		setup_model.phase == GameEnums.BattlePhase.SETUP,
		"The formal Battle Screen should begin in deployment."
	)
	suite.assert_int_equal(
		3,
		setup_model.units.size(),
		"Deployment should show the three configured enemies."
	)
	suite.assert_true(
		controller.status_view.deployment_panel.visible,
		"The Chinese deployment panel should be visible during setup."
	)
	suite.assert_true(
		controller.request_deploy_at(Vector2i(0, 1)),
		"The first player Unit should deploy through placement rules."
	)
	suite.assert_false(
		controller.request_deploy_at(Vector2i(0, 1)),
		"Deployment should reject occupied Cells."
	)
	suite.assert_true(
		controller.request_deploy_at(Vector2i(1, 3)),
		"The second player Unit should deploy through placement rules."
	)
	suite.assert_int_equal(
		2,
		controller.get_deployed_count(),
		"The deployment readout should track placed Units."
	)
	suite.assert_false(
		controller.status_view.start_battle_button.disabled,
		"The Battle button should enable after complete deployment."
	)
	suite.assert_true(
		controller.request_start_battle(),
		"The formal Battle Screen should start through BattleFlowService."
	)
	var battle_model: BattleReadModel = controller.get_read_model()
	suite.assert_true(
		battle_model.phase == GameEnums.BattlePhase.PLAYER_TURN,
		"Starting the Battle should enter the first player turn."
	)
	suite.assert_int_equal(
		5,
		battle_model.units.size(),
		"The started Battle should contain two players and three enemies."
	)
	suite.assert_int_equal(
		3,
		battle_model.intents.size(),
		"The first player turn should display all three enemy Intents."
	)
	suite.assert_true(
		controller.status_view.battle_panel.visible,
		"The Battle panel should replace deployment after Battle start."
	)
	var enemies: Array[BattleUnitReadModel] = battle_model.get_units_for_side(
		GameEnums.BattleSide.ENEMY
	)
	suite.assert_true(
		controller.request_inspect_unit(enemies[0].instance_id),
		"Enemy Units should be inspectable without becoming player actors."
	)
	suite.assert_true(
		controller.status_view.use_art_button.disabled,
		"Inspecting an Enemy must not enable its Arts for the player."
	)
	var players: Array[BattleUnitReadModel] = battle_model.get_units_for_side(
		GameEnums.BattleSide.PLAYER
	)
	var player: BattleUnitReadModel = players[0]
	suite.assert_true(
		controller.request_select_unit(player.instance_id),
		"Selecting a Unit should use its stable Battle instance ID."
	)
	suite.assert_true(
		not controller.get_reachable_cells().is_empty(),
		"Selecting a Unit should expose its validated movement range."
	)
	suite.assert_int_equal(
		4,
		controller.status_view.art_selector.item_count,
		"The Battle panel should list installed active and passive Arts."
	)
	controller.request_select_art(0)
	suite.assert_true(
		controller.request_toggle_art_targeting(),
		"The Art button should enter target-selection mode."
	)
	var empty_target: Vector2i = player.coordinate + Vector2i.UP
	suite.assert_true(
		controller.get_targetable_cells().has(empty_target),
		"Cell-targeted Arts should expose legal empty Cell aims."
	)
	controller.request_cell_action(empty_target)
	var after_empty_attack: BattleUnitReadModel = controller.get_read_model().get_unit(
		player.instance_id
	)
	suite.assert_int_equal(
		3,
		after_empty_attack.current_ap,
		"Empty-cell attacks should execute and spend AP."
	)
	controller.request_select_art(1)
	controller.request_toggle_art_targeting()
	controller.request_cell_action(player.coordinate)
	var after_guard: BattleUnitReadModel = controller.get_read_model().get_unit(
		player.instance_id
	)
	suite.assert_int_equal(
		3,
		after_guard.current_shield,
		"Self-targeted Arts should execute through the shared action pipeline."
	)
	suite.assert_true(
		controller.request_end_turn(),
		"Ending the player turn should execute the automatic enemy turn."
	)
	var next_round: BattleReadModel = controller.get_read_model()
	suite.assert_true(
		next_round.phase == GameEnums.BattlePhase.PLAYER_TURN,
		"Enemy automation should return control to the player when nonterminal."
	)
	suite.assert_int_equal(
		2,
		next_round.round_number,
		"Enemy automation should advance to the next round."
	)
	suite.assert_true(
		not next_round.intents.is_empty(),
		"The next player turn should already show refreshed enemy Intents."
	)
	var passive_turn_limit: int = 20
	while (
		not controller.get_read_model().is_terminal()
		and passive_turn_limit > 0
	):
		controller.request_end_turn()
		passive_turn_limit -= 1
	suite.assert_true(
		controller.get_read_model().is_terminal(),
		"Repeated valid turns should eventually reach a terminal result."
	)
	suite.assert_true(
		controller.result_overlay.visible,
		"Terminal Battle state should display the formal result overlay."
	)
	suite.assert_true(
		controller.result_title_label.text.contains("战斗"),
		"The formal result overlay should use Chinese player-facing copy."
	)
	suite.assert_true(
		controller.request_restart_battle(),
		"The formal Battle Screen should support a complete restart."
	)
	suite.assert_true(
		controller.get_read_model().phase == GameEnums.BattlePhase.SETUP,
		"Restarting should return to deployment."
	)
	controller.free()

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
	controller._connect_interface()
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
	suite.assert_false(
		controller.status_view.unit_hud.visible,
		"The lower Unit HUD should stay hidden while no friendly Unit is selected."
	)
	suite.assert_true(
		controller.status_view.turn_control.visible
		and controller.status_view.end_turn_button.visible
		and controller.round_label.text.contains("1"),
		"Round and end-turn controls should remain fixed in the lower-right corner."
	)
	suite.assert_true(
		controller.get_node_or_null(
			"BattleLayout/BattleBodyMargin/BattleBody/SidePanel"
		) == null
		and controller.get_node_or_null("BattleLayout/BattleHeader") == null,
		"The formal Battle layout should remove its former right panel and local header."
	)
	var enemies: Array[BattleUnitReadModel] = battle_model.get_units_for_side(
		GameEnums.BattleSide.ENEMY
	)
	suite.assert_true(
		controller.request_inspect_unit(enemies[0].instance_id),
		"Enemy Units should be inspectable without becoming player actors."
	)
	suite.assert_false(
		controller.status_view.unit_hud.visible,
		"Inspecting an Enemy should not open the friendly Unit HUD."
	)
	var players: Array[BattleUnitReadModel] = battle_model.get_units_for_side(
		GameEnums.BattleSide.PLAYER
	)
	var player: BattleUnitReadModel = players[0]
	var pan_press: InputEventMouseButton = InputEventMouseButton.new()
	pan_press.button_index = MOUSE_BUTTON_MIDDLE
	pan_press.pressed = true
	controller.board_view._gui_input(pan_press)
	var pan_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	pan_motion.relative = Vector2(42.0, 24.0)
	controller.board_view._gui_input(pan_motion)
	var pan_release: InputEventMouseButton = InputEventMouseButton.new()
	pan_release.button_index = MOUSE_BUTTON_MIDDLE
	pan_release.pressed = false
	controller.board_view._gui_input(pan_release)
	suite.assert_true(
		controller.board_view.get_pan_offset().is_equal_approx(
			Vector2(42.0, 24.0)
		),
		"Holding the pan input and dragging should offset only the board presentation."
	)
	controller.board_view.reset_pan()
	var space_down: InputEventKey = InputEventKey.new()
	space_down.keycode = KEY_SPACE
	space_down.pressed = true
	controller.board_view._input(space_down)
	var left_pan_press: InputEventMouseButton = InputEventMouseButton.new()
	left_pan_press.button_index = MOUSE_BUTTON_LEFT
	left_pan_press.pressed = true
	controller.board_view._gui_input(left_pan_press)
	var left_pan_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	left_pan_motion.relative = Vector2(-30.0, 18.0)
	controller.board_view._gui_input(left_pan_motion)
	var left_pan_release: InputEventMouseButton = InputEventMouseButton.new()
	left_pan_release.button_index = MOUSE_BUTTON_LEFT
	left_pan_release.pressed = false
	controller.board_view._gui_input(left_pan_release)
	var space_up: InputEventKey = InputEventKey.new()
	space_up.keycode = KEY_SPACE
	space_up.pressed = false
	controller.board_view._input(space_up)
	suite.assert_true(
		controller.board_view.get_pan_offset().is_equal_approx(
			Vector2(-30.0, 18.0)
		),
		"Holding Space and left-dragging should pan the Battle presentation."
	)
	controller.board_view.reset_pan()
	var initial_zoom: float = controller.board_view.get_zoom_factor()
	var zoom_in_event: InputEventMouseButton = InputEventMouseButton.new()
	zoom_in_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_in_event.pressed = true
	zoom_in_event.position = controller.board_view.size * 0.5
	controller.board_view._gui_input(zoom_in_event)
	suite.assert_true(
		controller.board_view.get_zoom_factor() > initial_zoom,
		"Mouse-wheel up should zoom the Battle presentation in."
	)
	var zoom_out_event: InputEventMouseButton = InputEventMouseButton.new()
	zoom_out_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zoom_out_event.pressed = true
	zoom_out_event.position = controller.board_view.size * 0.5
	controller.board_view._gui_input(zoom_out_event)
	suite.assert_true(
		is_equal_approx(controller.board_view.get_zoom_factor(), initial_zoom),
		"Mouse-wheel down should zoom the Battle presentation out."
	)
	controller.board_view.reset_zoom()
	var board_position_before_selection: Vector2 = (
		controller.board_view.battle_board.position
	)
	var board_click: InputEventMouseButton = InputEventMouseButton.new()
	board_click.button_index = MOUSE_BUTTON_LEFT
	board_click.pressed = true
	board_click.position = (
		controller.board_view.battle_board.position
		+ controller.grid_view.coordinate_center(player.coordinate)
	)
	controller.board_view._gui_input(board_click)
	suite.assert_int_equal(
		player.instance_id,
		controller.get_selected_unit_id(),
		"The board-local GUI input should select a player Unit."
	)
	suite.assert_true(
		controller.status_view.unit_hud.visible
		and controller.status_view.unit_portrait.texture != null
		and controller.status_view.unit_name_label.text == player.display_name,
		"Selecting a friendly Unit should reveal its portrait and name in the lower HUD."
	)
	suite.assert_true(
		controller.status_view.unit_hud is MarginContainer
		and controller.get_node_or_null(
			"BattleHud/SelectedUnitHud/UnitHudMargin/UnitHudRow/IdentityDivider"
		) == null
		and controller.get_node_or_null(
			"BattleHud/SelectedUnitHud/UnitHudMargin/UnitHudRow/ArtSection/ActionFooter/UseArtButton"
		) == null
		and controller.get_node_or_null(
			"BattleHud/SelectedUnitHud/UnitHudMargin/UnitHudRow/ArtSection/ActionFooter/ScrollSelector"
		) == null,
		"The selected Unit HUD should float without an enclosing panel, divider, or duplicate action controls."
	)
	suite.assert_true(
		controller.board_view.battle_board.position.is_equal_approx(
			board_position_before_selection
		),
		"Opening the lower Unit HUD must not resize or reposition the Battlefield."
	)
	suite.assert_true(
		controller.status_view.health_bar.value == float(player.current_health)
		and controller.status_view.ap_label.text.contains(
			str(player.current_ap)
		),
		"The friendly Unit HUD should show health and available AP."
	)
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
		controller.status_view.get_art_button_count(),
		"The Battle panel should list installed active and passive Arts."
	)
	var fixed_art_slots: bool = true
	var art_button_width: float = -1.0
	for art_control: Node in controller.status_view.art_list.get_children():
		if (
			art_control is not Control
			or (
				(art_control as Control).size_flags_horizontal
				& Control.SIZE_EXPAND
			) != 0
		):
			fixed_art_slots = false
			break
		var art_control_width: float = (
			(art_control as Control).custom_minimum_size.x
		)
		if art_button_width < 0.0:
			art_button_width = art_control_width
		elif not is_equal_approx(art_button_width, art_control_width):
			fixed_art_slots = false
			break
	suite.assert_true(
		fixed_art_slots
		and art_button_width <= 140.0
		and controller.status_view.art_list.alignment
		== BoxContainer.ALIGNMENT_CENTER
		and controller.status_view.art_list.get_theme_constant("separation") >= 16
		and controller.status_view.unit_hud.offset_right
		>= controller.status_view.turn_control.offset_left - 12.0,
		"Equal fixed-width Arts should be centered with deliberate spacing in the full-width lower HUD."
	)
	var first_art_button: Button = (
		controller.status_view.art_list.get_child(0) as Button
	)
	first_art_button.pressed.emit()
	suite.assert_true(
		not controller.get_targetable_cells().is_empty()
		and controller.get_node_or_null(
			"BattleHud/BattleFeedbackToast"
		) == null,
		"Pressing an Art should enter targeting without a transient-message layer."
	)
	var cancel_targeting: InputEventMouseButton = InputEventMouseButton.new()
	cancel_targeting.button_index = MOUSE_BUTTON_RIGHT
	cancel_targeting.pressed = true
	controller.board_view._gui_input(cancel_targeting)
	suite.assert_true(
		controller.get_targetable_cells().is_empty()
		and not controller.get_reachable_cells().is_empty(),
		"Right-clicking should cancel targeting and restore movement mode."
	)
	first_art_button.pressed.emit()
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
	var second_art_button: Button = (
		controller.status_view.art_list.get_child(1) as Button
	)
	second_art_button.pressed.emit()
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
		controller.round_label.text.contains("2"),
		"The fixed lower-right round display should refresh after turn execution."
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

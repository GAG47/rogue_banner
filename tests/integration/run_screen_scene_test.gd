class_name RunScreenSceneTest
extends RefCounted

const SCENE_PATH: String = "res://scenes/run/run_screen.tscn"


static func run(suite: TestSuite) -> void:
	_test_formal_run_scene(suite)
	_test_branching_route_graph(suite)


static func _test_formal_run_scene(suite: TestSuite) -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	suite.assert_true(packed != null, "The formal v8 Run Screen should load.")
	if packed == null:
		return
	var controller: RunScreenController = packed.instantiate() as RunScreenController
	suite.assert_true(
		controller != null,
		"The v8 scene should instantiate its typed session UI controller."
	)
	if controller == null:
		return
	controller._connect_interface()
	controller.header_view._ready()
	suite.assert_true(
		controller.start_new_run(),
		"The v8 scene should create the fixed first playable Run."
	)
	var snapshot: RunSessionSnapshot = controller.get_snapshot()
	suite.assert_true(
		snapshot != null and snapshot.route == RunSessionRoute.Value.MAP,
		"The formal Run Screen should open on the authoritative Map route."
	)
	suite.assert_true(
		controller.map_panel.visible
		and controller.header_view.hero_portrait.texture != null
		and controller.header_view.gold_label.text.contains("40"),
		"The first route should show its Map, Hero portrait, and Gold summary."
	)
	suite.assert_int_equal(
		snapshot.summary.scroll_capacity,
		controller.header_view.scroll_slot_row.get_child_count(),
		"The compact header should render occupied and empty Scroll slots."
	)
	var first_scroll_slot: Button = (
		controller.header_view.scroll_slot_row.get_child(0) as Button
	)
	suite.assert_true(
		first_scroll_slot != null and not first_scroll_slot.disabled,
		"An occupied top Scroll slot should be directly clickable."
	)
	suite.assert_true(
		first_scroll_slot.tooltip_text.is_empty(),
		"Occupied Scroll slots should not use the native detached tooltip."
	)
	first_scroll_slot.mouse_entered.emit()
	suite.assert_true(
		controller.header_view.scroll_detail_popup.visible
		and controller.header_view.scroll_detail_name_label.text.contains("卷轴")
		and controller.header_view.scroll_detail_effect_label.text.contains(
			"造成7点伤害"
		)
		and controller.header_view.scroll_detail_meta_label.text.contains("射程"),
		"Hovering an occupied Scroll should open the attached custom detail card."
	)
	first_scroll_slot.mouse_exited.emit()
	suite.assert_false(
		controller.header_view.scroll_detail_popup.visible,
		"Leaving an unselected Scroll should hide its custom detail card."
	)
	first_scroll_slot.pressed.emit()
	suite.assert_true(
		controller.header_view.scroll_detail_popup.visible
		and controller.header_view.scroll_action_popup.visible
		and controller.header_view.scroll_use_button.disabled
		and not controller.header_view.scroll_discard_button.disabled
		and controller.header_view.scroll_discard_button.text == "丢弃"
		and controller.header_view.scroll_action_popup.size.x <= 180.0
		and controller.header_view.scroll_action_popup.size.y <= 60.0,
		"Clicking a Scroll should keep its detail card and append a compact action menu."
	)
	suite.assert_true(
		controller.get_node_or_null(
			"ScrollActionPopup/ScrollActionMargin/ScrollActionContent"
		) == null,
		"The click menu should not duplicate the hover details in a large panel."
	)
	var leave_scroll_controls: InputEventMouseMotion = InputEventMouseMotion.new()
	leave_scroll_controls.position = Vector2(-100.0, -100.0)
	controller.header_view._input(leave_scroll_controls)
	suite.assert_true(
		not controller.header_view.scroll_detail_popup.visible
		and not controller.header_view.scroll_action_popup.visible,
		"Leaving the selected Scroll and both attached cards should close them."
	)
	first_scroll_slot.pressed.emit()
	first_scroll_slot.pressed.emit()
	suite.assert_false(
		controller.header_view.scroll_action_popup.visible,
		"Clicking the same Scroll should close its action menu without changing Run state."
	)
	suite.assert_true(
		controller.header_view.map_button.button_pressed,
		"The Map button should show the current Map as selected."
	)
	suite.assert_true(
		controller.get_node_or_null("Header/HeaderMargin/HeaderRow/RunTitleLabel")
		== null
		and controller.get_node_or_null("Footer") == null,
		"The formal Run UI should remove the expedition title and footer bar."
	)
	suite.assert_true(
		controller.settings_overlay != null
		and controller.get_node_or_null("FeedbackToast") == null
		and controller.get_node_or_null("FeedbackTimer") == null,
		"Settings should remain available without a global transient-message layer."
	)
	suite.assert_false(
		controller.battle_host.visible,
		"The Battle host should stay hidden until a Battle is started."
	)
	var graph: MapRouteGraphView = controller.map_panel.route_graph
	suite.assert_int_equal(
		snapshot.map.nodes.size(),
		graph.get_rendered_node_count(),
		"The v8.1 Map should render every generated node in the route graph."
	)
	suite.assert_int_equal(
		snapshot.map.connections.size(),
		graph.get_rendered_connection_count(),
		"The v8.1 Map should render the authoritative connection set."
	)
	suite.assert_true(
		snapshot.map.reachable_node_ids.size() >= 2
		and snapshot.map.reachable_node_ids.size() <= 4,
		"The authored v8.1 route should begin with a variable-width choice layer."
	)
	suite.assert_true(
		controller.get_node_or_null(
			"Content/ContentMargin/MapPanel/MapMargin/MapRow/MapInfo"
		) == null,
		"The formal Map should not retain the debug-style information sidebar."
	)
	var layer_sizes: Dictionary[int, int] = {}
	var maximum_layer: int = 0
	for node: MapNodeState in snapshot.map.nodes:
		maximum_layer = maxi(maximum_layer, node.layer_index)
		if node.layer_index > 0 and node.definition.kind != GameEnums.MapNodeKind.BOSS:
			layer_sizes[node.layer_index] = layer_sizes.get(node.layer_index, 0) + 1
	var distinct_layer_sizes: Array[int] = []
	for layer_size: int in layer_sizes.values():
		if not distinct_layer_sizes.has(layer_size):
			distinct_layer_sizes.append(layer_size)
	suite.assert_int_equal(
		14,
		maximum_layer,
		"The first formal route should contain thirteen regular layers and a Boss."
	)
	suite.assert_true(
		distinct_layer_sizes.size() > 1,
		"The formal route should not render every regular layer at one fixed width."
	)
	suite.assert_true(
		graph.is_node_interactive(snapshot.map.reachable_node_ids[0]),
		"Only the next reachable route node should be interactive."
	)
	var future_node_id: int = _find_node_id_at_layer(snapshot.map, 2)
	suite.assert_false(
		graph.is_node_interactive(future_node_id),
		"Future route nodes should remain visible but non-interactive."
	)
	var boss_id: int = _find_node_id(
		snapshot.map,
		GameEnums.MapNodeKind.BOSS
	)
	suite.assert_true(
		graph.get_node_position(snapshot.map.current_node_id).y
		> graph.get_node_position(boss_id).y,
		"The route should climb vertically from the current node to the Boss."
	)
	var sample_container: Control = graph.get_child(0) as Control
	var sample_button: Button = sample_container.get_child(0) as Button
	suite.assert_true(
		sample_button.size.x <= 44.0,
		"Map nodes should use compact icon-sized controls."
	)
	sample_button.mouse_entered.emit()
	suite.assert_true(
		sample_button.scale.x > 1.0,
		"Map node icons should enlarge when hovered."
	)
	sample_button.mouse_exited.emit()
	_test_deployment_interface(controller, snapshot, suite)
	controller.free()


static func _test_branching_route_graph(suite: TestSuite) -> void:
	var definition: MapDefinition = MapTestFactory.create_map(
		MapTestFactory.create_event_node(false),
		3,
		2,
		3
	)
	var generated: MapGenerationResult = MapGenerationService.new().generate(
		MapGenerationRequest.create(definition, 81231, 0)
	)
	suite.assert_true(
		generated.succeeded(),
		"The branching v8.1 route fixture should generate."
	)
	var model: MapReadModel = MapReadModel.create(generated.map_state)
	var graph: MapRouteGraphView = MapRouteGraphView.new()
	graph.present(model)
	var all_connections_climb: bool = true
	for connection: MapConnection in model.connections:
		if (
			graph.get_node_position(connection.from_node_id).y
			<= graph.get_node_position(connection.to_node_id).y
		):
			all_connections_climb = false
			break
	suite.assert_true(
		all_connections_climb,
		"Every generated connection should be drawn toward a higher layer."
	)
	suite.assert_int_equal(
		model.nodes.size(),
		graph.get_rendered_node_count(),
		"Branching layers should retain every generated node."
	)
	graph.free()


static func _test_deployment_interface(
	controller: RunScreenController,
	map_snapshot: RunSessionSnapshot,
	suite: TestSuite
) -> void:
	controller._on_node_requested(map_snapshot.map.reachable_node_ids[0])
	var snapshot: RunSessionSnapshot = controller.get_snapshot()
	suite.assert_true(
		snapshot != null
		and snapshot.route == RunSessionRoute.Value.DEPLOYMENT
		and controller.deployment_panel.visible,
		"Entering a first-layer Encounter should open the deployment interface."
	)
	if snapshot == null or snapshot.deployment == null:
		return
	var view: DeploymentPanelView = controller.deployment_panel
	view._ready()
	suite.assert_int_equal(
		snapshot.deployment.cells.size(),
		view.get_rendered_cell_count(),
		"v8.2 deployment should render the complete Battlefield, not only deployment Cells."
	)
	suite.assert_int_equal(
		snapshot.deployment.available_units.size(),
		view.get_rendered_unit_count(),
		"Every available unit should appear once in the bottom roster."
	)
	suite.assert_true(
		controller.get_node_or_null(
			"Content/ContentMargin/DeploymentPanel/DeploymentMargin/DeploymentContent/UnitSelector"
		) == null
		and controller.get_node_or_null(
			"Content/ContentMargin/DeploymentPanel/DeploymentMargin/DeploymentContent/DeployedUnitList"
		) == null,
		"The deployment screen should not retain its debug selector or assignment list."
	)
	var deployable_coordinate: Vector2i = Vector2i(-1, -1)
	for cell_index: int in range(snapshot.deployment.cells.size()):
		var cell: DeploymentCellReadModel = snapshot.deployment.cells[cell_index]
		if cell != null and cell.allows_player_deployment:
			deployable_coordinate = cell.coordinate
			break
	var original_board_layers: Array[int] = _child_instance_ids(
		view.board_view.battle_board
	)
	var original_unit_nodes: Array[int] = _child_instance_ids(view.unit_roster)
	var unit_button: Button = view.unit_roster.get_child(0) as Button
	unit_button.pressed.emit()
	suite.assert_true(
		original_board_layers == _child_instance_ids(view.board_view.battle_board)
		and original_unit_nodes == _child_instance_ids(view.unit_roster),
		"Selecting a Unit should update existing controls without duplicating or reordering them."
	)
	var selected_unit_id: int = view.get_selected_unit_id()
	var board_click: InputEventMouseButton = InputEventMouseButton.new()
	board_click.button_index = MOUSE_BUTTON_LEFT
	board_click.pressed = true
	board_click.position = (
		view.board_view.battle_board.position
		+ view.board_view.grid_view.coordinate_center(deployable_coordinate)
	)
	view.board_view._gui_input(board_click)
	suite.assert_true(
		selected_unit_id > 0
		and deployable_coordinate.x >= 0
		and view.is_unit_deployed(selected_unit_id),
		"An undeployed roster unit should be selected and placeable on a highlighted Cell."
	)
	suite.assert_true(
		view.get_deployment_count() == 1
		and not view.start_battle_button.disabled,
		"A placed unit should become deployed and enable the typed Battle start request."
	)
	suite.assert_true(
		original_board_layers == _child_instance_ids(view.board_view.battle_board)
		and original_unit_nodes == _child_instance_ids(view.unit_roster),
		"Deploying a Unit should preserve the Battlefield and roster control order."
	)
	var next_encounter: DeploymentReadModel = DeploymentReadModel.new()
	next_encounter.encounter_instance_id = (
		snapshot.deployment.encounter_instance_id + 1
	)
	next_encounter.encounter_name = snapshot.deployment.encounter_name
	next_encounter.node_kind = snapshot.deployment.node_kind
	next_encounter.width = snapshot.deployment.width
	next_encounter.height = snapshot.deployment.height
	next_encounter.cells.assign(snapshot.deployment.cells)
	next_encounter.available_units.assign(snapshot.deployment.available_units)
	view.present(next_encounter)
	suite.assert_int_equal(
		0,
		view.get_deployment_count(),
		"A new same-name Encounter should not retain the previous node's deployment draft."
	)
	var deployments: Array[RunUnitDeployment] = [
		RunUnitDeployment.create(selected_unit_id, deployable_coordinate),
	]
	controller._on_battle_start_requested(deployments)
	controller.battle_screen._connect_interface()
	var battle_snapshot: RunSessionSnapshot = controller.get_snapshot()
	suite.assert_true(
		battle_snapshot.route == RunSessionRoute.Value.BATTLE
		and controller.shell_header.visible
		and controller.shell_content.offset_top == 64.0
		and controller.battle_host.visible,
		"Battle should remain inside the persistent Run shell and retain its header."
	)
	var battle_model: BattleReadModel = controller.battle_screen.get_read_model()
	var players: Array[BattleUnitReadModel] = battle_model.get_units_for_side(
		GameEnums.BattleSide.PLAYER
	)
	var battle_player: BattleUnitReadModel = players[0]
	var battle_click: InputEventMouseButton = InputEventMouseButton.new()
	battle_click.button_index = MOUSE_BUTTON_LEFT
	battle_click.pressed = true
	battle_click.position = (
		controller.battle_screen.board_view.battle_board.position
		+ controller.battle_screen.grid_view.coordinate_center(
			battle_player.coordinate
		)
	)
	controller.battle_screen.board_view._gui_input(battle_click)
	suite.assert_int_equal(
		battle_player.instance_id,
		controller.battle_screen.get_selected_unit_id(),
		"A player Unit should remain selectable through the hosted Battle board."
	)
	suite.assert_true(
		controller.battle_host.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and controller.battle_screen.board_view.mouse_filter
		== Control.MOUSE_FILTER_STOP,
		"The Run host should yield pointer input to the board-local GUI handler."
	)
	var battle_scroll_slot: Button = (
		controller.header_view.scroll_slot_row.get_child(0) as Button
	)
	battle_scroll_slot.pressed.emit()
	suite.assert_true(
		controller.header_view.scroll_action_popup.visible
		and not controller.header_view.scroll_use_button.disabled,
		"An occupied top Scroll slot should expose Use during Battle."
	)
	controller.header_view.scroll_use_button.pressed.emit()
	suite.assert_true(
		not controller.battle_screen.get_targetable_cells().is_empty()
		and not controller.header_view.scroll_action_popup.visible,
		"Using a top-bar Scroll should enter the shared Battle target-selection flow."
	)
	var cancel_scroll_targeting: InputEventMouseButton = InputEventMouseButton.new()
	cancel_scroll_targeting.button_index = MOUSE_BUTTON_RIGHT
	cancel_scroll_targeting.pressed = true
	controller.battle_screen.board_view._gui_input(cancel_scroll_targeting)
	suite.assert_true(
		controller.battle_screen.get_targetable_cells().is_empty()
		and not controller.battle_screen.get_reachable_cells().is_empty(),
		"Right-clicking should also cancel top-bar Scroll targeting."
	)
	battle_scroll_slot = (
		controller.header_view.scroll_slot_row.get_child(0) as Button
	)
	battle_scroll_slot.pressed.emit()
	controller.header_view.scroll_discard_button.pressed.emit()
	var discarded_scroll_slot: Button = (
		controller.header_view.scroll_slot_row.get_child(0) as Button
	)
	suite.assert_true(
		discarded_scroll_slot.disabled and discarded_scroll_slot.text == "□",
		"Discarding the Battle Scroll should transactionally restore its empty top slot."
	)
	controller._on_map_requested()
	suite.assert_true(
		controller.map_panel.visible and not controller.battle_host.visible,
		"The persistent Map button should open a read-only route overlay during Battle."
	)
	controller._on_map_requested()
	suite.assert_true(
		controller.battle_host.visible
		and controller.battle_screen.get_selected_unit_id()
		== battle_player.instance_id,
		"Closing the Map should restore the same Battle presentation and selection."
	)


static func _child_instance_ids(parent: Node) -> Array[int]:
	var result: Array[int] = []
	for child: Node in parent.get_children():
		result.append(child.get_instance_id())
	return result


static func _find_node_id(
	model: MapReadModel,
	kind: GameEnums.MapNodeKind
) -> int:
	for node: MapNodeState in model.nodes:
		if node != null and node.definition.kind == kind:
			return node.instance_id
	return 0


static func _find_node_id_at_layer(model: MapReadModel, layer_index: int) -> int:
	for node: MapNodeState in model.nodes:
		if node != null and node.layer_index == layer_index:
			return node.instance_id
	return 0

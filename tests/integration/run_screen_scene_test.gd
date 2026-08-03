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
		and not controller.feedback_toast.visible,
		"Settings should be available without a persistent feedback message."
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

class_name MapSystemTest
extends RefCounted


static func run(suite: TestSuite) -> void:
	_test_definition_and_deterministic_generation(suite)
	_test_map_facts_and_read_views(suite)
	_test_encounter_building(suite)
	_test_event_operations_and_conditions(suite)


static func _test_definition_and_deterministic_generation(
	suite: TestSuite
) -> void:
	var definition: MapDefinition = MapTestFactory.create_map(
			MapTestFactory.create_event_node(false),
			3,
			2,
			3
	)
	suite.assert_true(
		DefinitionValidator.new().validate(definition).is_valid(),
		"A complete layered Map definition should validate."
	)
	var service: MapGenerationService = MapGenerationService.new()
	var first: MapGenerationResult = service.generate(
			MapGenerationRequest.create(definition, 7711, 0)
	)
	var second: MapGenerationResult = service.generate(
			MapGenerationRequest.create(definition, 7711, 0)
	)
	suite.assert_true(
		first.succeeded() and second.succeeded(),
		"Valid Map definitions should generate a saved graph."
	)
	var first_nodes: Array[MapNodeState] = first.map_state.get_nodes()
	var second_nodes: Array[MapNodeState] = second.map_state.get_nodes()
	suite.assert_int_equal(
		first_nodes.size(),
		second_nodes.size(),
		"Equivalent Map seeds should create the same node count."
	)
	for index: int in range(first_nodes.size()):
		suite.assert_int_equal(
			first_nodes[index].instance_id,
			second_nodes[index].instance_id,
			"Equivalent Maps should preserve stable node IDs."
		)
		suite.assert_true(
			first_nodes[index].definition
			== second_nodes[index].definition,
			"Equivalent Maps should save the same selected node content."
		)
	var first_connections: Array[MapConnection] = (
		first.map_state.get_connections()
	)
	var second_connections: Array[MapConnection] = (
		second.map_state.get_connections()
	)
	suite.assert_int_equal(
		first_connections.size(),
		second_connections.size(),
		"Equivalent Maps should create the same connection count."
	)
	for index: int in range(first_connections.size()):
		suite.assert_int_equal(
			first_connections[index].from_node_id,
			second_connections[index].from_node_id,
			"Equivalent Maps should preserve each connection source."
		)
		suite.assert_int_equal(
			first_connections[index].to_node_id,
			second_connections[index].to_node_id,
			"Equivalent Maps should preserve each connection target."
		)
		var source: MapNodeState = first.map_state.get_node(
				first_connections[index].from_node_id
		)
		var target: MapNodeState = first.map_state.get_node(
				first_connections[index].to_node_id
		)
		suite.assert_int_equal(
			source.layer_index + 1,
			target.layer_index,
			"Map connections should only advance one layer."
		)
	suite.assert_true(
		not first.map_state.get_reachable_node_ids().is_empty(),
		"A generated Map should expose the first reachable layer."
	)
	var uncovered: MapDefinition = MapTestFactory.create_map(
			MapTestFactory.create_event_node(false),
			2,
			1,
			1
	)
	uncovered.node_pool[0].maximum_layer = 1
	suite.assert_false(
		DefinitionValidator.new().validate(uncovered).is_valid(),
		"Map validation should reject a layer with no eligible node content."
	)
	var insufficient: MapDefinition = MapTestFactory.create_map(
			MapTestFactory.create_event_node(false),
			2,
			1,
			1
	)
	insufficient.node_pool[0].maximum_copies = 1
	suite.assert_false(
		DefinitionValidator.new().validate(insufficient).is_valid(),
		"Map validation should reject copy limits that cannot fill the graph."
	)
	var negative_minimum: MapDefinition = MapTestFactory.create_map(
			MapTestFactory.create_event_node(false)
	)
	negative_minimum.node_pool[0].minimum_copies = -1
	suite.assert_false(
		DefinitionValidator.new().validate(negative_minimum).is_valid(),
		"Map validation should reject negative minimum copy counts."
	)
	var negative_maximum: MapDefinition = MapTestFactory.create_map(
			MapTestFactory.create_event_node(false)
	)
	negative_maximum.node_pool[0].maximum_copies = -1
	suite.assert_false(
		DefinitionValidator.new().validate(negative_maximum).is_valid(),
		"Map validation should reject negative maximum copy counts."
	)
	var constrained: MapDefinition = MapTestFactory.create_map(
			MapTestFactory.create_event_node(false),
			2,
			1,
			1
	)
	var constrained_entry: MapNodePoolEntry = MapNodePoolEntry.new()
	constrained_entry.node_definition = MapTestFactory.create_chest_node()
	constrained_entry.minimum_layer = 1
	constrained_entry.maximum_layer = 1
	constrained_entry.minimum_copies = 1
	constrained_entry.maximum_copies = 1
	constrained.node_pool.append(constrained_entry)
	var all_required_placements_succeeded: bool = (
		DefinitionValidator.new().validate(constrained).is_valid()
	)
	for seed: int in range(50):
		if not service.generate(
				MapGenerationRequest.create(constrained, seed, 0)
		).succeeded():
			all_required_placements_succeeded = false
			break
	suite.assert_true(
		all_required_placements_succeeded,
		"Required nodes should use deterministic matching instead of greedy placement."
	)


static func _test_map_facts_and_read_views(suite: TestSuite) -> void:
	var run_state: RunState = MapTestFactory.create_run(991)
	var flow: MapFlowService = MapFlowService.new()
	var started: MapFlowResult = flow.start_map(
			run_state,
			MapTestFactory.create_map(
					MapTestFactory.create_event_node(false)
			)
	)
	suite.assert_true(started.succeeded(), "A Run should accept one generated Map.")
	var authoritative: MapState = run_state.get_map_state()
	var reachable: int = authoritative.get_reachable_node_ids()[0]
	var view: MapState = run_state.get_map_state()
	view._get_node_mutable(reachable).status = (
			GameEnums.MapNodeStatus.RESOLVED
	)
	suite.assert_true(
		run_state.get_map_state().get_node(reachable).status
		== GameEnums.MapNodeStatus.UNVISITED,
		"Map read views must not mutate authoritative node facts."
	)
	suite.assert_true(
		started.read_model.reachable_node_ids.has(reachable),
		"The read model should compute reachable nodes from saved facts."
	)
	suite.assert_false(
		flow.advance(
				run_state,
				MapAdvanceRequest.create(9999)
		).succeeded(),
		"Unknown nodes must not be entered."
	)
	suite.assert_true(
		run_state.get_map_state().get_active_session() == null,
		"Rejected movement must not create a partial node session."
	)


static func _test_encounter_building(suite: TestSuite) -> void:
	var run_state: RunState = MapTestFactory.create_run(882)
	var definition: EncounterDefinition = MapTestFactory.create_encounter(
			GameEnums.EnemyRank.STANDARD
	)
	var unit_id: int = run_state.get_units()[0].instance_id
	var valid_request: EncounterStartRequest = EncounterStartRequest.new()
	valid_request.player_deployments.append(
			RunUnitDeployment.create(unit_id, Vector2i(0, 0))
	)
	var built: EncounterBuildResult = EncounterBuildService.new().build(
			run_state,
			definition,
			valid_request,
			2
	)
	suite.assert_true(
		built.succeeded(),
		"Encounter building should combine authored and selected deployments."
	)
	suite.assert_int_equal(
		2,
		built.request.floor_number,
		"Encounter building should preserve the selected Map floor."
	)
	suite.assert_int_equal(
		1,
		built.request.enemy_deployments.size(),
		"Encounter definitions should supply Enemy deployments."
	)
	var invalid_request: EncounterStartRequest = EncounterStartRequest.new()
	invalid_request.player_deployments.append(
			RunUnitDeployment.create(unit_id, Vector2i(1, 0))
	)
	suite.assert_false(
		EncounterBuildService.new().build(
				run_state,
				definition,
				invalid_request,
				2
		).succeeded(),
		"Players must deploy only inside authored deployment Cells."
	)
	var wall: TerrainDefinition = load(
			"res://content/terrains/debug_wall.tres"
	) as TerrainDefinition
	var blocked_player: EncounterDefinition = MapTestFactory.create_encounter(
			GameEnums.EnemyRank.STANDARD,
			&"blocked_player"
	)
	var player_wall: BattlefieldTerrainPlacement = (
		BattlefieldTerrainPlacement.new()
	)
	player_wall.coordinate = Vector2i(0, 0)
	player_wall.terrain = wall
	blocked_player.battlefield.terrain_overrides.append(player_wall)
	suite.assert_false(
		DefinitionValidator.new().validate(blocked_player).is_valid(),
		"Authored player deployment Cells must use passable final Terrain."
	)
	suite.assert_false(
		EncounterBuildService.new().build(
				run_state,
				blocked_player,
				valid_request,
				2
		).succeeded(),
		"Encounter building must reject blocked player deployment Cells."
	)
	var blocked_enemy: EncounterDefinition = MapTestFactory.create_encounter(
			GameEnums.EnemyRank.STANDARD,
			&"blocked_enemy"
	)
	var enemy_wall: BattlefieldTerrainPlacement = (
		BattlefieldTerrainPlacement.new()
	)
	enemy_wall.coordinate = Vector2i(4, 0)
	enemy_wall.terrain = wall
	blocked_enemy.battlefield.terrain_overrides.append(enemy_wall)
	suite.assert_false(
		DefinitionValidator.new().validate(blocked_enemy).is_valid(),
		"Authored Enemy spawn Cells must use passable final Terrain."
	)
	suite.assert_false(
		EncounterBuildService.new().build(
				run_state,
				blocked_enemy,
				valid_request,
				2
		).succeeded(),
		"Encounter building must reject blocked Enemy spawn Cells."
	)
	var direct_request: RunBattleStartRequest = RunBattleStartRequest.new()
	direct_request.grid = GridState.create(
			5,
			2,
			load(MapTestFactory.TERRAIN_PATH) as TerrainDefinition
	)
	direct_request.grid.set_terrain(Vector2i(0, 0), wall)
	direct_request.player_deployments.append(
			RunUnitDeployment.create(unit_id, Vector2i(0, 0))
	)
	direct_request.enemy_deployments.append(
			EnemyDeployment.create(
					load(MapTestFactory.ENEMY_PATH) as EnemyDefinition,
					Vector2i(4, 0)
			)
	)
	direct_request.reward_pool = load(
			MapTestFactory.BATTLE_POOL_PATH
	) as RewardPoolDefinition
	suite.assert_false(
		BattleSetupService.new().build(
				run_state,
				direct_request,
				1
		).succeeded(),
		"Generic Battle setup must reject deployment on blocked Terrain."
	)


static func _test_event_operations_and_conditions(
	suite: TestSuite
) -> void:
	var run_state: RunState = MapTestFactory.create_run(773)
	var command_service: RunCommandService = RunCommandService.new()
	var scroll_definition: ScrollDefinition = load(
			"res://content/scrolls/debug_blast_scroll.tres"
	) as ScrollDefinition
	var relic_definition: RelicDefinition = load(
			"res://content/relics/debug_resolute_banner.tres"
	) as RelicDefinition
	command_service.execute(
			run_state,
			GrantScrollCommand.create(scroll_definition, 1)
	)
	command_service.execute(
			run_state,
			GrantRelicCommand.create(relic_definition)
	)
	var request: MapEventResolveRequest = MapEventResolveRequest.new()
	request.unit_instance_id = run_state.get_units()[0].instance_id
	request.scroll_stack_instance_id = run_state.get_scrolls()[0].instance_id
	request.relic_instance_id = run_state.get_relics()[0].instance_id
	var transaction: RunTransaction = RunTransaction.begin(run_state)
	var working: RunState = transaction.working_state
	var operations: Array[MapEventOperationDefinition] = []
	var gold: ChangeGoldMapOperationDefinition = (
		ChangeGoldMapOperationDefinition.new()
	)
	gold.amount = 3
	operations.append(gold)
	var damage: DamageUnitMapOperationDefinition = (
		DamageUnitMapOperationDefinition.new()
	)
	damage.amount = 2
	operations.append(damage)
	var heal: HealUnitMapOperationDefinition = (
		HealUnitMapOperationDefinition.new()
	)
	heal.amount = 1
	operations.append(heal)
	operations.append(ConsumeScrollMapOperationDefinition.new())
	operations.append(RemoveRelicMapOperationDefinition.new())
	var reward: GrantRewardMapOperationDefinition = (
		GrantRewardMapOperationDefinition.new()
	)
	var currency: CurrencyRewardDefinition = CurrencyRewardDefinition.new()
	currency.amount = 4
	reward.payload = currency
	operations.append(reward)
	var operation_service: MapEventOperationService = (
		MapEventOperationService.new()
	)
	for operation: MapEventOperationDefinition in operations:
		suite.assert_true(
			operation_service.execute_in_transaction(
					working,
					operation,
					request
			).succeeded(),
			"Every generic Event operation should use its Run command boundary."
		)
	suite.assert_true(transaction.commit(), "Event operations should commit together.")
	suite.assert_int_equal(
		67,
		run_state.get_gold(),
		"Gold changes and direct currency Rewards should share Run authority."
	)
	suite.assert_int_equal(
		9,
		run_state.get_unit(request.unit_instance_id).current_health,
		"Event damage and healing should update between-Battle health."
	)
	suite.assert_true(
		run_state.get_scrolls().is_empty()
		and run_state.get_relics().is_empty(),
		"Event removal operations should use authoritative inventory commands."
	)
	suite.assert_false(
		operation_service.execute_in_transaction(
				run_state,
				OpenRewardPoolMapOperationDefinition.new(),
				request
		).succeeded(),
		"Reward-pool opening should remain Map Event orchestration work."
	)
	var condition: RunGoldConditionDefinition = RunGoldConditionDefinition.new()
	condition.minimum_gold = 67
	var context: MapEventConditionContext = MapEventConditionContext.create(
			run_state,
			MapNodeState.create(
					1,
					1,
					0,
					MapTestFactory.create_event_node(false)
			),
			MapEventSessionState.new(),
			1
	)
	suite.assert_true(
		condition.evaluate(context).passed(),
		"Map Event Conditions should read Run facts through their own context."
	)
	condition.minimum_gold = 68
	suite.assert_false(
		condition.evaluate(context).passed(),
		"Map Event Conditions should reject unavailable choices."
	)

class_name MapFlowSystemTest
extends RefCounted

const SCROLL_PATH: String = "res://content/scrolls/debug_blast_scroll.tres"


static func run(suite: TestSuite) -> void:
	_test_event_retry_reward_and_boss_victory(suite)
	_test_shop_and_chest_completion(suite)
	_test_map_battle_defeat(suite)
	_test_explicit_abandon_reason(suite)


static func _test_event_retry_reward_and_boss_victory(
	suite: TestSuite
) -> void:
	var run_state: RunState = MapTestFactory.create_run(20260811)
	var command_service: RunCommandService = RunCommandService.new()
	var unit_id: int = run_state.get_units()[0].instance_id
	var scroll: ScrollDefinition = load(SCROLL_PATH) as ScrollDefinition
	command_service.execute(run_state, DamageRunUnitCommand.create(unit_id, 2))
	command_service.execute(run_state, GrantScrollCommand.create(scroll, 2))
	var flow: MapFlowService = MapFlowService.new()
	var map_started: MapFlowResult = flow.start_map(
			run_state,
			MapTestFactory.create_map(MapTestFactory.create_event_node())
	)
	suite.assert_true(map_started.succeeded(), "The v6 Map flow should start.")
	var event_node_id: int = map_started.read_model.reachable_node_ids[0]
	var entered: MapFlowResult = flow.advance(
			run_state,
			MapAdvanceRequest.create(event_node_id)
	)
	suite.assert_true(entered.succeeded(), "A reachable Event should be enterable.")
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.RESOLVING_MAP_NODE,
		"Entering an Event should create a persistent interaction session."
	)
	var selected: MapFlowResult = flow.choose_event_option(
			run_state,
			MapEventChoiceRequest.create(&"aid")
	)
	suite.assert_true(selected.succeeded(), "An available Event choice should plan a result.")
	var planned_id: StringName = run_state.get_map_state(
	).get_active_session().event_session.planned_outcome_id
	var version_before_failure: int = run_state.get_state_version()
	var gold_before_failure: int = run_state.get_gold()
	var invalid_target: MapEventResolveRequest = MapEventResolveRequest.new()
	invalid_target.unit_instance_id = 9999
	var rejected: MapFlowResult = flow.execute_event_result(
			run_state,
			invalid_target
	)
	suite.assert_false(
		rejected.succeeded(),
		"An Event result with an invalid selected target should fail atomically."
	)
	suite.assert_int_equal(
		version_before_failure,
		run_state.get_state_version(),
		"Failed Event execution must not commit a partial transaction."
	)
	suite.assert_int_equal(
		gold_before_failure,
		run_state.get_gold(),
		"Earlier Event operations must roll back when a later one fails."
	)
	suite.assert_true(
		run_state.get_map_state(
		).get_active_session().event_session.planned_outcome_id == planned_id,
		"Retrying an Event must retain the originally sampled outcome."
	)
	var valid_target: MapEventResolveRequest = MapEventResolveRequest.new()
	valid_target.unit_instance_id = unit_id
	var executed: MapFlowResult = flow.execute_event_result(
			run_state,
			valid_target
	)
	suite.assert_true(executed.succeeded(), "The saved Event result should be retryable.")
	suite.assert_int_equal(
		65,
		run_state.get_gold(),
		"Successful Event operations should commit together."
	)
	suite.assert_int_equal(
		9,
		run_state.get_unit(unit_id).current_health,
		"Event target selection should apply to the requested Run Unit."
	)
	var event_offer: RewardOffer = run_state.get_active_offer()
	suite.assert_true(
		event_offer != null
		and run_state.get_phase() == GameEnums.RunPhase.CHOOSING_REWARD,
		"An Event reward should remain associated with its node session."
	)
	suite.assert_false(
		RewardOfferService.new().take_all(
				run_state,
				event_offer.offer_id
		).succeeded(),
		"Standalone Reward entry points must not bypass Map progression."
	)
	suite.assert_true(
		run_state.get_map_state().get_active_session() != null,
		"A rejected Reward bypass must preserve the active Map session."
	)
	var reward_taken: MapFlowResult = flow.take_all_current_offer(
			run_state,
			event_offer.offer_id
	)
	suite.assert_true(reward_taken.succeeded(), "The Event reward should be collectable.")
	suite.assert_int_equal(
		72,
		run_state.get_gold(),
		"Event reward collection should commit before node completion."
	)
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.READY
		and run_state.get_map_state().get_node(event_node_id).status
		== GameEnums.MapNodeStatus.RESOLVED,
		"An Event node should complete only after its reward closes."
	)

	var boss_id: int = run_state.get_map_state().get_reachable_node_ids()[0]
	var boss_entered: MapFlowResult = flow.advance(
			run_state,
			MapAdvanceRequest.create(boss_id)
	)
	suite.assert_true(
		boss_entered.succeeded()
		and run_state.get_phase() == GameEnums.RunPhase.PREPARING_BATTLE,
		"Entering the Boss should wait for player deployment."
	)
	var encounter_request: EncounterStartRequest = EncounterStartRequest.new()
	encounter_request.player_deployments.append(
			RunUnitDeployment.create(unit_id, Vector2i(0, 0))
	)
	var battle_started: MapFlowResult = flow.start_current_battle(
			run_state,
			encounter_request
	)
	suite.assert_true(
		battle_started.succeeded()
		and battle_started.battle != null,
		"The Map encounter should start through the existing Run battle flow."
	)
	var battle: BattleState = battle_started.battle
	var player: UnitState = battle.get_units_for_side(
			GameEnums.BattleSide.PLAYER
	)[0]
	var enemy: UnitState = battle.get_units_for_side(
			GameEnums.BattleSide.ENEMY
	)[0]
	var enemy_cell: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			enemy.instance_id
	)
	var target: TargetSelection = TargetSelection.new()
	target.cells.append(enemy_cell.value)
	for stack: BattleScrollStackState in battle.get_scrolls():
		while (
			stack.quantity > 0
			and battle.phase == GameEnums.BattlePhase.PLAYER_TURN
		):
			var action: ActionExecutionResult = BattleActionService.new().execute(
					battle,
					UseScrollActionRequest.create(
							player.instance_id,
							stack.instance_id,
							target
					)
			)
			if not action.is_successful:
				break
	suite.assert_true(
		battle.phase == GameEnums.BattlePhase.VICTORY,
		"The Boss test encounter should reach a normal Battle victory."
	)
	suite.assert_false(
		RunFlowService.new().resolve_battle(run_state, battle).succeeded(),
		"Standalone Battle resolution must not bypass Map progression."
	)
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.IN_BATTLE,
		"A rejected Battle bypass must preserve the Map Battle session."
	)
	var battle_resolved: MapFlowResult = flow.resolve_current_battle(
			run_state,
			battle
	)
	suite.assert_true(
		battle_resolved.succeeded(),
		"A Map Battle outcome should write back through the v5 transaction."
	)
	var battle_offer: RewardOffer = run_state.get_active_offer()
	suite.assert_true(
		battle_offer != null,
		"Boss rewards should remain pending before Run victory."
	)
	var selected_option: RewardOption
	for option: RewardOption in battle_offer.options:
		if option.payload.kind != GameEnums.RewardKind.HEALING:
			selected_option = option
			break
	suite.assert_true(selected_option != null, "The Boss offer should have a direct reward.")
	var claimed: MapFlowResult = flow.claim_current_offer(
			run_state,
			battle_offer.offer_id,
			selected_option.option_id
	)
	suite.assert_true(claimed.succeeded(), "The Boss reward should resolve atomically.")
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.ENDED
		and run_state.get_end_reason() == GameEnums.RunEndReason.VICTORY,
		"Boss node completion should end the Run with an explicit victory."
	)
	suite.assert_true(
		run_state.get_map_state().get_node(boss_id).status
		== GameEnums.MapNodeStatus.RESOLVED,
		"Boss victory should save the completed Boss node."
	)
	suite.assert_false(
		flow.resolve_current_battle(run_state, battle).succeeded(),
		"A Map Battle result must not be applied twice."
	)


static func _test_shop_and_chest_completion(suite: TestSuite) -> void:
	var shop_run: RunState = MapTestFactory.create_run(303)
	var shop_flow: MapFlowService = MapFlowService.new()
	shop_flow.start_map(
			shop_run,
			MapTestFactory.create_map(MapTestFactory.create_shop_node())
	)
	var shop_id: int = shop_run.get_map_state().get_reachable_node_ids()[0]
	var shop_entered: MapFlowResult = shop_flow.advance(
			shop_run,
			MapAdvanceRequest.create(shop_id)
	)
	suite.assert_true(
		shop_entered.succeeded()
		and shop_run.get_phase() == GameEnums.RunPhase.SHOPPING,
		"A Shop node should open a purchase-any offer."
	)
	var shop_offer: RewardOffer = shop_run.get_active_offer()
	suite.assert_true(
		shop_flow.close_current_shop(
				shop_run,
				shop_offer.offer_id
		).succeeded(),
		"Closing a Shop should complete its node through Map flow."
	)
	suite.assert_true(
		shop_run.get_map_state().get_node(shop_id).status
		== GameEnums.MapNodeStatus.RESOLVED,
		"Shop nodes must save completion after their offer closes."
	)

	var chest_run: RunState = MapTestFactory.create_run(404)
	var chest_flow: MapFlowService = MapFlowService.new()
	chest_flow.start_map(
			chest_run,
			MapTestFactory.create_map(MapTestFactory.create_chest_node())
	)
	var chest_id: int = chest_run.get_map_state().get_reachable_node_ids()[0]
	var chest_entered: MapFlowResult = chest_flow.advance(
			chest_run,
			MapAdvanceRequest.create(chest_id)
	)
	suite.assert_true(
		chest_entered.succeeded()
		and chest_run.get_phase() == GameEnums.RunPhase.CHOOSING_REWARD,
		"A Chest node should open its saved take-all offer."
	)
	var chest_offer: RewardOffer = chest_run.get_active_offer()
	suite.assert_true(
		chest_flow.take_all_current_offer(
				chest_run,
				chest_offer.offer_id
		).succeeded(),
		"Taking a Chest reward should complete the node."
	)
	suite.assert_int_equal(
		71,
		chest_run.get_gold(),
		"Chest rewards should use the common Reward grant path."
	)


static func _test_explicit_abandon_reason(suite: TestSuite) -> void:
	var run_state: RunState = MapTestFactory.create_run(505)
	var flow: MapFlowService = MapFlowService.new()
	flow.start_map(
			run_state,
			MapTestFactory.create_map(MapTestFactory.create_event_node(false))
	)
	suite.assert_true(
		flow.abandon_run(run_state).succeeded(),
		"An active Map Run should support explicit abandonment."
	)
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.ENDED
		and run_state.get_end_reason() == GameEnums.RunEndReason.ABANDONED,
		"Abandonment should be distinguishable from victory and defeat."
	)


static func _test_map_battle_defeat(suite: TestSuite) -> void:
	var run_state: RunState = MapTestFactory.create_run(606)
	var flow: MapFlowService = MapFlowService.new()
	var battle_node: EncounterMapNodeDefinition = (
		MapTestFactory.create_encounter_node(
				GameEnums.MapNodeKind.BATTLE,
				GameEnums.EnemyRank.STANDARD,
				&"test_battle_node"
		)
	)
	flow.start_map(run_state, MapTestFactory.create_map(battle_node))
	var node_id: int = run_state.get_map_state().get_reachable_node_ids()[0]
	suite.assert_true(
		flow.advance(
				run_state,
				MapAdvanceRequest.create(node_id)
		).succeeded(),
		"A standard Map Battle should enter preparation."
	)
	var request: EncounterStartRequest = EncounterStartRequest.new()
	request.player_deployments.append(
			RunUnitDeployment.create(
					run_state.get_units()[0].instance_id,
					Vector2i(0, 0)
			)
	)
	var started: MapFlowResult = flow.start_current_battle(run_state, request)
	suite.assert_true(started.succeeded(), "A standard Map Battle should start.")
	var battle: BattleState = started.battle
	for turn_index: int in range(6):
		if battle.phase == GameEnums.BattlePhase.FAILURE:
			break
		BattleFlowService.new().end_player_turn(battle)
	suite.assert_true(
		battle.phase == GameEnums.BattlePhase.FAILURE,
		"The defeat fixture should reach a terminal Battle failure."
	)
	suite.assert_true(
		flow.resolve_current_battle(run_state, battle).succeeded(),
		"Map Battle failure should write back as a normal terminal result."
	)
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.ENDED
		and run_state.get_end_reason() == GameEnums.RunEndReason.DEFEAT,
		"Map Battle failure should end the Run with explicit defeat."
	)
	var session: MapNodeSessionState = run_state.get_map_state(
	).get_active_session()
	suite.assert_true(
		session != null
		and session.stage == GameEnums.MapSessionStage.FAILED
		and run_state.get_active_offer() == null,
		"Defeat should preserve a failed node fact without opening a Reward."
	)

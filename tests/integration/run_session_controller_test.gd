class_name RunSessionControllerTest
extends RefCounted

const HERO_PATH: String = "res://content/heroes/v8_banner_captain.tres"
const MAP_PATH: String = "res://content/maps/v8_first_route.tres"
const SCROLL_PATH: String = "res://content/scrolls/debug_blast_scroll.tres"


static func run(suite: TestSuite) -> void:
	_test_complete_route_and_authoritative_routing(suite)
	_test_defeat_routes_directly_to_result(suite)


static func _test_complete_route_and_authoritative_routing(
	suite: TestSuite
) -> void:
	var hero: HeroDefinition = load(HERO_PATH) as HeroDefinition
	var map_definition: MapDefinition = load(MAP_PATH) as MapDefinition
	var scroll: ScrollDefinition = load(SCROLL_PATH) as ScrollDefinition
	suite.assert_true(
		DefinitionValidator.new().validate(map_definition).is_valid(),
		"The authored v8 route should pass Definition validation."
	)
	var controller: RunSessionController = RunSessionController.new()
	var setup: RunSetup = RunSetup.create(hero, 20260802, 4, 3, 40)
	var started: RunSessionResult = controller.start_new_run(
		setup,
		map_definition,
		[scroll]
	)
	suite.assert_true(started.succeeded, "The v8 Run session should start.")
	suite.assert_true(
		controller.get_route() == RunSessionRoute.Value.MAP,
		"A new Run session should derive its first route from READY."
	)
	var first_snapshot: RunSessionSnapshot = controller.get_snapshot()
	suite.assert_true(
		first_snapshot != null
		and first_snapshot.summary != null
		and first_snapshot.map != null
		and first_snapshot.inventory != null,
		"The v8 UI should receive split read models from one detached snapshot."
	)
	suite.assert_int_equal(
		2,
		first_snapshot.inventory.units.size(),
		"The authored hero should provide the first playable team."
	)

	var visited_battle: bool = false
	var visited_reward: bool = false
	var visited_shop: bool = false
	var visited_event: bool = false
	var safety_limit: int = 40
	while (
		controller.get_route() != RunSessionRoute.Value.RESULT
		and safety_limit > 0
	):
		safety_limit -= 1
		var snapshot: RunSessionSnapshot = controller.get_snapshot()
		match snapshot.route:
			RunSessionRoute.Value.MAP:
				var reachable: Array[int] = snapshot.map.reachable_node_ids
				suite.assert_true(
					not reachable.is_empty(),
					"Each unfinished v8 Map layer should expose a reachable node."
				)
				if reachable.is_empty():
					break
				suite.assert_true(
					controller.advance_to_node(reachable[0]).succeeded,
					"The session should advance only through MapFlowService."
				)
			RunSessionRoute.Value.DEPLOYMENT:
				var deployments: Array[RunUnitDeployment] = (
					_create_deployments(snapshot.deployment)
				)
				suite.assert_true(
					controller.start_current_battle(deployments).succeeded,
					"The Deployment route should build a Battle through Map flow."
				)
			RunSessionRoute.Value.BATTLE:
				if not visited_battle:
					suite.assert_int_equal(
						1,
						snapshot.battle.relics.size(),
						"The Battle read model should display carried Relics."
					)
					suite.assert_int_equal(
						1,
						snapshot.battle.scrolls.size(),
						"The Battle read model should display usable Scroll stacks."
					)
				visited_battle = true
				var battle: BattleState = controller.get_current_battle_for_host()
				suite.assert_true(
					battle != null,
					"The Run session should own the Battle handed to the Battle UI."
				)
				if battle == null:
					break
				suite.assert_false(
					controller.submit_current_battle_result().succeeded,
					"A nonterminal Battle cannot be submitted by the UI."
				)
				battle.phase = GameEnums.BattlePhase.VICTORY
				suite.assert_true(
					controller.submit_current_battle_result().succeeded,
					"Continue should submit the terminal Battle exactly once."
				)
			RunSessionRoute.Value.REWARD:
				visited_reward = true
				var reward: RewardReadModel = snapshot.reward
				if reward.rule == GameEnums.RewardOfferRule.PICK_ANY:
					suite.assert_true(
						controller.finish_offer(reward.offer_id).succeeded,
						"PICK_ANY should support explicit completion after skips."
					)
				elif reward.rule == GameEnums.RewardOfferRule.TAKE_ALL:
					suite.assert_true(
						controller.take_all_offer(reward.offer_id).succeeded,
						"TAKE_ALL should complete its owning Map node."
					)
				else:
					var option: RewardOptionReadModel = reward.options[0]
					suite.assert_true(
						controller.claim_offer_option(
							reward.offer_id,
							option.option_id
						).succeeded,
						"A single-choice reward should be claimable."
					)
			RunSessionRoute.Value.SHOP:
				visited_shop = true
				suite.assert_true(
					controller.close_shop(snapshot.reward.offer_id).succeeded,
					"Leaving the Shop should complete its Map node."
				)
			RunSessionRoute.Value.EVENT:
				visited_event = true
				if (
					snapshot.event.stage
					== GameEnums.MapSessionStage.EVENT_CHOICE
				):
					var choice: EventChoiceReadModel = _first_available_choice(
						snapshot.event
					)
					suite.assert_true(
						choice != null
						and controller.choose_event(choice.choice_id).succeeded,
						"Events should save the selected outcome before execution."
					)
				else:
					var request: MapEventResolveRequest = (
						MapEventResolveRequest.new()
					)
					request.unit_instance_id = (
						snapshot.inventory.units[0].instance_id
					)
					suite.assert_true(
						controller.execute_event(request).succeeded,
						"The planned Event result should execute transactionally."
					)
			_:
				suite.assert_true(false, "The v8 route entered an unsupported state.")
				break

	suite.assert_true(safety_limit > 0, "The authored v8 route should terminate.")
	suite.assert_true(
		visited_battle and visited_reward and visited_shop and visited_event,
		"The v8 loop should traverse Battle, Reward, Shop, and Event routes."
	)
	var final_snapshot: RunSessionSnapshot = controller.get_snapshot()
	suite.assert_true(
		final_snapshot.route == RunSessionRoute.Value.RESULT
		and final_snapshot.summary.end_reason == GameEnums.RunEndReason.VICTORY,
		"Boss reward completion should end the complete v8 Run in victory."
	)


static func _create_deployments(
	model: DeploymentReadModel
) -> Array[RunUnitDeployment]:
	var cells: Array[Vector2i] = []
	for cell: DeploymentCellReadModel in model.cells:
		if cell.allows_player_deployment:
			cells.append(cell.coordinate)
	var result: Array[RunUnitDeployment] = []
	var count: int = mini(cells.size(), model.available_units.size())
	for index: int in range(count):
		result.append(RunUnitDeployment.create(
			model.available_units[index].instance_id,
			cells[index]
		))
	return result


static func _first_available_choice(model: EventReadModel) -> EventChoiceReadModel:
	for choice: EventChoiceReadModel in model.choices:
		if choice.available:
			return choice
	return null


static func _test_defeat_routes_directly_to_result(suite: TestSuite) -> void:
	var controller: RunSessionController = RunSessionController.new()
	var hero: HeroDefinition = load(HERO_PATH) as HeroDefinition
	var map_definition: MapDefinition = load(MAP_PATH) as MapDefinition
	var started: RunSessionResult = controller.start_new_run(
		RunSetup.create(hero, 9001, 4, 3, 0),
		map_definition
	)
	suite.assert_true(started.succeeded, "The defeat routing fixture should start.")
	var map_snapshot: RunSessionSnapshot = controller.get_snapshot()
	controller.advance_to_node(map_snapshot.map.reachable_node_ids[0])
	var deployment_snapshot: RunSessionSnapshot = controller.get_snapshot()
	controller.start_current_battle(
		_create_deployments(deployment_snapshot.deployment)
	)
	var battle: BattleState = controller.get_current_battle_for_host()
	battle.phase = GameEnums.BattlePhase.FAILURE
	suite.assert_true(
		controller.submit_current_battle_result().succeeded,
		"A terminal failure should submit through the same Continue boundary."
	)
	var result: RunSessionSnapshot = controller.get_snapshot()
	suite.assert_true(
		result.route == RunSessionRoute.Value.RESULT
		and result.summary.end_reason == GameEnums.RunEndReason.DEFEAT,
		"A defeated Battle should route directly to the explicit Run result."
	)

class_name RunFlowSystemTest
extends RefCounted

const HERO_PATH: String = "res://content/heroes/debug_run_hero.tres"
const SCROLL_PATH: String = "res://content/scrolls/debug_blast_scroll.tres"
const TERRAIN_PATH: String = "res://content/terrains/debug_ground.tres"
const ENEMY_PATH: String = "res://content/enemies/debug_archer.tres"
const BATTLE_POOL_PATH: String = (
		"res://content/rewards/debug_battle_reward_pool.tres"
)
const SHOP_POOL_PATH: String = (
		"res://content/rewards/debug_shop_reward_pool.tres"
)


static func run(suite: TestSuite) -> void:
	_test_complete_cross_battle_flow(suite)
	_test_victory_without_eligible_reward_completes(suite)
	_test_failure_does_not_generate_reward(suite)
	_test_relic_trigger_failure_rolls_back_action(suite)


static func _test_complete_cross_battle_flow(suite: TestSuite) -> void:
	var run_state: RunState = _create_run()
	var command_service: RunCommandService = RunCommandService.new()
	var scroll: ScrollDefinition = load(SCROLL_PATH) as ScrollDefinition
	command_service.execute(
			run_state,
			GrantScrollCommand.create(scroll, 1)
	)
	var original_unit: RunUnitState = run_state.get_units()[0]
	var flow_service: RunFlowService = RunFlowService.new()
	var start: RunFlowResult = flow_service.start_battle(
			run_state,
			_create_battle_request(run_state)
	)
	suite.assert_true(start.succeeded(), "Run flow should create a started Battle.")
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.IN_BATTLE,
		"Starting a Battle should move the Run into its battle phase."
	)
	suite.assert_int_equal(
			1,
			run_state.total_scroll_quantity(scroll),
			"Battle setup must not mutate Run Scroll inventory."
	)

	var battle: BattleState = start.battle
	var enemy_turn: BattleFlowResult = BattleFlowService.new().end_player_turn(
			battle
	)
	suite.assert_true(enemy_turn.succeeded, "Published enemy Intent should execute.")
	var battle_player: UnitState = battle.get_units_for_side(
			GameEnums.BattleSide.PLAYER
	)[0]
	suite.assert_int_equal(
			8,
			battle_player.current_health,
			"The first enemy action should damage the Battle copy."
	)
	suite.assert_int_equal(
			10,
			run_state.get_unit(original_unit.instance_id).current_health,
			"Battle damage must not directly mutate Run Unit health."
	)

	var enemy: UnitState = battle.get_units_for_side(
			GameEnums.BattleSide.ENEMY
	)[0]
	var enemy_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			enemy.instance_id
	)
	var selection: TargetSelection = TargetSelection.new()
	selection.cells.append(enemy_position.value)
	var scroll_action: ActionExecutionResult = BattleActionService.new().execute(
			battle,
			UseScrollActionRequest.create(
					battle_player.instance_id,
					battle.get_scrolls()[0].instance_id,
					selection
			)
	)
	suite.assert_true(
		scroll_action.is_successful,
		"Scrolls should execute through the Battle action pipeline."
	)
	suite.assert_true(
		battle.phase == GameEnums.BattlePhase.VICTORY,
		"Defeating the final enemy with a Scroll should win the Battle."
	)
	var resolution: RunFlowResult = flow_service.resolve_battle(
			run_state,
			battle
	)
	suite.assert_true(
		resolution.succeeded(),
		"Terminal Battle results should write back atomically."
	)
	suite.assert_int_equal(
			8,
			run_state.get_unit(original_unit.instance_id).current_health,
			"Battle outcome should preserve remaining Unit health."
	)
	suite.assert_int_equal(
			0,
			run_state.total_scroll_quantity(scroll),
			"Battle outcome should write back consumed Scrolls."
	)
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.CHOOSING_REWARD,
		"Victory should open a saved reward offer."
	)
	var repeated: RunFlowResult = flow_service.resolve_battle(run_state, battle)
	suite.assert_false(
		repeated.succeeded(),
		"The same Battle outcome must not be applied twice."
	)
	suite.assert_int_equal(
			8,
			run_state.get_unit(original_unit.instance_id).current_health,
			"Rejected duplicate outcomes must preserve Run health."
	)

	var reward_offer: RewardOffer = run_state.get_active_offer()
	var art_option: RewardOption = _find_option(
			reward_offer,
			GameEnums.RewardKind.ART
	)
	suite.assert_true(art_option != null, "Battle rewards should include the Art.")
	var reward_claim: RunCommandResult = RewardOfferService.new().claim_option(
			run_state,
			reward_offer.offer_id,
			art_option.option_id
	)
	suite.assert_true(reward_claim.succeeded(), "The selected Art should be granted.")
	var install: RunCommandResult = command_service.execute(
			run_state,
			InstallArtCommand.create(
					original_unit.instance_id,
					reward_claim.art_instance_id,
					1
			)
	)
	suite.assert_true(install.succeeded(), "The rewarded Art should install.")

	var shop_result: RunFlowResult = flow_service.open_shop(
			run_state,
			load(SHOP_POOL_PATH) as RewardPoolDefinition,
			1
	)
	suite.assert_true(shop_result.succeeded(), "Run flow should open a saved shop.")
	var shop: RewardOffer = run_state.get_active_offer()
	for option: RewardOption in shop.options:
		suite.assert_true(
			RewardOfferService.new().claim_option(
					run_state,
					shop.offer_id,
					option.option_id
			).succeeded(),
			"Each affordable shop option should purchase atomically."
		)
	suite.assert_true(
		RewardOfferService.new().close_offer(
				run_state,
				shop.offer_id
		).succeeded(),
		"Purchase-any offers should close explicitly."
	)
	suite.assert_int_equal(
			2,
			run_state.get_units().size(),
			"Recruitment rewards should add a new Run Unit."
	)
	suite.assert_int_equal(
			1,
			run_state.get_relics().size(),
			"Relic purchases should add a runtime Relic instance."
	)

	var second_start: RunFlowResult = flow_service.start_battle(
			run_state,
			_create_battle_request(run_state)
	)
	suite.assert_true(
		second_start.succeeded(),
		"The updated build should enter the next Battle."
	)
	var second_battle: BattleState = second_start.battle
	suite.assert_int_equal(
			2,
			second_battle.get_units_for_side(
					GameEnums.BattleSide.PLAYER
			).size(),
			"All selected Run Units should be copied into the second Battle."
	)
	suite.assert_int_equal(
			1,
			second_battle.get_relics().size(),
			"Owned Relics should register as Battle trigger sources."
	)
	BattleFlowService.new().end_player_turn(second_battle)
	var total_shield: int = 0
	for player: UnitState in second_battle.get_units_for_side(
		GameEnums.BattleSide.PLAYER
	):
		total_shield += player.current_shield
	suite.assert_int_equal(
			2,
			total_shield,
			"The purchased Relic should react to player damage."
	)

	var original_battle_id: int = 0
	for battle_unit_id: int in second_battle.get_run_participant_battle_ids():
		if second_battle.get_run_unit_id(battle_unit_id) == original_unit.instance_id:
			original_battle_id = battle_unit_id
	var second_enemy: UnitState = second_battle.get_units_for_side(
			GameEnums.BattleSide.ENEMY
	)[0]
	var second_enemy_position: GridCoordinate = (
		second_battle.grid.find_occupant(
				GameEnums.GridOccupantKind.UNIT,
				second_enemy.instance_id
		)
	)
	var art_selection: TargetSelection = TargetSelection.new()
	art_selection.cells.append(second_enemy_position.value)
	var art_action: ActionExecutionResult = BattleActionService.new().execute(
			second_battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					original_battle_id,
					1,
					art_selection
			)
	)
	suite.assert_true(
		art_action.is_successful,
		"The rewarded Art should execute in the second Battle."
	)
	suite.assert_true(
		second_battle.phase == GameEnums.BattlePhase.VICTORY,
		"The carried build should be able to complete the second Battle."
	)


static func _test_failure_does_not_generate_reward(
		suite: TestSuite
) -> void:
	var run_state: RunState = _create_run()
	var flow_service: RunFlowService = RunFlowService.new()
	var start: RunFlowResult = flow_service.start_battle(
			run_state,
			_create_battle_request(run_state)
	)
	var battle: BattleState = start.battle
	for turn_index: int in range(6):
		if battle.phase == GameEnums.BattlePhase.FAILURE:
			break
		BattleFlowService.new().end_player_turn(battle)
	suite.assert_true(
		battle.phase == GameEnums.BattlePhase.FAILURE,
		"Repeated enemy Intents should eventually defeat the Run Unit."
	)
	var resolution: RunFlowResult = flow_service.resolve_battle(
			run_state,
			battle
	)
	suite.assert_true(resolution.succeeded(), "Failure outcomes should write back.")
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.ENDED,
		"Battle failure should end the current Run."
	)
	suite.assert_true(
			run_state.get_active_offer() == null,
			"Battle failure must not generate a victory reward."
	)


static func _test_victory_without_eligible_reward_completes(
		suite: TestSuite
) -> void:
	var run_state: RunState = RunState.create_from_setup(
			RunSetup.create(
					load(HERO_PATH) as HeroDefinition,
					20260803,
					1,
					3,
					0
			)
	)
	var scroll_definition: ScrollDefinition = load(
			SCROLL_PATH
	) as ScrollDefinition
	RunCommandService.new().execute(
			run_state,
			GrantScrollCommand.create(scroll_definition, 1)
	)
	var unit_payload: UnitRewardDefinition = UnitRewardDefinition.new()
	unit_payload.unit_definition = load(
			"res://content/units/debug_run_recruit.tres"
	) as UnitDefinition
	var entry: RewardEntryDefinition = RewardEntryDefinition.new()
	entry.payload = unit_payload
	entry.allow_duplicate = true
	var pool: RewardPoolDefinition = RewardPoolDefinition.new()
	pool.content_id = &"full_team_battle_reward"
	pool.offer_rule = GameEnums.RewardOfferRule.PICK_ONE
	pool.option_count = 1
	pool.entries.append(entry)
	suite.assert_true(
			DefinitionValidator.new().validate(pool).is_valid(),
			"The unavailable battle pool should remain definition-valid."
	)

	var request: RunBattleStartRequest = _create_battle_request(run_state)
	request.reward_pool = pool
	var flow_service: RunFlowService = RunFlowService.new()
	var start: RunFlowResult = flow_service.start_battle(run_state, request)
	suite.assert_true(
			start.succeeded(),
			"A dynamically unavailable reward must not block Battle start."
	)
	var battle: BattleState = start.battle
	var player: UnitState = battle.get_units_for_side(
			GameEnums.BattleSide.PLAYER
	)[0]
	var enemy: UnitState = battle.get_units_for_side(
			GameEnums.BattleSide.ENEMY
	)[0]
	var enemy_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			enemy.instance_id
	)
	var selection: TargetSelection = TargetSelection.new()
	selection.cells.append(enemy_position.value)
	var action: ActionExecutionResult = BattleActionService.new().execute(
			battle,
			UseScrollActionRequest.create(
					player.instance_id,
					battle.get_scrolls()[0].instance_id,
					selection
			)
	)
	suite.assert_true(
			action.is_successful
			and battle.phase == GameEnums.BattlePhase.VICTORY,
			"The test Battle should reach victory before Run resolution."
	)

	var resolution: RunFlowResult = flow_service.resolve_battle(
			run_state,
			battle
	)
	suite.assert_true(
			resolution.succeeded(),
			"Victory must commit even when no reward remains eligible."
	)
	suite.assert_true(
			resolution.offer == null
			and run_state.get_active_offer() == null,
			"An empty reward result should not create an unusable offer."
	)
	suite.assert_true(
			run_state.get_phase() == GameEnums.RunPhase.READY,
			"A rewardless victory should return the Run to ready."
	)
	suite.assert_true(
			run_state.get_active_battle_session() == null,
			"A rewardless victory must still clear the Battle session."
	)
	suite.assert_int_equal(
			0,
			run_state.total_scroll_quantity(scroll_definition),
			"A rewardless victory must still write back Scroll consumption."
	)
	suite.assert_false(
			flow_service.resolve_battle(run_state, battle).succeeded(),
			"A rewardless victory outcome must still be one-time."
	)


static func _test_relic_trigger_failure_rolls_back_action(
		suite: TestSuite
) -> void:
	var run_state: RunState = _create_run()
	var relic: RelicDefinition = load(
			"res://content/relics/debug_resolute_banner.tres"
	) as RelicDefinition
	RunCommandService.new().execute(
			run_state,
			GrantRelicCommand.create(relic)
	)
	var start: RunFlowResult = RunFlowService.new().start_battle(
			run_state,
			_create_battle_request(run_state)
	)
	var battle: BattleState = start.battle
	var standard_service: BattleActionService = BattleActionService.new()
	standard_service.execute(
			battle,
			EndTurnActionRequest.create(GameEnums.BattleSide.PLAYER)
	)
	var player: UnitState = battle.get_units_for_side(
			GameEnums.BattleSide.PLAYER
	)[0]
	var enemy: UnitState = battle.get_units_for_side(
			GameEnums.BattleSide.ENEMY
	)[0]
	var initial_health: int = player.current_health
	var initial_shield: int = player.current_shield
	var selection: TargetSelection = TargetSelection.new()
	selection.unit_instance_ids.append(player.instance_id)
	var failing_service: BattleActionService = BattleActionService.new(
			GridPathfinder.new(),
			BattleTurnService.new(),
			FailingRelicEventProcessor.new()
	)
	var result: ActionExecutionResult = failing_service.execute(
			battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.ENEMY,
					enemy.instance_id,
					0,
					selection
			)
	)
	suite.assert_false(
		result.is_successful,
		"An internal failure after Relic processing should reject the action."
	)
	suite.assert_int_equal(
		initial_health,
		player.current_health,
		"Failed Relic trigger chains should roll back health damage."
	)
	suite.assert_int_equal(
		initial_shield,
		player.current_shield,
		"Failed Relic trigger chains should roll back granted Shield."
	)


static func _create_run() -> RunState:
	return RunState.create_from_setup(
			RunSetup.create(
					load(HERO_PATH) as HeroDefinition,
					20260801,
					4,
					3,
					60
			)
	)


static func _create_battle_request(
		run_state: RunState
) -> RunBattleStartRequest:
	var request: RunBattleStartRequest = RunBattleStartRequest.new()
	request.grid = GridState.create(
			5,
			2,
			load(TERRAIN_PATH) as TerrainDefinition
	)
	var row: int = 0
	for unit: RunUnitState in run_state.get_units():
		if not unit.is_defeated():
			request.player_deployments.append(
					RunUnitDeployment.create(
							unit.instance_id,
							Vector2i(0, row)
					)
			)
			row += 1
	request.enemy_deployments.append(
			EnemyDeployment.create(
					load(ENEMY_PATH) as EnemyDefinition,
					Vector2i(4, 0)
			)
	)
	request.reward_pool = load(BATTLE_POOL_PATH) as RewardPoolDefinition
	return request


static func _find_option(
		offer: RewardOffer,
		kind: GameEnums.RewardKind
) -> RewardOption:
	for option: RewardOption in offer.options:
		if option.payload != null and option.payload.kind == kind:
			return option
	return null

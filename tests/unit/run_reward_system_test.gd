class_name RunRewardSystemTest
extends RefCounted

const HERO_PATH: String = "res://content/heroes/debug_run_hero.tres"
const ART_PATH: String = "res://content/arts/debug_run_strike.tres"
const SCROLL_PATH: String = "res://content/scrolls/debug_blast_scroll.tres"
const BATTLE_POOL_PATH: String = (
		"res://content/rewards/debug_battle_reward_pool.tres"
)
const SHOP_POOL_PATH: String = (
		"res://content/rewards/debug_shop_reward_pool.tres"
)


static func run(suite: TestSuite) -> void:
	_test_run_commands_are_atomic(suite)
	_test_reward_generation_is_deterministic(suite)
	_test_failed_purchase_preserves_offer(suite)
	_test_team_capacity_failure_preserves_purchase(suite)
	_test_reward_definitions_validate(suite)


static func _test_run_commands_are_atomic(suite: TestSuite) -> void:
	var run_state: RunState = _create_run(60)
	var service: RunCommandService = RunCommandService.new()
	suite.assert_true(run_state != null, "Run setup should create a Run state.")
	suite.assert_int_equal(
			1,
			run_state.get_arts().size(),
			"Default Arts should become owned runtime Art instances."
	)
	var unit: RunUnitState = run_state.get_units()[0]
	suite.assert_true(
			unit.installed_art_instance_ids[0] > 0,
			"Default Art slots should store runtime Art instance IDs."
	)

	var art_definition: ArtDefinition = load(ART_PATH) as ArtDefinition
	var grant_art: RunCommandResult = service.execute(
			run_state,
			GrantArtCommand.create(art_definition)
	)
	suite.assert_true(grant_art.succeeded(), "Owned Arts should be grantable.")
	var install: RunCommandResult = service.execute(
			run_state,
			InstallArtCommand.create(
					unit.instance_id,
					grant_art.art_instance_id,
					1
			)
	)
	suite.assert_true(install.succeeded(), "Compatible Arts should install.")
	var upgrade: RunCommandResult = service.execute(
			run_state,
			UpgradeArtCommand.create(grant_art.art_instance_id)
	)
	suite.assert_true(upgrade.succeeded(), "Installed Arts should upgrade atomically.")
	suite.assert_true(
			run_state.get_art(grant_art.art_instance_id).definition.content_id
			== &"debug_run_strike_upgraded",
			"Art upgrades should replace only the selected runtime instance."
	)

	var scroll: ScrollDefinition = load(SCROLL_PATH) as ScrollDefinition
	suite.assert_true(
			service.execute(
					run_state,
					GrantScrollCommand.create(scroll, 5)
			).succeeded(),
			"Scroll grants should fill existing and new stacks."
	)
	var quantity_before: int = run_state.total_scroll_quantity(scroll)
	var rejected: RunCommandResult = service.execute(
			run_state,
			GrantScrollCommand.create(scroll, 2)
	)
	suite.assert_false(
			rejected.succeeded(),
			"Scroll grants exceeding total capacity should fail."
	)
	suite.assert_int_equal(
			quantity_before,
			run_state.total_scroll_quantity(scroll),
			"Rejected Scroll grants must not add a partial quantity."
	)

	var first: RunTransaction = RunTransaction.begin(run_state)
	var second: RunTransaction = RunTransaction.begin(run_state)
	service.execute_in_transaction(
			first.working_state,
			ChangeGoldCommand.create(1)
	)
	service.execute_in_transaction(
			second.working_state,
			ChangeGoldCommand.create(2)
	)
	suite.assert_true(first.commit(), "The first Run transaction should commit.")
	suite.assert_false(
			second.commit(),
			"A stale Run transaction should not overwrite newer state."
	)
	suite.assert_int_equal(
			61,
			run_state.get_gold(),
			"Optimistic transaction rejection should preserve committed Gold."
	)


static func _test_reward_generation_is_deterministic(
		suite: TestSuite
) -> void:
	var first: RunState = _create_run(60)
	var second: RunState = _create_run(60)
	var pool: RewardPoolDefinition = load(SHOP_POOL_PATH) as RewardPoolDefinition
	var flow: RunFlowService = RunFlowService.new()
	var first_result: RunFlowResult = flow.open_shop(first, pool, 1)
	var second_result: RunFlowResult = flow.open_shop(second, pool, 1)
	suite.assert_true(
		first_result.succeeded() and second_result.succeeded(),
		"Equivalent Runs should generate shop offers."
	)
	var first_offer: RewardOffer = first.get_active_offer()
	var second_offer: RewardOffer = second.get_active_offer()
	var repeated_view: RewardOffer = first.get_active_offer()
	suite.assert_int_equal(
			first_offer.offer_id,
			repeated_view.offer_id,
			"Reading an active offer again should not regenerate it."
	)
	repeated_view.options[0].status = GameEnums.RewardOptionStatus.SOLD
	suite.assert_true(
			first.get_active_offer().options[0].status
			== GameEnums.RewardOptionStatus.AVAILABLE,
			"Offer views should not mutate the authoritative saved offer."
	)
	suite.assert_int_equal(
			first_offer.options.size(),
			second_offer.options.size(),
			"Equivalent offers should contain the same option count."
	)
	for index: int in range(first_offer.options.size()):
		suite.assert_true(
			_payload_key(first_offer.options[index].payload)
			== _payload_key(second_offer.options[index].payload),
			"Equal seeds and Run state should produce the same option order."
		)


static func _test_failed_purchase_preserves_offer(suite: TestSuite) -> void:
	var run_state: RunState = _create_run(0)
	var pool: RewardPoolDefinition = load(SHOP_POOL_PATH) as RewardPoolDefinition
	var flow_result: RunFlowResult = RunFlowService.new().open_shop(
			run_state,
			pool,
			1
	)
	suite.assert_true(flow_result.succeeded(), "A zero-Gold Run may inspect a shop.")
	var offer: RewardOffer = run_state.get_active_offer()
	var option: RewardOption = offer.options[0]
	var result: RunCommandResult = RewardOfferService.new().claim_option(
			run_state,
			offer.offer_id,
			option.option_id
	)
	suite.assert_true(
		result.code == GameEnums.RunCommandCode.INSUFFICIENT_GOLD,
		"Unaffordable purchases should report insufficient Gold."
	)
	suite.assert_int_equal(
			0,
			run_state.get_gold(),
			"Failed purchases should not change Gold."
	)
	suite.assert_true(
			run_state.get_active_offer().get_option(option.option_id).status
			== GameEnums.RewardOptionStatus.AVAILABLE,
			"Failed purchases should keep the displayed option available."
	)


static func _test_team_capacity_failure_preserves_purchase(
		suite: TestSuite
) -> void:
	var run_state: RunState = RunState.create_from_setup(
			RunSetup.create(
					load(HERO_PATH) as HeroDefinition,
					20260802,
					2,
					3,
					100
			)
	)
	var pool: RewardPoolDefinition = RewardPoolDefinition.new()
	pool.content_id = &"capacity_purchase_pool"
	pool.offer_rule = GameEnums.RewardOfferRule.PURCHASE_ANY
	pool.option_count = 2
	var definitions: Array[UnitDefinition] = [
		load("res://content/units/debug_run_recruit.tres") as UnitDefinition,
		load("res://content/units/debug_raider.tres") as UnitDefinition,
	]
	for definition: UnitDefinition in definitions:
		var payload: UnitRewardDefinition = UnitRewardDefinition.new()
		payload.unit_definition = definition
		var entry: RewardEntryDefinition = RewardEntryDefinition.new()
		entry.payload = payload
		entry.allow_duplicate = true
		entry.price = 10
		pool.entries.append(entry)
	var opening: RunFlowResult = RunFlowService.new().open_shop(
			run_state,
			pool,
			1
	)
	suite.assert_true(
			opening.succeeded(),
			"Two initially legal recruits should appear in one shop offer."
	)
	var offer: RewardOffer = run_state.get_active_offer()
	var service: RewardOfferService = RewardOfferService.new()
	suite.assert_true(
			service.claim_option(
					run_state,
					offer.offer_id,
					offer.options[0].option_id
			).succeeded(),
			"The first recruit should fill the final team slot."
	)
	var gold_before_failure: int = run_state.get_gold()
	var rejected: RunCommandResult = service.claim_option(
			run_state,
			offer.offer_id,
			offer.options[1].option_id
	)
	suite.assert_true(
			rejected.code == GameEnums.RunCommandCode.TEAM_FULL,
			"A later recruit should revalidate current team capacity."
	)
	suite.assert_int_equal(
			gold_before_failure,
			run_state.get_gold(),
			"A team-full purchase failure should not spend Gold."
	)
	suite.assert_true(
			run_state.get_active_offer().options[1].status
			== GameEnums.RewardOptionStatus.AVAILABLE,
			"A team-full purchase failure should preserve option availability."
	)


static func _test_reward_definitions_validate(suite: TestSuite) -> void:
	var validator: DefinitionValidator = DefinitionValidator.new()
	suite.assert_true(
		validator.validate(
				load(BATTLE_POOL_PATH) as RewardPoolDefinition
		).is_valid(),
		"Battle reward content should pass Definition validation."
	)
	suite.assert_true(
		validator.validate(
				load(SHOP_POOL_PATH) as RewardPoolDefinition
		).is_valid(),
		"Shop reward content should pass Definition validation."
	)


static func _create_run(gold: int) -> RunState:
	return RunState.create_from_setup(
			RunSetup.create(
					load(HERO_PATH) as HeroDefinition,
					20260801,
					4,
					3,
					gold
			)
	)


static func _payload_key(payload: RewardPayloadDefinition) -> String:
	if payload is RelicRewardDefinition:
		return String(
				(payload as RelicRewardDefinition).relic_definition.content_id
		)
	if payload is UnitRewardDefinition:
		return String(
				(payload as UnitRewardDefinition).unit_definition.content_id
		)
	return str(payload.kind)

class_name RunFlowService
extends RefCounted

var _setup_service: BattleSetupService
var _setup_factory: BattleSetupFactory
var _outcome_service: BattleOutcomeService
var _outcome_applier: RunOutcomeApplier
var _reward_generation_service: RewardGenerationService


func _init(
		setup_service: BattleSetupService = null,
		setup_factory: BattleSetupFactory = null,
		outcome_service: BattleOutcomeService = null,
		outcome_applier: RunOutcomeApplier = null,
		reward_generation_service: RewardGenerationService = null
) -> void:
	_setup_service = setup_service
	if _setup_service == null:
		_setup_service = BattleSetupService.new()
	_setup_factory = setup_factory
	if _setup_factory == null:
		_setup_factory = BattleSetupFactory.new()
	_outcome_service = outcome_service
	if _outcome_service == null:
		_outcome_service = BattleOutcomeService.new()
	_outcome_applier = outcome_applier
	if _outcome_applier == null:
		_outcome_applier = RunOutcomeApplier.new()
	_reward_generation_service = reward_generation_service
	if _reward_generation_service == null:
		_reward_generation_service = RewardGenerationService.new()


func start_battle(
		run: RunState,
		request: RunBattleStartRequest
) -> RunFlowResult:
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return RunFlowResult.failure(GameEnums.RunCommandCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	if (
		request == null
		or request.reward_pool == null
		or not DefinitionValidator.new().validate(
				request.reward_pool
		).is_valid()
		or request.reward_pool.offer_rule
		!= GameEnums.RewardOfferRule.PICK_ONE
	):
		return RunFlowResult.failure(
				GameEnums.RunCommandCode.INVALID_TARGET
		)
	var session_id: int = working._allocate_battle_session_id()
	var setup_result: BattleSetupResult = _setup_service.build(
			working,
			request,
			session_id
	)
	if not setup_result.succeeded():
		return RunFlowResult.failure(setup_result.code)
	var battle_start: BattleStartResult = (
		_setup_factory.create_started_battle(setup_result.setup)
	)
	if not battle_start.succeeded():
		return RunFlowResult.failure(battle_start.code)

	var session: RunBattleSessionState = RunBattleSessionState.new()
	session.battle_session_id = session_id
	session.floor_number = request.floor_number
	session.battle_rank = request.battle_rank
	session.reward_pool = request.reward_pool
	for unit: BattleSetupUnit in setup_result.setup.player_units:
		session.participant_run_unit_ids.append(unit.source_run_unit_id)
	for stack: BattleScrollStackState in setup_result.setup.scrolls:
		session.scroll_stack_ids.append(stack.source_run_stack_id)
	working._set_active_battle_session(session)
	working._set_active_offer(null)
	working._set_phase(GameEnums.RunPhase.IN_BATTLE)
	if not transaction.commit():
		return RunFlowResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	var result: RunFlowResult = RunFlowResult.success()
	result.battle = battle_start.battle
	return result


func resolve_battle(
		run: RunState,
		battle: BattleState
) -> RunFlowResult:
	if run == null:
		return RunFlowResult.failure(GameEnums.RunCommandCode.INVALID_RUN)
	var outcome_result: BattleOutcomeResult = (
		_outcome_service.create_outcome(battle)
	)
	if not outcome_result.succeeded():
		return RunFlowResult.failure(outcome_result.code)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return RunFlowResult.failure(GameEnums.RunCommandCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	var session: RunBattleSessionState = (
		working._get_active_battle_session_mutable()
	)
	if session == null:
		return RunFlowResult.failure(
				GameEnums.RunCommandCode.BATTLE_SESSION_MISMATCH
		)
	var apply_result: RunCommandResult = _outcome_applier.apply_in_transaction(
			working,
			outcome_result.outcome
	)
	if not apply_result.succeeded():
		return RunFlowResult.failure(apply_result.code)

	var generated_offer: RewardOffer
	if outcome_result.outcome.is_victory():
		working._set_phase(GameEnums.RunPhase.CHOOSING_REWARD)
		var generation: RewardGenerationResult = (
			_reward_generation_service.generate_in_transaction(
					working,
					session.reward_pool,
					GameEnums.RewardSource.BATTLE,
					session.floor_number,
					session.battle_rank
			)
		)
		if not generation.succeeded():
			return RunFlowResult.failure(generation.failure_code)
		generated_offer = generation.offer
		working._set_active_offer(generated_offer)
	else:
		working._set_phase(GameEnums.RunPhase.ENDED)
		working._set_active_offer(null)
	working._set_active_battle_session(null)
	if not transaction.commit():
		return RunFlowResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	var result: RunFlowResult = RunFlowResult.success()
	result.outcome = outcome_result.outcome
	result.offer = (
			generated_offer.duplicate_state()
			if generated_offer != null
			else null
	)
	return result


func open_shop(
		run: RunState,
		pool: RewardPoolDefinition,
		floor_number: int
) -> RunFlowResult:
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return RunFlowResult.failure(GameEnums.RunCommandCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	if (
		working.get_phase() != GameEnums.RunPhase.READY
		or pool == null
		or pool.offer_rule != GameEnums.RewardOfferRule.PURCHASE_ANY
		or not DefinitionValidator.new().validate(pool).is_valid()
	):
		return RunFlowResult.failure(GameEnums.RunCommandCode.INVALID_PHASE)
	var generation: RewardGenerationResult = (
		_reward_generation_service.generate_in_transaction(
				working,
				pool,
				GameEnums.RewardSource.SHOP,
				floor_number,
				GameEnums.EnemyRank.STANDARD
		)
	)
	if not generation.succeeded():
		return RunFlowResult.failure(generation.failure_code)
	working._set_active_offer(generation.offer)
	working._set_phase(GameEnums.RunPhase.SHOPPING)
	if not transaction.commit():
		return RunFlowResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	var result: RunFlowResult = RunFlowResult.success()
	result.offer = generation.offer.duplicate_state()
	return result

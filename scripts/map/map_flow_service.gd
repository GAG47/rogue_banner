class_name MapFlowService
extends RefCounted

var _generation_service: MapGenerationService
var _encounter_build_service: EncounterBuildService
var _run_flow_service: RunFlowService
var _reward_offer_service: RewardOfferService
var _node_preparation_service: MapNodePreparationService
var _event_service: MapEventService


func _init(
	generation_service: MapGenerationService = null,
	encounter_build_service: EncounterBuildService = null,
	run_flow_service: RunFlowService = null,
	reward_offer_service: RewardOfferService = null,
	node_preparation_service: MapNodePreparationService = null,
	event_service: MapEventService = null
) -> void:
	_generation_service = generation_service
	if _generation_service == null:
		_generation_service = MapGenerationService.new()
	_encounter_build_service = encounter_build_service
	if _encounter_build_service == null:
		_encounter_build_service = EncounterBuildService.new()
	_run_flow_service = run_flow_service
	if _run_flow_service == null:
		_run_flow_service = RunFlowService.new()
	_reward_offer_service = reward_offer_service
	if _reward_offer_service == null:
		_reward_offer_service = RewardOfferService.new()
	_node_preparation_service = node_preparation_service
	if _node_preparation_service == null:
		_node_preparation_service = MapNodePreparationService.new(
				_run_flow_service
		)
	_event_service = event_service
	if _event_service == null:
		_event_service = MapEventService.new()


func start_map(run: RunState, definition: MapDefinition) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	if (
		run.get_phase() != GameEnums.RunPhase.READY
		or run.get_map_state() != null
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_PHASE)
	if (
		definition == null
		or not DefinitionValidator.new().validate(definition).is_valid()
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_DEFINITION)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	var generation_index: int = working._advance_map_generation()
	var generated: MapGenerationResult = _generation_service.generate(
			MapGenerationRequest.create(
					definition,
					working.get_run_seed(),
					generation_index
			)
	)
	if not generated.succeeded():
		return MapFlowResult.failure(generated.code)
	working._set_map_state(generated.map_state)
	working._set_end_reason(GameEnums.RunEndReason.NONE)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	return _success_with_read_model(run)


func advance(run: RunState, request: MapAdvanceRequest) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	if request == null or request.destination_node_id <= 0:
		return MapFlowResult.failure(GameEnums.MapFlowCode.NODE_NOT_FOUND)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	if working.get_phase() != GameEnums.RunPhase.READY:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_PHASE)
	var map_state: MapState = working._get_map_state_mutable()
	if map_state == null or not map_state.is_valid():
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_MAP)
	var node: MapNodeState = map_state._get_node_mutable(
			request.destination_node_id
	)
	if node == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.NODE_NOT_FOUND)
	if node.status == GameEnums.MapNodeStatus.RESOLVED:
		return MapFlowResult.failure(
				GameEnums.MapFlowCode.NODE_ALREADY_RESOLVED
		)
	if not map_state.get_reachable_node_ids().has(node.instance_id):
		return MapFlowResult.failure(GameEnums.MapFlowCode.NODE_NOT_REACHABLE)

	var session: MapNodeSessionState = MapNodeSessionState.new()
	session.session_id = working._allocate_progression_session_id()
	session.node_instance_id = node.instance_id
	if not map_state._enter_node(session):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	var preparation: MapNodePreparationResult = (
		_node_preparation_service.prepare_in_transaction(
			working,
			node,
			session
		)
	)
	if not preparation.succeeded():
		return MapFlowResult.failure(preparation.code)
	if (
		preparation.completes_immediately
		and not _complete_current_node(working, map_state, node)
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	var result: MapFlowResult = _success_with_read_model(run)
	result.offer = run.get_active_offer()
	return result


func start_current_battle(
	run: RunState,
	request: EncounterStartRequest
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	if working.get_phase() != GameEnums.RunPhase.PREPARING_BATTLE:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_PHASE)
	var map_state: MapState = working._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	var node: MapNodeState = _session_node(map_state, session)
	if (
		session == null
		or session.stage != GameEnums.MapSessionStage.PREPARING_BATTLE
		or node == null
		or not node.definition is EncounterMapNodeDefinition
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.SESSION_MISMATCH)
	var encounter: EncounterDefinition = (
		(node.definition as EncounterMapNodeDefinition).encounter
	)
	var built: EncounterBuildResult = _encounter_build_service.build(
			working,
			encounter,
			request,
			maxi(1, node.layer_index)
	)
	if not built.succeeded():
		return MapFlowResult.failure(built.code)
	var started: RunFlowResult = _run_flow_service.start_battle_in_transaction(
			working,
			built.request,
			session.session_id
	)
	if not started.succeeded() or started.battle == null:
		return MapFlowResult.failure(_map_run_failure(started.code, true))
	var battle_session: RunBattleSessionState = (
		working._get_active_battle_session_mutable()
	)
	if (
		battle_session == null
		or battle_session.progression_session_id != session.session_id
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.SESSION_MISMATCH)
	session.battle_session_id = battle_session.battle_session_id
	session.stage = GameEnums.MapSessionStage.IN_BATTLE
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	var result: MapFlowResult = _success_with_read_model(run)
	result.battle = started.battle
	return result


func resolve_current_battle(
	run: RunState,
	battle: BattleState
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	if working.get_phase() != GameEnums.RunPhase.IN_BATTLE:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_PHASE)
	var map_state: MapState = working._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	var node: MapNodeState = _session_node(map_state, session)
	var battle_session: RunBattleSessionState = (
		working._get_active_battle_session_mutable()
	)
	if (
		session == null
		or session.stage != GameEnums.MapSessionStage.IN_BATTLE
		or node == null
		or battle_session == null
		or battle == null
		or session.battle_session_id != battle_session.battle_session_id
		or session.battle_session_id != battle.battle_session_id
		or battle_session.progression_session_id != session.session_id
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.SESSION_MISMATCH)
	var resolved: RunFlowResult = _run_flow_service.resolve_battle_in_transaction(
			working,
			battle
	)
	if not resolved.succeeded() or resolved.outcome == null:
		return MapFlowResult.failure(_map_run_failure(resolved.code, true))
	if not resolved.outcome.is_victory():
		session.stage = GameEnums.MapSessionStage.FAILED
		working._set_active_offer(null)
		working._set_phase(GameEnums.RunPhase.ENDED)
		working._set_end_reason(GameEnums.RunEndReason.DEFEAT)
	elif resolved.offer != null:
		working._set_active_offer(resolved.offer)
		working._set_phase(GameEnums.RunPhase.CHOOSING_REWARD)
		session.offer_id = resolved.offer.offer_id
		session.stage = GameEnums.MapSessionStage.AWAITING_REWARD
	elif not _complete_current_node(working, map_state, node):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	var result: MapFlowResult = _success_with_read_model(run)
	result.outcome = resolved.outcome
	result.offer = run.get_active_offer()
	return result


func claim_current_offer(
	run: RunState,
	offer_id: int,
	option_id: int,
	destination: RewardGrantDestination = null
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	var validation: MapFlowResult = _validate_progression_offer(
			working,
			offer_id
	)
	if not validation.succeeded():
		return validation
	var claim: RunCommandResult = (
		_reward_offer_service.claim_option_in_transaction(
				working,
				offer_id,
				option_id,
				destination
		)
	)
	if not claim.succeeded():
		return MapFlowResult.failure(_map_run_failure(claim.code, false))
	if working._get_active_offer_mutable() == null:
		var map_state: MapState = working._get_map_state_mutable()
		var session: MapNodeSessionState = _active_session(map_state)
		var node: MapNodeState = _session_node(map_state, session)
		if not _complete_current_node(working, map_state, node):
			return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	var result: MapFlowResult = _success_with_read_model(run)
	result.offer = run.get_active_offer()
	return result


func take_all_current_offer(
	run: RunState,
	offer_id: int
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	var validation: MapFlowResult = _validate_progression_offer(
			working,
			offer_id
	)
	if not validation.succeeded():
		return validation
	var claim: RunCommandResult = (
		_reward_offer_service.take_all_in_transaction(working, offer_id)
	)
	if not claim.succeeded():
		return MapFlowResult.failure(_map_run_failure(claim.code, false))
	var map_state: MapState = working._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	var node: MapNodeState = _session_node(map_state, session)
	if not _complete_current_node(working, map_state, node):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	return _success_with_read_model(run)


func skip_current_offer_option(
	run: RunState,
	offer_id: int,
	option_id: int
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	var validation: MapFlowResult = _validate_progression_offer(
		working,
		offer_id
	)
	if not validation.succeeded():
		return validation
	var skipped: RunCommandResult = (
		_reward_offer_service.skip_option_in_transaction(
			working,
			offer_id,
			option_id
		)
	)
	if not skipped.succeeded():
		return MapFlowResult.failure(
			_map_run_failure(skipped.code, false)
		)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	var result: MapFlowResult = _success_with_read_model(run)
	result.offer = run.get_active_offer()
	return result


func finish_current_offer(
	run: RunState,
	offer_id: int
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	var validation: MapFlowResult = _validate_progression_offer(
		working,
		offer_id
	)
	if not validation.succeeded():
		return validation
	var finished: RunCommandResult = (
		_reward_offer_service.finish_offer_in_transaction(
			working,
			offer_id
		)
	)
	if not finished.succeeded():
		return MapFlowResult.failure(
			_map_run_failure(finished.code, false)
		)
	var map_state: MapState = working._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	var node: MapNodeState = _session_node(map_state, session)
	if not _complete_current_node(working, map_state, node):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	return _success_with_read_model(run)


func close_current_shop(run: RunState, offer_id: int) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	var map_state: MapState = working._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	var validation: MapFlowResult = _validate_progression_offer(
			working,
			offer_id
	)
	if not validation.succeeded():
		return validation
	if (
		session == null
		or session.stage != GameEnums.MapSessionStage.SHOPPING
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_NODE_KIND)
	var closed: RunCommandResult = (
		_reward_offer_service.close_offer_in_transaction(working, offer_id)
	)
	if not closed.succeeded():
		return MapFlowResult.failure(_map_run_failure(closed.code, false))
	var node: MapNodeState = _session_node(map_state, session)
	if not _complete_current_node(working, map_state, node):
		return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	return _success_with_read_model(run)


func choose_event_option(
	run: RunState,
	request: MapEventChoiceRequest
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	if working.get_phase() != GameEnums.RunPhase.RESOLVING_MAP_NODE:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_PHASE)
	var map_state: MapState = working._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	var node: MapNodeState = _session_node(map_state, session)
	var selected: MapFlowResult = _event_service.choose_in_transaction(
			working,
			map_state,
			node,
			session,
			request
	)
	if not selected.succeeded():
		return selected
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	return _success_with_read_model(run)


func execute_event_result(
	run: RunState,
	request: MapEventResolveRequest
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	if request == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_DEFINITION)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	if working.get_phase() != GameEnums.RunPhase.RESOLVING_MAP_NODE:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_PHASE)
	var map_state: MapState = working._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	var node: MapNodeState = _session_node(map_state, session)
	var executed: MapFlowResult = _event_service.execute_in_transaction(
			working,
			node,
			session,
			request
	)
	if not executed.succeeded():
		return executed
	if (
		working.get_phase() != GameEnums.RunPhase.ENDED
		and session != null
		and session.event_session != null
		and session.event_session.stage == GameEnums.MapEventStage.COMPLETED
	):
		if not _complete_current_node(working, map_state, node):
			return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	var result: MapFlowResult = _success_with_read_model(run)
	result.offer = run.get_active_offer()
	return result


func abandon_run(run: RunState) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	if run.get_phase() == GameEnums.RunPhase.ENDED:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_PHASE)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	var working: RunState = transaction.working_state
	var map_state: MapState = working._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	if session != null:
		session.stage = GameEnums.MapSessionStage.FAILED
	working._set_active_battle_session(null)
	working._set_active_offer(null)
	working._set_phase(GameEnums.RunPhase.ENDED)
	working._set_end_reason(GameEnums.RunEndReason.ABANDONED)
	if not transaction.commit():
		return MapFlowResult.failure(GameEnums.MapFlowCode.STATE_CHANGED)
	return _success_with_read_model(run)


func _validate_progression_offer(
	run: RunState,
	offer_id: int
) -> MapFlowResult:
	if run == null:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_RUN)
	if run.get_phase() not in [
		GameEnums.RunPhase.CHOOSING_REWARD,
		GameEnums.RunPhase.SHOPPING,
	]:
		return MapFlowResult.failure(GameEnums.MapFlowCode.INVALID_PHASE)
	var map_state: MapState = run._get_map_state_mutable()
	var session: MapNodeSessionState = _active_session(map_state)
	var offer: RewardOffer = run._get_active_offer_mutable()
	if (
		session == null
		or offer == null
		or offer.offer_id != offer_id
		or session.offer_id != offer_id
		or offer.progression_session_id != session.session_id
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.SESSION_MISMATCH)
	return MapFlowResult.success()


func _complete_current_node(
	run: RunState,
	map_state: MapState,
	node: MapNodeState
) -> bool:
	if (
		run == null
		or map_state == null
		or node == null
		or node.instance_id != map_state.get_current_node_id()
		or not map_state._resolve_current_node()
	):
		return false
	run._set_active_offer(null)
	if node.definition.kind == GameEnums.MapNodeKind.BOSS:
		run._set_phase(GameEnums.RunPhase.ENDED)
		run._set_end_reason(GameEnums.RunEndReason.VICTORY)
	else:
		run._set_phase(GameEnums.RunPhase.READY)
	return true


func _active_session(map_state: MapState) -> MapNodeSessionState:
	return (
		map_state._get_active_session_mutable()
		if map_state != null
		else null
	)


func _session_node(
	map_state: MapState,
	session: MapNodeSessionState
) -> MapNodeState:
	if map_state == null or session == null:
		return null
	var node: MapNodeState = map_state._get_node_mutable(
			session.node_instance_id
	)
	if (
		node == null
		or node.instance_id != map_state.get_current_node_id()
		or node.status != GameEnums.MapNodeStatus.ENTERED
	):
		return null
	return node


func _success_with_read_model(run: RunState) -> MapFlowResult:
	var result: MapFlowResult = MapFlowResult.success()
	result.read_model = MapReadModel.create(run.get_map_state())
	return result


func _map_run_failure(
	code: GameEnums.RunCommandCode,
	battle_boundary: bool
) -> GameEnums.MapFlowCode:
	match code:
		GameEnums.RunCommandCode.INVALID_RUN:
			return GameEnums.MapFlowCode.INVALID_RUN
		GameEnums.RunCommandCode.INVALID_PHASE:
			return GameEnums.MapFlowCode.INVALID_PHASE
		GameEnums.RunCommandCode.BATTLE_SESSION_MISMATCH:
			return GameEnums.MapFlowCode.SESSION_MISMATCH
		GameEnums.RunCommandCode.REWARD_GENERATION_FAILED:
			return GameEnums.MapFlowCode.REWARD_FAILED
		_:
			return (
				GameEnums.MapFlowCode.BATTLE_FAILED
				if battle_boundary
				else GameEnums.MapFlowCode.REWARD_FAILED
			)

class_name RunSessionController
extends RefCounted

var _run: RunState
var _current_battle: BattleState
var _map_flow_service: MapFlowService
var _command_service: RunCommandService
var _read_model_service: RunReadModelService


func _init(
	map_flow_service: MapFlowService = null,
	command_service: RunCommandService = null,
	read_model_service: RunReadModelService = null
) -> void:
	_map_flow_service = map_flow_service
	if _map_flow_service == null:
		_map_flow_service = MapFlowService.new()
	_command_service = command_service
	if _command_service == null:
		_command_service = RunCommandService.new()
	_read_model_service = read_model_service
	if _read_model_service == null:
		_read_model_service = RunReadModelService.new()


func start_new_run(
	setup: RunSetup,
	map_definition: MapDefinition,
	starting_scrolls: Array[ScrollDefinition] = []
) -> RunSessionResult:
	var created: RunState = RunState.create_from_setup(setup)
	if created == null:
		return RunSessionResult.run_failure(
			GameEnums.RunCommandCode.INVALID_RUN
		)
	for scroll: ScrollDefinition in starting_scrolls:
		var granted: RunCommandResult = _command_service.execute(
			created,
			GrantScrollCommand.create(scroll, 1)
		)
		if not granted.succeeded():
			return RunSessionResult.run_failure(granted.code)
	var started: MapFlowResult = _map_flow_service.start_map(
		created,
		map_definition
	)
	if not started.succeeded():
		return RunSessionResult.map_failure(started.code)
	_run = created
	_current_battle = null
	return RunSessionResult.success()


func get_route() -> RunSessionRoute.Value:
	if _run == null:
		return RunSessionRoute.Value.UNAVAILABLE
	match _run.get_phase():
		GameEnums.RunPhase.READY:
			return RunSessionRoute.Value.MAP
		GameEnums.RunPhase.PREPARING_BATTLE:
			return RunSessionRoute.Value.DEPLOYMENT
		GameEnums.RunPhase.IN_BATTLE:
			return (
				RunSessionRoute.Value.BATTLE
				if _current_battle != null
				else RunSessionRoute.Value.UNAVAILABLE
			)
		GameEnums.RunPhase.CHOOSING_REWARD:
			return RunSessionRoute.Value.REWARD
		GameEnums.RunPhase.SHOPPING:
			return RunSessionRoute.Value.SHOP
		GameEnums.RunPhase.RESOLVING_MAP_NODE:
			return RunSessionRoute.Value.EVENT
		GameEnums.RunPhase.ENDED:
			return RunSessionRoute.Value.RESULT
	return RunSessionRoute.Value.UNAVAILABLE


func get_snapshot() -> RunSessionSnapshot:
	return _read_model_service.build(_run, _current_battle, get_route())


func get_current_battle_for_host() -> BattleState:
	return _current_battle


func advance_to_node(node_instance_id: int) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	return _from_map_result(
		_map_flow_service.advance(
			_run,
			MapAdvanceRequest.create(node_instance_id)
		)
	)


func start_current_battle(
	deployments: Array[RunUnitDeployment]
) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	var request: EncounterStartRequest = EncounterStartRequest.new()
	request.player_deployments.assign(deployments)
	var started: MapFlowResult = _map_flow_service.start_current_battle(
		_run,
		request
	)
	if not started.succeeded() or started.battle == null:
		return RunSessionResult.map_failure(started.code)
	_current_battle = started.battle
	return RunSessionResult.success()


func submit_current_battle_result() -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	if (
		_current_battle == null
		or _current_battle.phase not in [
			GameEnums.BattlePhase.VICTORY,
			GameEnums.BattlePhase.FAILURE,
		]
	):
		return RunSessionResult.map_failure(
			GameEnums.MapFlowCode.BATTLE_FAILED
		)
	var resolved: MapFlowResult = (
		_map_flow_service.resolve_current_battle(
			_run,
			_current_battle
		)
	)
	if not resolved.succeeded():
		return RunSessionResult.map_failure(resolved.code)
	_current_battle = null
	return RunSessionResult.success()


func claim_offer_option(
	offer_id: int,
	option_id: int,
	destination: RewardGrantDestination = null
) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	return _from_map_result(
		_map_flow_service.claim_current_offer(
			_run,
			offer_id,
			option_id,
			destination
		)
	)


func skip_offer_option(
	offer_id: int,
	option_id: int
) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	return _from_map_result(
		_map_flow_service.skip_current_offer_option(
			_run,
			offer_id,
			option_id
		)
	)


func finish_offer(offer_id: int) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	return _from_map_result(
		_map_flow_service.finish_current_offer(_run, offer_id)
	)


func take_all_offer(offer_id: int) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	return _from_map_result(
		_map_flow_service.take_all_current_offer(_run, offer_id)
	)


func close_shop(offer_id: int) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	return _from_map_result(
		_map_flow_service.close_current_shop(_run, offer_id)
	)


func choose_event(choice_id: StringName) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	return _from_map_result(
		_map_flow_service.choose_event_option(
			_run,
			MapEventChoiceRequest.create(choice_id)
		)
	)


func execute_event(
	request: MapEventResolveRequest
) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	return _from_map_result(
		_map_flow_service.execute_event_result(_run, request)
	)


func execute_inventory_command(command: RunCommand) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	var result: RunCommandResult = _command_service.execute(_run, command)
	if not result.succeeded():
		return RunSessionResult.run_failure(result.code)
	return RunSessionResult.success()


func discard_scroll_during_offer(
	stack_instance_id: int,
	quantity: int = 1
) -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	if _run.get_phase() != GameEnums.RunPhase.CHOOSING_REWARD:
		return RunSessionResult.run_failure(
			GameEnums.RunCommandCode.INVALID_PHASE
		)
	var transaction: RunTransaction = RunTransaction.begin(_run)
	if transaction == null or transaction.working_state == null:
		return _invalid_run()
	var discarded: RunCommandResult = (
		_command_service.execute_in_transaction(
			transaction.working_state,
			ConsumeScrollCommand.create(stack_instance_id, quantity),
			true
		)
	)
	if not discarded.succeeded():
		return RunSessionResult.run_failure(discarded.code)
	if not transaction.commit():
		return RunSessionResult.run_failure(
			GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	return RunSessionResult.success()


func abandon_run() -> RunSessionResult:
	if _run == null:
		return _invalid_run()
	var abandoned: MapFlowResult = _map_flow_service.abandon_run(_run)
	if not abandoned.succeeded():
		return RunSessionResult.map_failure(abandoned.code)
	_current_battle = null
	return RunSessionResult.success()


func _invalid_run() -> RunSessionResult:
	return RunSessionResult.run_failure(GameEnums.RunCommandCode.INVALID_RUN)


func _from_map_result(result: MapFlowResult) -> RunSessionResult:
	if result == null:
		return RunSessionResult.map_failure(
			GameEnums.MapFlowCode.INTERNAL_FAILURE
		)
	if not result.succeeded():
		return RunSessionResult.map_failure(result.code)
	return RunSessionResult.success()

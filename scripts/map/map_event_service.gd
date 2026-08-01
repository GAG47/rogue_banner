class_name MapEventService
extends RefCounted

var _operation_service: MapEventOperationService
var _condition_evaluator: ConditionEvaluator
var _reward_generation_service: RewardGenerationService


func _init(
	operation_service: MapEventOperationService = null,
	condition_evaluator: ConditionEvaluator = null,
	reward_generation_service: RewardGenerationService = null
) -> void:
	_operation_service = operation_service
	if _operation_service == null:
		_operation_service = MapEventOperationService.new()
	_condition_evaluator = condition_evaluator
	if _condition_evaluator == null:
		_condition_evaluator = ConditionEvaluator.new()
	_reward_generation_service = reward_generation_service
	if _reward_generation_service == null:
		_reward_generation_service = RewardGenerationService.new()


func choose_in_transaction(
	run: RunState,
	map_state: MapState,
	node: MapNodeState,
	session: MapNodeSessionState,
	request: MapEventChoiceRequest
) -> MapFlowResult:
	var definition: MapEventDefinition = get_event_definition(node)
	if (
		run == null
		or map_state == null
		or session == null
		or request == null
		or request.choice_id == &""
		or session.stage != GameEnums.MapSessionStage.EVENT_CHOICE
		or session.event_session == null
		or session.event_session.stage != GameEnums.MapEventStage.CHOOSING
		or definition == null
	):
		return MapFlowResult.failure(GameEnums.MapFlowCode.SESSION_MISMATCH)
	var choice: MapEventChoiceDefinition = _find_choice(
			definition,
			request.choice_id
	)
	if choice == null:
		return MapFlowResult.failure(
				GameEnums.MapFlowCode.EVENT_CHOICE_NOT_FOUND
		)
	var context: MapEventConditionContext = MapEventConditionContext.create(
			run,
			node.duplicate_state(),
			session.event_session.duplicate_state(),
			maxi(1, node.layer_index)
	)
	if not _condition_evaluator.evaluate_all(
		choice.conditions,
		context
	).passed():
		return MapFlowResult.failure(
				GameEnums.MapFlowCode.EVENT_CHOICE_UNAVAILABLE
		)
	var weights: Array[float] = []
	for outcome: MapEventOutcomeDefinition in choice.outcomes:
		weights.append(outcome.weight)
	var random: SeededRandomSource = SeededRandomSource.new(
			_event_seed(
					run.get_run_seed(),
					map_state.generation_index,
					session.session_id,
					choice.choice_id
			)
	)
	var selected_index: int = random.choose_weighted_index(weights)
	if selected_index < 0 or selected_index >= choice.outcomes.size():
		return MapFlowResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	var selected: MapEventOutcomeDefinition = choice.outcomes[selected_index]
	session.event_session.selected_choice_id = choice.choice_id
	session.event_session.planned_outcome_id = selected.outcome_id
	session.event_session.stage = GameEnums.MapEventStage.RESULT_PLANNED
	session.stage = GameEnums.MapSessionStage.EVENT_RESULT_PLANNED
	return MapFlowResult.success()


func execute_in_transaction(
	run: RunState,
	node: MapNodeState,
	session: MapNodeSessionState,
	request: MapEventResolveRequest
) -> MapFlowResult:
	var definition: MapEventDefinition = get_event_definition(node)
	if (
		run == null
		or session == null
		or request == null
		or session.stage != GameEnums.MapSessionStage.EVENT_RESULT_PLANNED
		or session.event_session == null
		or session.event_session.stage
		!= GameEnums.MapEventStage.RESULT_PLANNED
		or definition == null
	):
		return MapFlowResult.failure(
				GameEnums.MapFlowCode.EVENT_RESULT_NOT_PLANNED
		)
	var outcome: MapEventOutcomeDefinition = _find_planned_outcome(
			definition,
			session.event_session
	)
	if outcome == null:
		return MapFlowResult.failure(
				GameEnums.MapFlowCode.EVENT_RESULT_NOT_PLANNED
		)
	var opened_pool: RewardPoolDefinition
	for operation: MapEventOperationDefinition in outcome.operations:
		if operation is OpenRewardPoolMapOperationDefinition:
			opened_pool = (
				operation as OpenRewardPoolMapOperationDefinition
			).reward_pool
		else:
			var applied: RunCommandResult = (
				_operation_service.execute_in_transaction(
						run,
						operation,
						request
				)
			)
			if not applied.succeeded():
				return MapFlowResult.failure(GameEnums.MapFlowCode.REWARD_FAILED)
		session.event_session.executed_operation_count += 1
	if run.count_available_units() == 0:
		session.stage = GameEnums.MapSessionStage.FAILED
		run._set_active_offer(null)
		run._set_phase(GameEnums.RunPhase.ENDED)
		run._set_end_reason(GameEnums.RunEndReason.DEFEAT)
		return MapFlowResult.success()
	if opened_pool != null:
		var generated: RewardGenerationResult = (
			_reward_generation_service.generate_in_transaction(
					run,
					opened_pool,
					GameEnums.RewardSource.EVENT,
					maxi(1, node.layer_index),
					GameEnums.EnemyRank.STANDARD,
					GameEnums.RewardGenerationMode.PROGRESSION_SAFE,
					session.session_id
				)
		)
		if not generated.succeeded():
			return MapFlowResult.failure(GameEnums.MapFlowCode.REWARD_FAILED)
		if generated.offer != null:
			run._set_active_offer(generated.offer)
			run._set_phase(GameEnums.RunPhase.CHOOSING_REWARD)
			session.offer_id = generated.offer.offer_id
			session.stage = GameEnums.MapSessionStage.AWAITING_EVENT_REWARD
			session.event_session.offer_id = generated.offer.offer_id
			session.event_session.stage = (
					GameEnums.MapEventStage.AWAITING_REWARD
			)
			var result: MapFlowResult = MapFlowResult.success()
			result.offer = generated.offer
			return result
	session.event_session.stage = GameEnums.MapEventStage.COMPLETED
	return MapFlowResult.success()


func get_event_definition(node: MapNodeState) -> MapEventDefinition:
	if node == null or node.definition == null:
		return null
	if node.definition is EventMapNodeDefinition:
		return (node.definition as EventMapNodeDefinition).event_definition
	if node.definition is CampMapNodeDefinition:
		return (node.definition as CampMapNodeDefinition).camp_definition
	return null


func _find_choice(
	definition: MapEventDefinition,
	choice_id: StringName
) -> MapEventChoiceDefinition:
	for choice: MapEventChoiceDefinition in definition.choices:
		if choice != null and choice.choice_id == choice_id:
			return choice
	return null


func _find_planned_outcome(
	definition: MapEventDefinition,
	event_session: MapEventSessionState
) -> MapEventOutcomeDefinition:
	var choice: MapEventChoiceDefinition = _find_choice(
			definition,
			event_session.selected_choice_id
	)
	if choice == null:
		return null
	for outcome: MapEventOutcomeDefinition in choice.outcomes:
		if (
			outcome != null
			and outcome.outcome_id == event_session.planned_outcome_id
		):
			return outcome
	return null


func _event_seed(
	run_seed: int,
	map_generation_index: int,
	session_id: int,
	choice_id: StringName
) -> int:
	return (
		run_seed * 1103515245
		+ map_generation_index * 12345
		+ session_id * 2654435761
		+ String(choice_id).hash()
	)

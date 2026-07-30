class_name IntentGenerationService
extends RefCounted

var _condition_evaluator: ConditionEvaluator
var _plan_builder: IntentPlanBuilder
var _definition_validator: DefinitionValidator


func _init(
		condition_evaluator: ConditionEvaluator = null,
		plan_builder: IntentPlanBuilder = null
) -> void:
	_condition_evaluator = condition_evaluator
	if _condition_evaluator == null:
		_condition_evaluator = ConditionEvaluator.new()
	_plan_builder = plan_builder
	if _plan_builder == null:
		_plan_builder = IntentPlanBuilder.new()
	_definition_validator = DefinitionValidator.new()


func generate_for_player_turn(
		battle: BattleState
) -> IntentGenerationResult:
	if (
		battle == null
		or battle.grid == null
		or battle.phase != GameEnums.BattlePhase.PLAYER_TURN
		or battle.active_side != GameEnums.BattleSide.PLAYER
	):
		return IntentGenerationResult.failure(
				GameEnums.ActionFailureCode.INVALID_PHASE
		)
	var transaction: BattleTransaction = BattleTransaction.begin(battle)
	if transaction == null or transaction.working_state == null:
		return IntentGenerationResult.failure(
				GameEnums.ActionFailureCode.INVALID_BATTLE
		)
	var working: BattleState = transaction.working_state
	var plans: Array[IntentPlan] = []
	for enemy_state: EnemyState in working.get_enemy_states():
		enemy_state.current_intent = null
		var actor: UnitState = working.get_unit(enemy_state.unit_instance_id)
		if actor == null or actor.is_defeated():
			continue
		if (
			enemy_state.definition == null
			or not _definition_validator.validate(
					enemy_state.definition
			).is_valid()
		):
			return IntentGenerationResult.failure(
					GameEnums.ActionFailureCode.INTENT_GENERATION_FAILED
			)
		var policy: EnemyDecisionPolicyDefinition = _select_policy(
				working,
				enemy_state
		)
		var intent: IntentDefinition = _select_intent(
				working,
				enemy_state,
				policy
		)
		if intent == null:
			continue
		var plan: IntentPlan = _plan_builder.build(
				working,
				enemy_state,
				intent,
				enemy_state.current_phase_id
		)
		if plan == null:
			continue
		enemy_state.current_intent = plan
		plans.append(plan)
	if not transaction.commit():
		return IntentGenerationResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)
	return IntentGenerationResult.success(plans)


func _select_policy(
		battle: BattleState,
		enemy_state: EnemyState
) -> EnemyDecisionPolicyDefinition:
	var selected_phase: EnemyPhaseDefinition
	for phase: EnemyPhaseDefinition in enemy_state.definition.phases:
		if phase == null:
			continue
		var condition_result: ConditionResult = _condition_evaluator.evaluate_all(
				phase.entry_conditions,
				EnemyDecisionContext.create(
						battle,
						enemy_state.unit_instance_id
				)
		)
		if not condition_result.passed():
			continue
		if (
			selected_phase == null
			or phase.priority > selected_phase.priority
		):
			selected_phase = phase

	var next_phase_id: StringName = (
		selected_phase.phase_id
		if selected_phase != null
		else &""
	)
	if enemy_state.current_phase_id != next_phase_id:
		enemy_state.current_phase_id = next_phase_id
		enemy_state.cycle_index = 0
	return (
		selected_phase.decision_policy
		if selected_phase != null
		else enemy_state.definition.default_decision
	)


func _select_intent(
		battle: BattleState,
		enemy_state: EnemyState,
		policy: EnemyDecisionPolicyDefinition
) -> IntentDefinition:
	if policy is FixedCycleDecisionDefinition:
		var fixed: FixedCycleDecisionDefinition = (
			policy as FixedCycleDecisionDefinition
		)
		if fixed.sequence.is_empty():
			return null
		var cycle_position: int = (
			enemy_state.cycle_index % fixed.sequence.size()
		)
		var intent: IntentDefinition = fixed.sequence[cycle_position]
		enemy_state.cycle_index = (
			enemy_state.cycle_index + 1
		) % fixed.sequence.size()
		return intent
	if policy is PriorityDecisionDefinition:
		return _select_priority_intent(
				battle,
				enemy_state,
				policy as PriorityDecisionDefinition
		)
	return null


func _select_priority_intent(
		battle: BattleState,
		enemy_state: EnemyState,
		policy: PriorityDecisionDefinition
) -> IntentDefinition:
	var eligible: Array[IntentCandidateDefinition] = []
	var best_priority: int = -2147483648
	var context: EnemyDecisionContext = EnemyDecisionContext.create(
			battle,
			enemy_state.unit_instance_id
	)
	for candidate: IntentCandidateDefinition in policy.candidates:
		if (
			candidate == null
			or candidate.intent == null
			or not _condition_evaluator.evaluate_all(
					candidate.conditions,
					context
			).passed()
		):
			continue
		if candidate.priority > best_priority:
			eligible.clear()
			best_priority = candidate.priority
		if candidate.priority == best_priority:
			eligible.append(candidate)
	if eligible.is_empty():
		return null
	var weights: Array[float] = []
	for candidate: IntentCandidateDefinition in eligible:
		weights.append(candidate.weight)
	var random_source: SeededRandomSource = SeededRandomSource.new(
			_decision_seed(battle, enemy_state)
	)
	var selected_index: int = random_source.choose_weighted_index(weights)
	if selected_index < 0:
		return null
	return eligible[selected_index].intent


func _decision_seed(
		battle: BattleState,
		enemy_state: EnemyState
) -> int:
	var value: int = battle.battle_seed
	value = value * 1103515245 + battle.round_number * 12345
	value = value * 1103515245 + enemy_state.unit_instance_id * 1013904223
	value = value * 1103515245 + enemy_state.cycle_index * 97
	value = value * 1103515245 + int(hash(enemy_state.current_phase_id))
	return value

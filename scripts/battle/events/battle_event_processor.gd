class_name BattleEventProcessor
extends RefCounted

const MAX_EVENTS_PER_CHAIN: int = 128

class TriggerActivationCounter:
	extends RefCounted

	var owner_unit_id: int = 0
	var source_order: int = 0
	var trigger: TriggerDefinition
	var count: int = 0


var _condition_evaluator: ConditionEvaluator
var _effect_planner: BattleEffectPlanner
var _effect_executor: BattleEffectExecutor


func _init(
		condition_evaluator: ConditionEvaluator = null,
		effect_planner: BattleEffectPlanner = null,
		effect_executor: BattleEffectExecutor = null
) -> void:
	_condition_evaluator = condition_evaluator
	if _condition_evaluator == null:
		_condition_evaluator = ConditionEvaluator.new()
	_effect_planner = effect_planner
	if _effect_planner == null:
		_effect_planner = BattleEffectPlanner.new()
	_effect_executor = effect_executor
	if _effect_executor == null:
		_effect_executor = BattleEffectExecutor.new()


func process(
		battle: BattleState,
		initial_events: Array[BattleEvent]
) -> BattleEventProcessResult:
	if battle == null:
		return BattleEventProcessResult.failure(
				GameEnums.ActionFailureCode.INVALID_BATTLE
		)

	var pending: Array[BattleEvent] = []
	pending.assign(initial_events)
	var processed: Array[BattleEvent] = []
	var counters: Array[TriggerActivationCounter] = []

	while not pending.is_empty():
		if processed.size() >= MAX_EVENTS_PER_CHAIN:
			return BattleEventProcessResult.failure(
					GameEnums.ActionFailureCode.TRIGGER_LIMIT_EXCEEDED,
					processed
			)
		var event: BattleEvent = pending.pop_front()
		if event == null or not battle._stamp_event(event):
			return BattleEventProcessResult.failure(
					GameEnums.ActionFailureCode.EFFECT_EXECUTION_FAILED,
					processed
			)
		processed.append(event)

		for owner: UnitState in battle.get_units():
			if owner == null or owner.is_defeated():
				continue
			var source_order: int = 0
			for art_state: ArtState in owner.arts:
				if (
					art_state == null
					or art_state.definition == null
					or art_state.definition.category
					!= GameEnums.ArtCategory.PASSIVE
				):
					source_order += 1
					continue
				for trigger: TriggerDefinition in art_state.definition.passive_triggers:
					var trigger_result: BattleEventProcessResult = (
						_process_trigger(
								battle,
								owner,
								trigger,
								source_order,
								event,
								counters
						)
					)
					if not trigger_result.succeeded:
						trigger_result.events.assign(processed)
						return trigger_result
					pending.append_array(trigger_result.events)
					source_order += 1

			for buff: BuffState in owner.get_buffs():
				if buff == null or buff.definition == null:
					continue
				for trigger: TriggerDefinition in buff.definition.passive_triggers:
					var buff_trigger_result: BattleEventProcessResult = (
						_process_trigger(
								battle,
								owner,
								trigger,
								source_order,
								event,
								counters
						)
					)
					if not buff_trigger_result.succeeded:
						buff_trigger_result.events.assign(processed)
						return buff_trigger_result
					pending.append_array(buff_trigger_result.events)
					source_order += 1

	return BattleEventProcessResult.success(processed)


func _process_trigger(
		battle: BattleState,
		owner: UnitState,
		trigger: TriggerDefinition,
		source_order: int,
		event: BattleEvent,
		counters: Array[TriggerActivationCounter]
) -> BattleEventProcessResult:
	if trigger == null or trigger.event_kind != event.kind:
		return BattleEventProcessResult.success([])
	var counter: TriggerActivationCounter = _find_counter(
			counters,
			owner.instance_id,
			source_order,
			trigger
	)
	if counter.count >= trigger.maximum_triggers_per_action:
		return BattleEventProcessResult.success([])

	var context: BattleConditionContext = BattleConditionContext.create(
			battle,
			owner.instance_id,
			null,
			null,
			null,
			event
	)
	var condition_result: ConditionResult = _condition_evaluator.evaluate_all(
			trigger.conditions,
			context
	)
	if not condition_result.passed():
		return BattleEventProcessResult.success([])

	var effect_context: EffectContext = EffectContext.create(
			battle,
			owner.instance_id,
			null,
			null,
			null,
			event
	)
	var plan_result: EffectPlanResult = _effect_planner.plan_all(
			trigger.effects,
			effect_context
	)
	if not plan_result.is_valid:
		return BattleEventProcessResult.failure(
				GameEnums.ActionFailureCode.EFFECT_PLAN_INVALID
		)
	counter.count += 1
	var effect_result: EffectResult = _effect_executor.execute_plans(
			battle,
			owner.instance_id,
			plan_result.plans
	)
	if not effect_result.succeeded():
		return BattleEventProcessResult.failure(
				GameEnums.ActionFailureCode.EFFECT_EXECUTION_FAILED
		)
	return BattleEventProcessResult.success(effect_result.events)


func _find_counter(
		counters: Array[TriggerActivationCounter],
		owner_unit_id: int,
		source_order: int,
		trigger: TriggerDefinition
) -> TriggerActivationCounter:
	for counter: TriggerActivationCounter in counters:
		if (
			counter.owner_unit_id == owner_unit_id
			and counter.source_order == source_order
			and counter.trigger == trigger
		):
			return counter
	var counter: TriggerActivationCounter = TriggerActivationCounter.new()
	counter.owner_unit_id = owner_unit_id
	counter.source_order = source_order
	counter.trigger = trigger
	counters.append(counter)
	return counter

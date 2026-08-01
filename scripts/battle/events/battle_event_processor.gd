class_name BattleEventProcessor
extends RefCounted

const MAX_EVENTS_PER_CHAIN: int = 128

class TriggerActivationCounter:
	extends RefCounted

	var owner_unit_id: int = 0
	var source_kind: GameEnums.TriggerSourceKind = GameEnums.TriggerSourceKind.ART
	var source_instance_id: int = 0
	var trigger_index: int = 0
	var count: int = 0


class TriggerBinding:
	extends RefCounted

	var owner_unit_id: int = 0
	var source_kind: GameEnums.TriggerSourceKind = GameEnums.TriggerSourceKind.ART
	var source_instance_id: int = 0
	var trigger_index: int = 0
	var trigger: TriggerDefinition
	var effect_source: BattleSource


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
		if (
			not BattleEventSchema.is_valid_event(event)
			or not battle._stamp_event(event)
		):
			return BattleEventProcessResult.failure(
					GameEnums.ActionFailureCode.EFFECT_EXECUTION_FAILED,
					processed
			)
		processed.append(event)

		var bindings: Array[TriggerBinding] = _collect_trigger_bindings(battle)
		for binding: TriggerBinding in bindings:
			if not _is_binding_active(battle, binding):
				continue
			var trigger_result: BattleEventProcessResult = _process_trigger(
					battle,
					binding,
					event,
					counters
			)
			if not trigger_result.succeeded:
				trigger_result.events.assign(processed)
				return trigger_result
			pending.append_array(trigger_result.events)

	return BattleEventProcessResult.success(processed)


func _process_trigger(
		battle: BattleState,
		binding: TriggerBinding,
		event: BattleEvent,
		counters: Array[TriggerActivationCounter]
) -> BattleEventProcessResult:
	var trigger: TriggerDefinition = binding.trigger
	if trigger == null or trigger.event_kind != event.kind:
		return BattleEventProcessResult.success([])
	var counter: TriggerActivationCounter = _find_counter(
			counters,
			binding
	)
	if counter.count >= trigger.maximum_triggers_per_action:
		return BattleEventProcessResult.success([])

	var context: BattleConditionContext = BattleConditionContext.create(
			battle,
			binding.owner_unit_id,
			null,
			null,
			null,
			event,
			binding.effect_source
	)
	var condition_result: ConditionResult = _condition_evaluator.evaluate_all(
			trigger.conditions,
			context
	)
	if condition_result.status == GameEnums.ConditionStatus.INVALID_CONTEXT:
		return BattleEventProcessResult.failure(
				GameEnums.ActionFailureCode.CONDITION_CONTEXT_INVALID
		)
	if not condition_result.passed():
		return BattleEventProcessResult.success([])

	var effect_context: EffectContext = EffectContext.create(
			battle,
			binding.owner_unit_id,
			null,
			null,
			null,
			event,
			binding.effect_source
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
			binding.owner_unit_id,
			plan_result.plans,
			binding.effect_source
	)
	if not effect_result.succeeded():
		return BattleEventProcessResult.failure(
				GameEnums.ActionFailureCode.EFFECT_EXECUTION_FAILED
		)
	return BattleEventProcessResult.success(effect_result.events)


func _find_counter(
		counters: Array[TriggerActivationCounter],
		binding: TriggerBinding
) -> TriggerActivationCounter:
	for counter: TriggerActivationCounter in counters:
		if (
			counter.owner_unit_id == binding.owner_unit_id
			and counter.source_kind == binding.source_kind
			and counter.source_instance_id == binding.source_instance_id
			and counter.trigger_index == binding.trigger_index
		):
			return counter
	var counter: TriggerActivationCounter = TriggerActivationCounter.new()
	counter.owner_unit_id = binding.owner_unit_id
	counter.source_kind = binding.source_kind
	counter.source_instance_id = binding.source_instance_id
	counter.trigger_index = binding.trigger_index
	counters.append(counter)
	return counter


func _collect_trigger_bindings(
		battle: BattleState
) -> Array[TriggerBinding]:
	var bindings: Array[TriggerBinding] = []
	for owner: UnitState in battle.get_units():
		if owner == null or owner.is_defeated():
			continue
		for slot_index: int in range(owner.arts.size()):
			var art_state: ArtState = owner.arts[slot_index]
			if (
				art_state == null
				or art_state.definition == null
				or art_state.definition.category
				!= GameEnums.ArtCategory.PASSIVE
			):
				continue
			for trigger_index: int in range(
				art_state.definition.passive_triggers.size()
			):
				bindings.append(
						_create_binding(
								owner.instance_id,
								GameEnums.TriggerSourceKind.ART,
								slot_index,
								trigger_index,
								art_state.definition.passive_triggers[
									trigger_index
								],
								BattleSource.unit(
										owner.instance_id,
										owner.side
								)
						)
				)
		for buff: BuffState in owner.get_buffs():
			if buff == null or buff.definition == null:
				continue
			for trigger_index: int in range(
				buff.definition.passive_triggers.size()
			):
				bindings.append(
						_create_binding(
								owner.instance_id,
								GameEnums.TriggerSourceKind.BUFF,
								buff.instance_id,
								trigger_index,
								buff.definition.passive_triggers[trigger_index],
								BattleSource.unit(
										owner.instance_id,
										owner.side
								)
						)
				)
	for relic: BattleRelicState in battle.get_relics():
		if relic == null or relic.definition == null:
			continue
		for trigger_index: int in range(
			relic.definition.passive_triggers.size()
		):
			bindings.append(
					_create_binding(
							0,
							GameEnums.TriggerSourceKind.RELIC,
							relic.instance_id,
							trigger_index,
							relic.definition.passive_triggers[trigger_index],
							BattleSource.relic(
									relic.instance_id,
									relic.side
							)
					)
			)
	return bindings


func _create_binding(
		owner_unit_id: int,
		source_kind: GameEnums.TriggerSourceKind,
		source_instance_id: int,
		trigger_index: int,
		trigger: TriggerDefinition,
		effect_source: BattleSource
) -> TriggerBinding:
	var binding: TriggerBinding = TriggerBinding.new()
	binding.owner_unit_id = owner_unit_id
	binding.source_kind = source_kind
	binding.source_instance_id = source_instance_id
	binding.trigger_index = trigger_index
	binding.trigger = trigger
	binding.effect_source = effect_source
	return binding


func _is_binding_active(
		battle: BattleState,
		binding: TriggerBinding
) -> bool:
	if battle == null or binding == null:
		return false
	if binding.source_kind == GameEnums.TriggerSourceKind.RELIC:
		var relic: BattleRelicState = battle.get_relic(
				binding.source_instance_id
		)
		return (
				relic != null
				and relic.definition != null
				and binding.trigger_index >= 0
				and binding.trigger_index
				< relic.definition.passive_triggers.size()
				and relic.definition.passive_triggers[
					binding.trigger_index
				] == binding.trigger
		)
	var owner: UnitState = battle.get_unit(binding.owner_unit_id)
	if owner == null or owner.is_defeated():
		return false
	if binding.source_kind == GameEnums.TriggerSourceKind.ART:
		if (
			binding.source_instance_id < 0
			or binding.source_instance_id >= owner.arts.size()
		):
			return false
		var art_state: ArtState = owner.arts[binding.source_instance_id]
		return (
				art_state != null
				and art_state.definition != null
				and binding.trigger_index >= 0
				and binding.trigger_index
				< art_state.definition.passive_triggers.size()
				and art_state.definition.passive_triggers[
					binding.trigger_index
				] == binding.trigger
		)

	var buff: BuffState = _find_buff(owner, binding.source_instance_id)
	return (
			buff != null
			and buff.definition != null
			and binding.trigger_index >= 0
			and binding.trigger_index < buff.definition.passive_triggers.size()
			and buff.definition.passive_triggers[binding.trigger_index]
			== binding.trigger
	)


func _find_buff(owner: UnitState, buff_instance_id: int) -> BuffState:
	for buff: BuffState in owner.get_buffs():
		if buff != null and buff.instance_id == buff_instance_id:
			return buff
	return null

class_name RewardGenerationService
extends RefCounted

var _condition_evaluator: ConditionEvaluator
var _grant_service: RewardGrantService


func _init(
		condition_evaluator: ConditionEvaluator = null,
		grant_service: RewardGrantService = null
) -> void:
	_condition_evaluator = condition_evaluator
	if _condition_evaluator == null:
		_condition_evaluator = ConditionEvaluator.new()
	_grant_service = grant_service
	if _grant_service == null:
		_grant_service = RewardGrantService.new()


func generate_in_transaction(
		run: RunState,
		pool: RewardPoolDefinition,
		source: GameEnums.RewardSource,
		floor_number: int,
		battle_rank: GameEnums.EnemyRank
) -> RewardGenerationResult:
	if (
		run == null
		or pool == null
		or pool.content_id == &""
		or floor_number <= 0
	):
		return RewardGenerationResult.failure(
				GameEnums.RunCommandCode.REWARD_GENERATION_FAILED
		)
	var generation_index: int = run._advance_reward_generation()
	var context: RewardGenerationContext = RewardGenerationContext.create(
			run,
			source,
			floor_number,
			battle_rank,
			generation_index
	)
	var candidates: Array[RewardEntryDefinition] = []
	for entry: RewardEntryDefinition in pool.entries:
		if _is_eligible(run, entry, context):
			candidates.append(entry)
	var option_count: int = pool.option_count
	if (
		source == GameEnums.RewardSource.BATTLE
		and pool.offer_rule == GameEnums.RewardOfferRule.PICK_ONE
	):
		option_count = mini(
				option_count,
				_count_unique_payloads(candidates)
		)
		if option_count == 0:
			return RewardGenerationResult.empty_success()
	elif _count_unique_payloads(candidates) < option_count:
		return RewardGenerationResult.failure(
				GameEnums.RunCommandCode.REWARD_GENERATION_FAILED
		)

	var offer: RewardOffer = RewardOffer.new()
	offer.offer_id = run._allocate_offer_id()
	offer.source = source
	offer.rule = pool.offer_rule
	offer.generation_index = generation_index
	var random: SeededRandomSource = SeededRandomSource.new(
			_reward_seed(
					run.get_run_seed(),
					generation_index,
					pool.content_id
			)
	)
	var selected_keys: Array[String] = []
	var selection_state: RunState = run
	if pool.offer_rule == GameEnums.RewardOfferRule.TAKE_ALL:
		selection_state = run.duplicate_state()
		if selection_state == null:
			return RewardGenerationResult.failure(
					GameEnums.RunCommandCode.REWARD_GENERATION_FAILED
			)
	for option_index: int in range(option_count):
		var selectable: Array[RewardEntryDefinition] = []
		var weights: Array[float] = []
		var selection_context: RewardGenerationContext = context
		if selection_state != run:
			selection_context = RewardGenerationContext.create(
					selection_state,
					context.source,
					context.floor_number,
					context.battle_rank,
					context.generation_index
			)
		for entry: RewardEntryDefinition in candidates:
			var key: String = _payload_key(entry.payload)
			if (
				selected_keys.has(key)
				or not _is_eligible(
						selection_state,
						entry,
						selection_context
				)
			):
				continue
			selectable.append(entry)
			weights.append(entry.weight)
		if selectable.is_empty():
			return RewardGenerationResult.failure(
					GameEnums.RunCommandCode.REWARD_GENERATION_FAILED
			)
		var selected_index: int = random.choose_weighted_index(weights)
		if selected_index < 0:
			return RewardGenerationResult.failure(
					GameEnums.RunCommandCode.REWARD_GENERATION_FAILED
			)
		var selected: RewardEntryDefinition = selectable[selected_index]
		var option: RewardOption = RewardOption.new()
		option.option_id = option_index + 1
		option.payload = selected.payload
		option.rarity = selected.rarity
		option.price = selected.price
		offer.options.append(option)
		selected_keys.append(_payload_key(selected.payload))
		if selection_state != run:
			var simulated_grant: RunCommandResult = (
				_grant_service.grant_in_transaction(
						selection_state,
						selected.payload
				)
			)
			if not simulated_grant.succeeded():
				return RewardGenerationResult.failure(
						GameEnums.RunCommandCode.REWARD_GENERATION_FAILED
				)
	return RewardGenerationResult.success(offer)


func _count_unique_payloads(
	entries: Array[RewardEntryDefinition]
) -> int:
	var keys: Array[String] = []
	for entry: RewardEntryDefinition in entries:
		if entry == null or entry.payload == null:
			continue
		var key: String = _payload_key(entry.payload)
		if not keys.has(key):
			keys.append(key)
	return keys.size()


func _is_eligible(
		run: RunState,
		entry: RewardEntryDefinition,
		context: RewardGenerationContext
) -> bool:
	if (
		entry == null
		or entry.payload == null
		or not is_finite(entry.weight)
		or entry.weight <= 0.0
		or context.floor_number < entry.minimum_floor
		or (
			entry.maximum_floor > 0
			and context.floor_number > entry.maximum_floor
		)
		or not _grant_service.can_grant(run, entry.payload)
	):
		return false
	if (
		not entry.allow_duplicate
		and _run_has_payload(run, entry.payload)
	):
		return false
	var condition_result: ConditionResult = _condition_evaluator.evaluate_all(
			entry.conditions,
			context
	)
	return condition_result.passed()


func _run_has_payload(
		run: RunState,
		payload: RewardPayloadDefinition
) -> bool:
	if payload is ArtRewardDefinition:
		var art_definition: ArtDefinition = (
			payload as ArtRewardDefinition
		).art_definition
		for art: RunArtState in run.get_arts():
			if art.definition == art_definition:
				return true
	elif payload is RelicRewardDefinition:
		return run.count_relic_definition(
				(payload as RelicRewardDefinition).relic_definition
		) > 0
	elif payload is ScrollRewardDefinition:
		return run.total_scroll_quantity(
				(payload as ScrollRewardDefinition).scroll_definition
		) > 0
	elif payload is UnitRewardDefinition:
		var unit_definition: UnitDefinition = (
			payload as UnitRewardDefinition
		).unit_definition
		for unit: RunUnitState in run.get_units():
			if unit.definition == unit_definition:
				return true
	return false


func _payload_key(payload: RewardPayloadDefinition) -> String:
	if payload is ArtRewardDefinition:
		return "art:%s" % (
			payload as ArtRewardDefinition
		).art_definition.content_id
	if payload is RelicRewardDefinition:
		return "relic:%s" % (
			payload as RelicRewardDefinition
		).relic_definition.content_id
	if payload is ScrollRewardDefinition:
		return "scroll:%s" % (
			payload as ScrollRewardDefinition
		).scroll_definition.content_id
	if payload is UnitRewardDefinition:
		return "unit:%s" % (
			payload as UnitRewardDefinition
		).unit_definition.content_id
	if payload is CurrencyRewardDefinition:
		return "currency:%d" % (
			payload as CurrencyRewardDefinition
		).amount
	if payload is HealingRewardDefinition:
		return "healing:%d" % (
			payload as HealingRewardDefinition
		).amount
	if payload is ArtUpgradeRewardDefinition:
		return "art_upgrade"
	return "unsupported:%d" % payload.kind


func _reward_seed(
		run_seed: int,
		generation_index: int,
		pool_id: StringName
) -> int:
	return (
			run_seed * 1103515245
			+ generation_index * 12345
			+ String(pool_id).hash()
	)

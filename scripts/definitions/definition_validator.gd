class_name DefinitionValidator
extends RefCounted


func validate(definition: DefinitionResource) -> DefinitionValidationResult:
	var result: DefinitionValidationResult = DefinitionValidationResult.new()
	if definition == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				&"definition",
				"Definition cannot be null."
		)
		return result

	_validate_base(definition, result)

	if definition is HeroDefinition:
		_validate_hero(definition as HeroDefinition, result)
	elif definition is UnitDefinition:
		_validate_unit(definition as UnitDefinition, result)
	elif definition is ArtDefinition:
		_validate_art(definition as ArtDefinition, result)
	elif definition is RelicDefinition:
		_validate_relic(definition as RelicDefinition, result)
	elif definition is ScrollDefinition:
		_validate_scroll(definition as ScrollDefinition, result)
	elif definition is EnemyDefinition:
		_validate_enemy(definition as EnemyDefinition, result)
	elif definition is TerrainDefinition:
		_validate_terrain(definition as TerrainDefinition, result)
	elif definition is BuffDefinition:
		_validate_buff(definition as BuffDefinition, result)
	elif definition is IntentDefinition:
		_validate_intent(definition as IntentDefinition, result)
	elif definition is RewardPoolDefinition:
		_validate_reward_pool(definition as RewardPoolDefinition, result)
	elif definition is TagDefinition:
		pass
	else:
		result.add_issue(
				GameEnums.DefinitionValidationCode.UNSUPPORTED_DEFINITION,
				&"definition",
				"Definition type is not supported by the core data validator."
		)

	return result


func _validate_base(
		definition: DefinitionResource,
		result: DefinitionValidationResult
) -> void:
	if definition.content_id == &"":
		result.add_issue(
				GameEnums.DefinitionValidationCode.EMPTY_ID,
				&"content_id",
				"Content ID is required."
		)


func _validate_hero(
		definition: HeroDefinition,
		result: DefinitionValidationResult
) -> void:
	for index: int in range(definition.starting_units.size()):
		_validate_reference(
				definition.starting_units[index],
				_indexed_path(&"starting_units", index),
				result
		)

	var seen_starting_relics: Array[StringName] = []
	for index: int in range(definition.starting_relics.size()):
		_validate_unique_reference(
				definition.starting_relics[index],
				seen_starting_relics,
				_indexed_path(&"starting_relics", index),
				result
		)

	var seen_exclusive_relics: Array[StringName] = []
	for index: int in range(definition.exclusive_relics.size()):
		_validate_unique_reference(
				definition.exclusive_relics[index],
				seen_exclusive_relics,
				_indexed_path(&"exclusive_relics", index),
				result
		)

	var seen_art_pool: Array[StringName] = []
	for index: int in range(definition.art_pool.size()):
		_validate_unique_reference(
				definition.art_pool[index],
				seen_art_pool,
				_indexed_path(&"art_pool", index),
				result
		)

	var seen_preferred_tags: Array[StringName] = []
	for index: int in range(definition.preferred_tags.size()):
		var tag_weight: TagWeight = definition.preferred_tags[index]
		var entry_path: StringName = _indexed_path(&"preferred_tags", index)
		if tag_weight == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					entry_path,
					"Preferred tag entries cannot be null."
			)
			continue
		_validate_unique_reference(
				tag_weight.tag,
				seen_preferred_tags,
				_child_path(entry_path, &"tag"),
				result
		)
		if tag_weight.weight <= 0.0:
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_VALUE,
					_child_path(entry_path, &"weight"),
					"Preferred tag weight must be greater than zero."
			)


func _validate_unit(
		definition: UnitDefinition,
		result: DefinitionValidationResult
) -> void:
	if definition.max_health <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"max_health",
				"Maximum health must be greater than zero."
		)
	if definition.base_attack < 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"base_attack",
				"Base attack cannot be negative."
		)
	if definition.max_ap <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"max_ap",
				"Maximum AP must be greater than zero."
		)
	if definition.slot_count < 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"slot_count",
				"Slot count cannot be negative."
		)
	if definition.default_arts.size() > definition.slot_count:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"default_arts",
				"Default Art count cannot exceed slot count."
		)

	_validate_tags(definition.tags, &"tags", result)

	var default_state: RunUnitState = RunUnitState.create_empty(1, definition)
	var loadout_service: ArtLoadoutService = ArtLoadoutService.new(null, self)
	for index: int in range(definition.default_arts.size()):
		var art: ArtDefinition = definition.default_arts[index]
		var art_path: StringName = _indexed_path(&"default_arts", index)
		if not _validate_reference(art, art_path, result):
			continue
		_validate_default_art_installation(
				default_state,
				loadout_service,
				art,
				index,
				art_path,
				result
		)


func _validate_art(
		definition: ArtDefinition,
		result: DefinitionValidationResult,
		validate_upgrade_variants: bool = true
) -> void:
	if definition.ap_cost < 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"ap_cost",
				"AP cost cannot be negative."
		)
	if definition.cooldown < 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"cooldown",
				"Cooldown cannot be negative."
		)

	_validate_tags(definition.required_tags, &"required_tags", result)
	_validate_conditions(
			definition.installation_conditions,
			&"installation_conditions",
			GameEnums.ConditionContextKind.ART_INSTALL,
			result
	)
	_validate_conditions(
			definition.use_conditions,
			&"use_conditions",
			GameEnums.ConditionContextKind.ACTION_USE,
			result
	)
	_validate_effects(
			definition.effects,
			&"effects",
			definition.category != GameEnums.ArtCategory.PASSIVE,
			result
	)
	_validate_triggers(
			definition.passive_triggers,
			&"passive_triggers",
			definition.category == GameEnums.ArtCategory.PASSIVE,
			GameEnums.TriggerSourceKind.ART,
			result
	)

	if definition.category == GameEnums.ArtCategory.PASSIVE:
		if definition.targeting != null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_TARGETING,
					&"targeting",
					"Passive Arts cannot declare active targeting."
			)
		if not definition.effects.is_empty():
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_VALUE,
					&"effects",
					"Passive Arts cannot declare active effects."
			)
	elif definition.targeting == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				&"targeting",
				"Active Arts require targeting configuration."
		)
	else:
		definition.targeting.validate_configuration(result, &"targeting")
		_validate_active_art_effect_context(definition, result)
	if (
		definition.category != GameEnums.ArtCategory.PASSIVE
		and not definition.passive_triggers.is_empty()
	):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"passive_triggers",
				"Active Arts cannot declare passive triggers."
		)

	if definition.upgraded_variant != null and validate_upgrade_variants:
		_validate_reference(definition.upgraded_variant, &"upgraded_variant", result)
		if _validate_art_upgrade_chain(definition, result):
			_validate_art_upgrade_variants(definition, result)


func _validate_relic(
		definition: RelicDefinition,
		result: DefinitionValidationResult
) -> void:
	if definition.maximum_copies <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"maximum_copies",
				"Maximum Relic copies must be greater than zero."
		)
	_validate_triggers(
			definition.passive_triggers,
			&"passive_triggers",
			true,
			GameEnums.TriggerSourceKind.RELIC,
			result
	)


func _validate_scroll(
		definition: ScrollDefinition,
		result: DefinitionValidationResult
) -> void:
	if definition.max_stack_size <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"max_stack_size",
				"Maximum stack size must be greater than zero."
		)
	if definition.targeting == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				&"targeting",
				"Scrolls require targeting configuration."
		)
	else:
		definition.targeting.validate_configuration(result, &"targeting")

	_validate_conditions(
			definition.use_conditions,
			&"use_conditions",
			GameEnums.ConditionContextKind.ACTION_USE,
			result
	)
	_validate_effects(definition.effects, &"effects", true, result)


func _validate_enemy(
		definition: EnemyDefinition,
		result: DefinitionValidationResult
) -> void:
	if _validate_reference(
			definition.unit_definition,
			&"unit_definition",
			result
	):
		_append_prefixed_issues(
				result,
				validate(definition.unit_definition),
				&"unit_definition"
		)

	if definition.available_intents.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_ENEMY,
				&"available_intents",
				"Enemy definitions require at least one available Intent."
		)
	var seen_intents: Array[StringName] = []
	for index: int in range(definition.available_intents.size()):
		var intent: IntentDefinition = definition.available_intents[index]
		var intent_path: StringName = _indexed_path(&"available_intents", index)
		if not _validate_unique_reference(
			intent,
			seen_intents,
			intent_path,
			result
		):
			continue
		_append_prefixed_issues(result, validate(intent), intent_path)
		if not _unit_has_art(definition.unit_definition, intent.art):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_ENEMY,
					intent_path,
					"Enemy Intents must reference an installed default Art."
			)

	if definition.default_decision == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				&"default_decision",
				"Enemy definitions require a default decision policy."
		)
	else:
		_validate_decision_policy(
				definition.default_decision,
				definition.available_intents,
				&"default_decision",
				result
		)

	var seen_phase_ids: Array[StringName] = []
	for index: int in range(definition.phases.size()):
		var phase: EnemyPhaseDefinition = definition.phases[index]
		var phase_path: StringName = _indexed_path(&"phases", index)
		if phase == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					phase_path,
					"Enemy phase references cannot be null."
			)
			continue
		if phase.phase_id == &"" or seen_phase_ids.has(phase.phase_id):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_ENEMY,
					_child_path(phase_path, &"phase_id"),
					"Enemy phase IDs must be non-empty and unique."
			)
		else:
			seen_phase_ids.append(phase.phase_id)
		_validate_conditions(
				phase.entry_conditions,
				_child_path(phase_path, &"entry_conditions"),
				GameEnums.ConditionContextKind.ENEMY_DECISION,
				result
		)
		if phase.decision_policy == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					_child_path(phase_path, &"decision_policy"),
					"Enemy phases require a decision policy."
			)
		else:
			_validate_decision_policy(
					phase.decision_policy,
					definition.available_intents,
					_child_path(phase_path, &"decision_policy"),
					result
			)


func _validate_intent(
		definition: IntentDefinition,
		result: DefinitionValidationResult
) -> void:
	if not _validate_reference(definition.art, &"art", result):
		return
	_append_prefixed_issues(result, validate(definition.art), &"art")
	if definition.art.category == GameEnums.ArtCategory.PASSIVE:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_INTENT,
				&"art",
				"Enemy Intents require an active Art."
		)
	if definition.art.targeting == null:
		return

	var expected_kind: GameEnums.TargetKind = _intent_target_kind(definition)
	if definition.art.targeting.target_kind != expected_kind:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_INTENT,
				&"target_rule",
				"Intent target rules must match the referenced Art targeting kind."
		)
	if (
		definition.kind == GameEnums.IntentKind.PATTERN
		and definition.target_rule
		!= GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
	):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_INTENT,
				&"target_rule",
				"Pattern Intents currently orient toward an opponent Unit."
		)
	if (
		definition.kind == GameEnums.IntentKind.ENHANCE
		and definition.target_rule
		not in [
			GameEnums.IntentTargetRule.SELF,
			GameEnums.IntentTargetRule.LOWEST_HEALTH_ALLY_UNIT,
		]
	):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_INTENT,
				&"target_rule",
				"Enhance Intents require a self or allied Unit target rule."
		)
	if (
		definition.movement_rule == GameEnums.IntentMovementRule.NONE
		and definition.sequence != GameEnums.IntentSequence.ART_ONLY
	):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_INTENT,
				&"sequence",
				"Intents without movement must use an Art-only sequence."
		)
	if (
		definition.movement_rule != GameEnums.IntentMovementRule.NONE
		and definition.sequence == GameEnums.IntentSequence.ART_ONLY
	):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_INTENT,
				&"sequence",
				"Intents with movement must declare its execution order."
		)


func _validate_decision_policy(
		policy: EnemyDecisionPolicyDefinition,
		available_intents: Array[IntentDefinition],
		field_path: StringName,
		result: DefinitionValidationResult
) -> void:
	if policy is FixedCycleDecisionDefinition:
		var fixed: FixedCycleDecisionDefinition = (
			policy as FixedCycleDecisionDefinition
		)
		if fixed.sequence.is_empty():
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_ENEMY,
					field_path,
					"Fixed-cycle policies require at least one Intent."
			)
		for index: int in range(fixed.sequence.size()):
			_validate_policy_intent_reference(
					fixed.sequence[index],
					available_intents,
					_indexed_path(
							_child_path(field_path, &"sequence"),
							index
					),
					result
			)
		return
	if policy is PriorityDecisionDefinition:
		var priority: PriorityDecisionDefinition = (
			policy as PriorityDecisionDefinition
		)
		if priority.candidates.is_empty():
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_ENEMY,
					field_path,
					"Priority policies require at least one candidate."
			)
		for index: int in range(priority.candidates.size()):
			var candidate: IntentCandidateDefinition = priority.candidates[index]
			var candidate_path: StringName = _indexed_path(
					_child_path(field_path, &"candidates"),
					index
			)
			if candidate == null:
				result.add_issue(
						GameEnums.DefinitionValidationCode.NULL_REFERENCE,
						candidate_path,
						"Intent candidates cannot be null."
				)
				continue
			_validate_policy_intent_reference(
					candidate.intent,
					available_intents,
					_child_path(candidate_path, &"intent"),
					result
			)
			if not is_finite(candidate.weight) or candidate.weight <= 0.0:
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_VALUE,
						_child_path(candidate_path, &"weight"),
						"Intent candidate weight must be finite and positive."
				)
			_validate_conditions(
					candidate.conditions,
					_child_path(candidate_path, &"conditions"),
					GameEnums.ConditionContextKind.ENEMY_DECISION,
					result
			)
		return
	result.add_issue(
			GameEnums.DefinitionValidationCode.INVALID_ENEMY,
			field_path,
			"Enemy decision policy type is not supported."
	)


func _validate_policy_intent_reference(
		intent: IntentDefinition,
		available_intents: Array[IntentDefinition],
		field_path: StringName,
		result: DefinitionValidationResult
) -> void:
	if intent == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				field_path,
				"Decision policy Intent references cannot be null."
		)
		return
	for available: IntentDefinition in available_intents:
		if (
			available == intent
			or (
				available != null
				and available.content_id != &""
				and available.content_id == intent.content_id
			)
		):
			return
	result.add_issue(
			GameEnums.DefinitionValidationCode.INVALID_ENEMY,
			field_path,
			"Decision policies may only reference available Enemy Intents."
	)


func _intent_target_kind(
		definition: IntentDefinition
) -> GameEnums.TargetKind:
	if definition.kind == GameEnums.IntentKind.PATTERN:
		return GameEnums.TargetKind.CELL
	match definition.target_rule:
		GameEnums.IntentTargetRule.NEAREST_OPPONENT_CELL:
			return GameEnums.TargetKind.CELL
		GameEnums.IntentTargetRule.NEAREST_SCENE_OBJECT:
			return GameEnums.TargetKind.TERRAIN_OBJECT
		_:
			return GameEnums.TargetKind.UNIT


func _unit_has_art(
		unit: UnitDefinition,
		art: ArtDefinition
) -> bool:
	if unit == null or art == null:
		return false
	for installed: ArtDefinition in unit.default_arts:
		if (
			installed == art
			or (
				installed != null
				and installed.content_id != &""
				and installed.content_id == art.content_id
			)
		):
			return true
	return false


func _validate_terrain(
		definition: TerrainDefinition,
		result: DefinitionValidationResult
) -> void:
	if definition.movement_cost < 1:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"movement_cost",
				"Movement cost must be at least one."
		)
	_validate_tags(definition.tags, &"tags", result)


func _validate_buff(
		definition: BuffDefinition,
		result: DefinitionValidationResult
) -> void:
	if definition.duration_turns <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_BUFF,
				&"duration_turns",
				"Buff duration must be greater than zero."
		)
	if definition.maximum_stacks <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_BUFF,
				&"maximum_stacks",
				"Maximum Buff stacks must be greater than zero."
		)
	for index: int in range(definition.modifiers.size()):
		var modifier: ModifierDefinition = definition.modifiers[index]
		var modifier_path: StringName = _indexed_path(&"modifiers", index)
		if modifier == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					modifier_path,
					"Buff modifier references cannot be null."
			)
		else:
			modifier.validate_configuration(result, modifier_path)
	_validate_triggers(
			definition.passive_triggers,
			&"passive_triggers",
			false,
			GameEnums.TriggerSourceKind.BUFF,
			result
	)


func _validate_reward_pool(
		definition: RewardPoolDefinition,
		result: DefinitionValidationResult
) -> void:
	if definition.option_count <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_REWARD,
				&"option_count",
				"Reward option count must be greater than zero."
		)
	if definition.entries.size() < definition.option_count:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_REWARD,
				&"entries",
				"Reward pools require at least one entry per option."
		)
	for index: int in range(definition.entries.size()):
		var entry: RewardEntryDefinition = definition.entries[index]
		var entry_path: StringName = _indexed_path(&"entries", index)
		if entry == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					entry_path,
					"Reward entries cannot be null."
			)
			continue
		if entry.payload == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					_child_path(entry_path, &"payload"),
					"Reward payloads cannot be null."
			)
		else:
			_validate_reward_payload(
					entry.payload,
					_child_path(entry_path, &"payload"),
					result
			)
		if not is_finite(entry.weight) or entry.weight <= 0.0:
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_REWARD,
					_child_path(entry_path, &"weight"),
					"Reward weight must be finite and positive."
			)
		if (
			entry.minimum_floor <= 0
			or (
				entry.maximum_floor > 0
				and entry.maximum_floor < entry.minimum_floor
			)
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_REWARD,
					_child_path(entry_path, &"minimum_floor"),
					"Reward floor bounds are invalid."
			)
		if (
			definition.offer_rule
			!= GameEnums.RewardOfferRule.PURCHASE_ANY
			and entry.price != 0
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_REWARD,
					_child_path(entry_path, &"price"),
					"Only purchase offers may contain priced entries."
			)
		if (
			definition.offer_rule == GameEnums.RewardOfferRule.TAKE_ALL
			and (
				entry.payload is HealingRewardDefinition
				or entry.payload is ArtUpgradeRewardDefinition
			)
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_REWARD,
					_child_path(entry_path, &"payload"),
					"Take-all rewards cannot require a target destination."
			)
		_validate_conditions(
				entry.conditions,
				_child_path(entry_path, &"conditions"),
				GameEnums.ConditionContextKind.REWARD_GENERATION,
				result
		)


func _validate_reward_payload(
		payload: RewardPayloadDefinition,
		field_path: StringName,
		result: DefinitionValidationResult
) -> void:
	var reference: DefinitionResource
	var expected_kind: GameEnums.RewardKind
	if payload is CurrencyRewardDefinition:
		expected_kind = GameEnums.RewardKind.CURRENCY
		if (payload as CurrencyRewardDefinition).amount <= 0:
			_add_invalid_reward(result, field_path, "Currency must be positive.")
	elif payload is ArtRewardDefinition:
		expected_kind = GameEnums.RewardKind.ART
		reference = (payload as ArtRewardDefinition).art_definition
	elif payload is RelicRewardDefinition:
		expected_kind = GameEnums.RewardKind.RELIC
		reference = (payload as RelicRewardDefinition).relic_definition
	elif payload is ScrollRewardDefinition:
		expected_kind = GameEnums.RewardKind.SCROLL
		var scroll: ScrollRewardDefinition = payload as ScrollRewardDefinition
		reference = scroll.scroll_definition
		if scroll.quantity <= 0:
			_add_invalid_reward(result, field_path, "Scroll quantity must be positive.")
	elif payload is UnitRewardDefinition:
		expected_kind = GameEnums.RewardKind.UNIT
		reference = (payload as UnitRewardDefinition).unit_definition
	elif payload is HealingRewardDefinition:
		expected_kind = GameEnums.RewardKind.HEALING
		if (payload as HealingRewardDefinition).amount <= 0:
			_add_invalid_reward(result, field_path, "Healing must be positive.")
	elif payload is ArtUpgradeRewardDefinition:
		expected_kind = GameEnums.RewardKind.ART_UPGRADE
	else:
		_add_invalid_reward(result, field_path, "Reward payload type is unsupported.")
		return
	if payload.kind != expected_kind:
		_add_invalid_reward(
				result,
				field_path,
				"Reward payload kind does not match its concrete type."
		)
	if reference != null:
		var reference_path: StringName = _child_path(field_path, &"definition")
		if _validate_reference(reference, reference_path, result):
			_append_prefixed_issues(
					result,
					validate(reference),
					reference_path
			)
	elif payload is ArtRewardDefinition \
			or payload is RelicRewardDefinition \
			or payload is ScrollRewardDefinition \
			or payload is UnitRewardDefinition:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				_child_path(field_path, &"definition"),
				"Content reward payloads require a definition."
		)


func _add_invalid_reward(
		result: DefinitionValidationResult,
		field_path: StringName,
		message: String
) -> void:
	result.add_issue(
			GameEnums.DefinitionValidationCode.INVALID_REWARD,
			field_path,
			message
	)


func _validate_active_art_effect_context(
	definition: ArtDefinition,
	result: DefinitionValidationResult
) -> void:
	var move_effect_count: int = 0
	for index: int in range(definition.effects.size()):
		var effect: EffectDefinition = definition.effects[index]
		if effect == null:
			continue
		var effect_path: StringName = _indexed_path(&"effects", index)
		if (
			effect.target_source
			== GameEnums.EffectTargetSource.EVENT_SOURCE_UNIT
			or effect.target_source
			== GameEnums.EffectTargetSource.EVENT_TARGET_UNIT
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_VALUE,
					effect_path,
					"Active Art effects cannot require a triggering event."
			)
		if effect is MoveEffectDefinition:
			move_effect_count += 1
			if (
				definition.targeting.target_kind != GameEnums.TargetKind.CELL
				or definition.targeting.minimum_targets != 1
				or definition.targeting.maximum_targets != 1
			):
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_TARGETING,
						effect_path,
						"Move Arts require exactly one selected Cell."
				)
	if move_effect_count > 1:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				&"effects",
				"An Art cannot contain more than one Move effect."
		)


func _validate_tags(
		tags: Array[TagDefinition],
		field_path: StringName,
		result: DefinitionValidationResult
) -> void:
	var seen_tags: Array[StringName] = []
	for index: int in range(tags.size()):
		_validate_unique_reference(
				tags[index],
				seen_tags,
				_indexed_path(field_path, index),
				result,
				GameEnums.DefinitionValidationCode.INVALID_TAG
		)


func _validate_conditions(
		conditions: Array[ConditionDefinition],
		field_path: StringName,
		context_kind: GameEnums.ConditionContextKind,
		result: DefinitionValidationResult
) -> void:
	for index: int in range(conditions.size()):
		var condition: ConditionDefinition = conditions[index]
		var condition_path: StringName = _indexed_path(field_path, index)
		if condition == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					condition_path,
					"Condition references cannot be null."
			)
			continue
		condition.validate_configuration(result, condition_path)
		condition.validate_context(
				context_kind,
				GameEnums.BattleEventKind.ART_USED,
				result,
				condition_path
		)


func _validate_effects(
		effects: Array[EffectDefinition],
		field_path: StringName,
		required: bool,
		result: DefinitionValidationResult
) -> void:
	if required and effects.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.MISSING_EFFECT,
				field_path,
				"At least one effect is required."
		)

	for index: int in range(effects.size()):
		var effect: EffectDefinition = effects[index]
		var effect_path: StringName = _indexed_path(field_path, index)
		if effect == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					effect_path,
					"Effect references cannot be null."
			)
			continue
		effect.validate_configuration(result, effect_path)


func _validate_triggers(
		triggers: Array[TriggerDefinition],
		field_path: StringName,
		required: bool,
		source_kind: GameEnums.TriggerSourceKind,
		result: DefinitionValidationResult
) -> void:
	if required and triggers.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.MISSING_TRIGGER,
				field_path,
				"At least one trigger is required."
		)

	for index: int in range(triggers.size()):
		var trigger: TriggerDefinition = triggers[index]
		var trigger_path: StringName = _indexed_path(field_path, index)
		if trigger == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					trigger_path,
					"Trigger references cannot be null."
			)
			continue
		trigger.validate_configuration(result, trigger_path)
		trigger.validate_source_configuration(
				source_kind,
				result,
				trigger_path
		)


func _validate_reference(
		reference: DefinitionResource,
		field_path: StringName,
		result: DefinitionValidationResult
) -> bool:
	if reference == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				field_path,
				"Definition references cannot be null."
		)
		return false
	if reference.content_id == &"":
		result.add_issue(
				GameEnums.DefinitionValidationCode.EMPTY_ID,
				field_path,
				"Referenced definitions require a content ID."
		)
		return false
	return true


func _validate_unique_reference(
		reference: DefinitionResource,
		seen_content_ids: Array[StringName],
		field_path: StringName,
		result: DefinitionValidationResult,
		duplicate_code: GameEnums.DefinitionValidationCode = (
				GameEnums.DefinitionValidationCode.DUPLICATE_REFERENCE
		)
) -> bool:
	if not _validate_reference(reference, field_path, result):
		return false
	if seen_content_ids.has(reference.content_id):
		result.add_issue(
				duplicate_code,
				field_path,
				"Duplicate definition references are not allowed in this field."
		)
		return false
	seen_content_ids.append(reference.content_id)
	return true


func _validate_default_art_installation(
		unit: RunUnitState,
		loadout_service: ArtLoadoutService,
		art: ArtDefinition,
		slot_index: int,
		field_path: StringName,
		result: DefinitionValidationResult
) -> void:
	var art_result: DefinitionValidationResult = validate(art)
	_append_prefixed_issues(result, art_result, field_path)
	if not art_result.is_valid():
		return
	var installation: ArtLoadoutResult = loadout_service.install(
			unit,
			RunArtState.create(slot_index + 1, art),
			slot_index
	)
	if not installation.succeeded():
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_INSTALL_CONDITION,
				field_path,
				"Default Art installation requirements are not satisfied."
		)


func _validate_art_upgrade_chain(
		definition: ArtDefinition,
		result: DefinitionValidationResult
) -> bool:
	var seen_instances: Array[int] = []
	var seen_content_ids: Array[StringName] = []
	var current: ArtDefinition = definition

	while current != null:
		var instance_id: int = current.get_instance_id()
		if seen_instances.has(instance_id):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_REFERENCE,
					&"upgraded_variant",
					"Art upgrade variants cannot form a cycle."
			)
			return false
		seen_instances.append(instance_id)

		if current.content_id != &"":
			if seen_content_ids.has(current.content_id):
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_REFERENCE,
						&"upgraded_variant",
						"Art upgrade variants must use distinct content IDs."
				)
				return false
			seen_content_ids.append(current.content_id)

		current = current.upgraded_variant
	return true


func _validate_art_upgrade_variants(
		definition: ArtDefinition,
		result: DefinitionValidationResult
) -> void:
	var current: ArtDefinition = definition.upgraded_variant
	var field_path: StringName = &"upgraded_variant"
	while current != null:
		var variant_result: DefinitionValidationResult = (
			DefinitionValidationResult.new()
		)
		_validate_base(current, variant_result)
		_validate_art(current, variant_result, false)
		_append_prefixed_issues(result, variant_result, field_path)
		current = current.upgraded_variant
		field_path = _child_path(field_path, &"upgraded_variant")


func _append_prefixed_issues(
		target: DefinitionValidationResult,
		source: DefinitionValidationResult,
		prefix: StringName
) -> void:
	for issue: DefinitionValidationIssue in source.issues:
		target.add_issue(
				issue.code,
				_child_path(prefix, issue.field_path),
				issue.message
		)


func _child_path(parent: StringName, child: StringName) -> StringName:
	return StringName("%s.%s" % [String(parent), String(child)])


func _indexed_path(field_path: StringName, index: int) -> StringName:
	return StringName("%s[%d]" % [String(field_path), index])

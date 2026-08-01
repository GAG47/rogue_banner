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
	elif definition is MapDefinition:
		_validate_map(definition as MapDefinition, result)
	elif definition is BattlefieldDefinition:
		_validate_battlefield(definition as BattlefieldDefinition, result)
	elif definition is EncounterDefinition:
		_validate_encounter(definition as EncounterDefinition, result)
	elif definition is MapEventDefinition:
		_validate_map_event(definition as MapEventDefinition, result)
	elif definition is MapNodeDefinition:
		_validate_map_node(definition as MapNodeDefinition, result)
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


func _validate_battlefield(
	definition: BattlefieldDefinition,
	result: DefinitionValidationResult
) -> void:
	if definition.width <= 0 or definition.height <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
				&"width",
				"Battlefield dimensions must be positive."
		)
	if _validate_reference(
		definition.default_terrain,
		&"default_terrain",
		result
	):
		_append_prefixed_issues(
				result,
				validate(definition.default_terrain),
				&"default_terrain"
		)
	var override_cells: Array[Vector2i] = []
	for index: int in range(definition.terrain_overrides.size()):
		var placement: BattlefieldTerrainPlacement = (
			definition.terrain_overrides[index]
		)
		var path: StringName = _indexed_path(&"terrain_overrides", index)
		if placement == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					path,
					"Terrain placements cannot be null."
			)
			continue
		if (
			not _coordinate_in_bounds(
					placement.coordinate,
					definition.width,
					definition.height
			)
			or override_cells.has(placement.coordinate)
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
					_child_path(path, &"coordinate"),
					"Terrain placement coordinates must be unique and in bounds."
			)
		else:
			override_cells.append(placement.coordinate)
		if _validate_reference(
			placement.terrain,
			_child_path(path, &"terrain"),
			result
		):
			_append_prefixed_issues(
					result,
					validate(placement.terrain),
					_child_path(path, &"terrain")
			)
	if definition.player_deployment_cells.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
				&"player_deployment_cells",
				"Battlefields require at least one player deployment Cell."
		)
	var deployment_cells: Array[Vector2i] = []
	for index: int in range(definition.player_deployment_cells.size()):
		var coordinate: Vector2i = definition.player_deployment_cells[index]
		var path: StringName = _indexed_path(
				&"player_deployment_cells",
				index
		)
		if (
			not _coordinate_in_bounds(
					coordinate,
					definition.width,
					definition.height
			)
			or deployment_cells.has(coordinate)
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
					path,
					"Deployment Cells must be unique and in bounds."
			)
		else:
			deployment_cells.append(coordinate)
			var terrain: TerrainDefinition = _battlefield_terrain_at(
					definition,
					coordinate
			)
			if terrain != null and terrain.blocks_movement:
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
						path,
						"Deployment Cells require passable Terrain."
				)


func _validate_encounter(
	definition: EncounterDefinition,
	result: DefinitionValidationResult
) -> void:
	if _validate_reference(definition.battlefield, &"battlefield", result):
		_append_prefixed_issues(
				result,
				validate(definition.battlefield),
				&"battlefield"
		)
	if definition.enemy_spawns.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
				&"enemy_spawns",
				"Encounters require at least one Enemy spawn."
		)
	var spawn_cells: Array[Vector2i] = []
	for index: int in range(definition.enemy_spawns.size()):
		var spawn: EnemySpawnDefinition = definition.enemy_spawns[index]
		var path: StringName = _indexed_path(&"enemy_spawns", index)
		if spawn == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					path,
					"Enemy spawns cannot be null."
			)
			continue
		if _validate_reference(
			spawn.enemy_definition,
			_child_path(path, &"enemy_definition"),
			result
		):
			_append_prefixed_issues(
					result,
					validate(spawn.enemy_definition),
					_child_path(path, &"enemy_definition")
			)
		if (
			definition.battlefield == null
			or not _coordinate_in_bounds(
					spawn.coordinate,
					definition.battlefield.width,
					definition.battlefield.height
			)
			or spawn_cells.has(spawn.coordinate)
			or definition.battlefield.player_deployment_cells.has(
					spawn.coordinate
			)
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
					_child_path(path, &"coordinate"),
					"Enemy spawn Cells must be unique, in bounds, and outside deployment Cells."
			)
		else:
			spawn_cells.append(spawn.coordinate)
			var terrain: TerrainDefinition = _battlefield_terrain_at(
					definition.battlefield,
					spawn.coordinate
			)
			if terrain != null and terrain.blocks_movement:
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
						_child_path(path, &"coordinate"),
						"Enemy spawn Cells require passable Terrain."
				)
	if _validate_reference(definition.reward_pool, &"reward_pool", result):
		_append_prefixed_issues(
				result,
				validate(definition.reward_pool),
				&"reward_pool"
		)
		if (
			definition.reward_pool.offer_rule
			!= GameEnums.RewardOfferRule.PICK_ONE
		):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_ENCOUNTER,
					&"reward_pool",
					"Encounter rewards must use the pick-one rule."
			)


func _validate_map_node(
	definition: MapNodeDefinition,
	result: DefinitionValidationResult
) -> void:
	if definition is EncounterMapNodeDefinition:
		if definition.kind not in [
			GameEnums.MapNodeKind.BATTLE,
			GameEnums.MapNodeKind.ELITE,
			GameEnums.MapNodeKind.BOSS,
		]:
			_add_invalid_map(result, &"kind", "Encounter node kind is invalid.")
		var encounter_node: EncounterMapNodeDefinition = (
			definition as EncounterMapNodeDefinition
		)
		if _validate_reference(encounter_node.encounter, &"encounter", result):
			_append_prefixed_issues(
					result,
					validate(encounter_node.encounter),
					&"encounter"
			)
			var expected_rank: GameEnums.EnemyRank = (
				GameEnums.EnemyRank.STANDARD
			)
			if definition.kind == GameEnums.MapNodeKind.ELITE:
				expected_rank = GameEnums.EnemyRank.ELITE
			elif definition.kind == GameEnums.MapNodeKind.BOSS:
				expected_rank = GameEnums.EnemyRank.BOSS
			if encounter_node.encounter.battle_rank != expected_rank:
				_add_invalid_map(
						result,
						&"encounter",
						"Encounter rank must match its Map node kind."
				)
		return
	if definition is ShopMapNodeDefinition:
		var shop: ShopMapNodeDefinition = definition as ShopMapNodeDefinition
		if definition.kind != GameEnums.MapNodeKind.SHOP:
			_add_invalid_map(result, &"kind", "Shop node kind is invalid.")
		_validate_map_reward_pool(
				shop.reward_pool,
				&"reward_pool",
				GameEnums.RewardOfferRule.PURCHASE_ANY,
				result
		)
		return
	if definition is ChestMapNodeDefinition:
		var chest: ChestMapNodeDefinition = definition as ChestMapNodeDefinition
		if definition.kind != GameEnums.MapNodeKind.CHEST:
			_add_invalid_map(result, &"kind", "Chest node kind is invalid.")
		if _validate_reference(chest.reward_pool, &"reward_pool", result):
			_append_prefixed_issues(
					result,
					validate(chest.reward_pool),
					&"reward_pool"
			)
			if (
				chest.reward_pool.offer_rule
				== GameEnums.RewardOfferRule.PURCHASE_ANY
			):
				_add_invalid_map(
						result,
						&"reward_pool",
						"Chest rewards cannot use purchase-any offers."
				)
		return
	if definition is EventMapNodeDefinition:
		var event_node: EventMapNodeDefinition = (
			definition as EventMapNodeDefinition
		)
		if definition.kind != GameEnums.MapNodeKind.EVENT:
			_add_invalid_map(result, &"kind", "Event node kind is invalid.")
		if _validate_reference(
			event_node.event_definition,
			&"event_definition",
			result
		):
			_append_prefixed_issues(
					result,
					validate(event_node.event_definition),
					&"event_definition"
			)
		return
	if definition is CampMapNodeDefinition:
		var camp_node: CampMapNodeDefinition = definition as CampMapNodeDefinition
		if definition.kind != GameEnums.MapNodeKind.CAMP:
			_add_invalid_map(result, &"kind", "Camp node kind is invalid.")
		if _validate_reference(
			camp_node.camp_definition,
			&"camp_definition",
			result
		):
			_append_prefixed_issues(
					result,
					validate(camp_node.camp_definition),
					&"camp_definition"
			)
		return
	if definition.kind != GameEnums.MapNodeKind.START:
		_add_invalid_map(
				result,
				&"kind",
				"Generic Map nodes may only represent the start node."
		)


func _validate_map(
	definition: MapDefinition,
	result: DefinitionValidationResult
) -> void:
	if (
		definition.layer_count <= 0
		or definition.minimum_nodes_per_layer <= 0
		or definition.maximum_nodes_per_layer
		< definition.minimum_nodes_per_layer
	):
		_add_invalid_map(
				result,
				&"layer_count",
				"Map layer and node-count bounds are invalid."
		)
	if (
		not is_finite(definition.extra_connection_chance)
		or definition.extra_connection_chance < 0.0
		or definition.extra_connection_chance > 1.0
	):
		_add_invalid_map(
				result,
				&"extra_connection_chance",
				"Extra connection chance must be between zero and one."
		)
	if _validate_reference(definition.start_node, &"start_node", result):
		_append_prefixed_issues(
				result,
				validate(definition.start_node),
				&"start_node"
		)
		if definition.start_node.kind != GameEnums.MapNodeKind.START:
			_add_invalid_map(result, &"start_node", "Start node kind is invalid.")
	if _validate_reference(definition.boss_node, &"boss_node", result):
		_append_prefixed_issues(
				result,
				validate(definition.boss_node),
				&"boss_node"
		)
		if definition.boss_node.kind != GameEnums.MapNodeKind.BOSS:
			_add_invalid_map(result, &"boss_node", "Boss node kind is invalid.")
	if definition.node_pool.is_empty():
		_add_invalid_map(result, &"node_pool", "Map node pools cannot be empty.")
	var minimum_total: int = 0
	var maximum_total: int = 0
	var has_unlimited_entry: bool = false
	for index: int in range(definition.node_pool.size()):
		var entry: MapNodePoolEntry = definition.node_pool[index]
		var path: StringName = _indexed_path(&"node_pool", index)
		if entry == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					path,
					"Map node pool entries cannot be null."
			)
			continue
		if _validate_reference(
			entry.node_definition,
			_child_path(path, &"node_definition"),
			result
		):
			_append_prefixed_issues(
					result,
					validate(entry.node_definition),
					_child_path(path, &"node_definition")
			)
			if entry.node_definition.kind in [
				GameEnums.MapNodeKind.START,
				GameEnums.MapNodeKind.BOSS,
			]:
				_add_invalid_map(
						result,
						_child_path(path, &"node_definition"),
						"Start and Boss nodes cannot appear in the random pool."
				)
		if not is_finite(entry.weight) or entry.weight <= 0.0:
			_add_invalid_map(result, _child_path(path, &"weight"), "Map node weight must be positive.")
		if (
			entry.minimum_layer <= 0
			or entry.minimum_layer > definition.layer_count
			or (
				entry.maximum_layer > 0
				and (
					entry.maximum_layer < entry.minimum_layer
					or entry.maximum_layer > definition.layer_count
				)
			)
		):
			_add_invalid_map(result, _child_path(path, &"minimum_layer"), "Map node layer bounds are invalid.")
		if entry.minimum_copies < 0:
			_add_invalid_map(
					result,
					_child_path(path, &"minimum_copies"),
					"Minimum copies cannot be negative."
			)
		if entry.maximum_copies < 0:
			_add_invalid_map(
					result,
					_child_path(path, &"maximum_copies"),
					"Maximum copies cannot be negative."
			)
		if (
			entry.minimum_copies >= 0
			and entry.maximum_copies > 0
			and entry.minimum_copies > entry.maximum_copies
		):
			_add_invalid_map(result, _child_path(path, &"minimum_copies"), "Minimum copies cannot exceed maximum copies.")
		minimum_total += maxi(0, entry.minimum_copies)
		if entry.maximum_copies == 0:
			has_unlimited_entry = true
		elif entry.maximum_copies > 0:
			maximum_total += entry.maximum_copies
	if (
		minimum_total
		> definition.layer_count * definition.minimum_nodes_per_layer
	):
		_add_invalid_map(
				result,
				&"node_pool",
				"Required Map node copies exceed the minimum generated capacity."
		)
	if (
		not has_unlimited_entry
		and maximum_total
		< definition.layer_count * definition.maximum_nodes_per_layer
	):
		_add_invalid_map(
				result,
				&"node_pool",
				"Map node copy limits cannot fill the maximum generated capacity."
		)
	for layer_number: int in range(1, definition.layer_count + 1):
		var layer_has_entry: bool = false
		var layer_has_unlimited_entry: bool = false
		var layer_maximum_total: int = 0
		for entry: MapNodePoolEntry in definition.node_pool:
			if entry == null or entry.node_definition == null:
				continue
			if (
				layer_number < entry.minimum_layer
				or (
					entry.maximum_layer > 0
					and layer_number > entry.maximum_layer
				)
			):
				continue
			layer_has_entry = true
			if entry.maximum_copies == 0:
				layer_has_unlimited_entry = true
			elif entry.maximum_copies > 0:
				layer_maximum_total += entry.maximum_copies
		if not layer_has_entry:
			_add_invalid_map(
					result,
					&"node_pool",
					"Every generated layer requires an eligible node-pool entry."
			)
		elif (
			not layer_has_unlimited_entry
			and layer_maximum_total < definition.maximum_nodes_per_layer
		):
			_add_invalid_map(
					result,
					&"node_pool",
					"Node copy limits cannot fill every Cell in a generated layer."
			)
	for interval_start: int in range(1, definition.layer_count + 1):
		for interval_end: int in range(
			interval_start,
			definition.layer_count + 1
		):
			var required_in_interval: int = 0
			for entry: MapNodePoolEntry in definition.node_pool:
				if entry == null:
					continue
				var maximum_layer: int = entry.maximum_layer
				if maximum_layer == 0:
					maximum_layer = definition.layer_count
				if (
					entry.minimum_layer >= interval_start
					and maximum_layer <= interval_end
				):
					required_in_interval += maxi(0, entry.minimum_copies)
			if (
				required_in_interval
				> (interval_end - interval_start + 1)
				* definition.minimum_nodes_per_layer
			):
				_add_invalid_map(
						result,
						&"node_pool",
						"Required node copies cannot fit their allowed layer interval."
				)


func _validate_map_event(
	definition: MapEventDefinition,
	result: DefinitionValidationResult
) -> void:
	if definition.choices.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
				&"choices",
				"Map interactions require at least one choice."
		)
	var choice_ids: Array[StringName] = []
	for choice_index: int in range(definition.choices.size()):
		var choice: MapEventChoiceDefinition = definition.choices[choice_index]
		var choice_path: StringName = _indexed_path(&"choices", choice_index)
		if choice == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					choice_path,
					"Map Event choices cannot be null."
			)
			continue
		if choice.choice_id == &"" or choice_ids.has(choice.choice_id):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
					_child_path(choice_path, &"choice_id"),
					"Map Event choice IDs must be non-empty and unique."
			)
		else:
			choice_ids.append(choice.choice_id)
		_validate_conditions(
				choice.conditions,
				_child_path(choice_path, &"conditions"),
				GameEnums.ConditionContextKind.MAP_EVENT,
				result
		)
		if choice.outcomes.is_empty():
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
					_child_path(choice_path, &"outcomes"),
					"Map Event choices require at least one outcome."
			)
		if definition is CampDefinition and choice.outcomes.size() != 1:
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
					_child_path(choice_path, &"outcomes"),
					"Camp choices require exactly one deterministic outcome."
			)
		var outcome_ids: Array[StringName] = []
		for outcome_index: int in range(choice.outcomes.size()):
			var outcome: MapEventOutcomeDefinition = choice.outcomes[outcome_index]
			var outcome_path: StringName = _indexed_path(
					_child_path(choice_path, &"outcomes"),
					outcome_index
			)
			if outcome == null:
				result.add_issue(
						GameEnums.DefinitionValidationCode.NULL_REFERENCE,
						outcome_path,
						"Map Event outcomes cannot be null."
				)
				continue
			if outcome.outcome_id == &"" or outcome_ids.has(outcome.outcome_id):
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
						_child_path(outcome_path, &"outcome_id"),
						"Map Event outcome IDs must be non-empty and unique per choice."
				)
			else:
				outcome_ids.append(outcome.outcome_id)
			if not is_finite(outcome.weight) or outcome.weight <= 0.0:
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
						_child_path(outcome_path, &"weight"),
						"Map Event outcome weights must be positive."
				)
			if outcome.operations.is_empty():
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
						_child_path(outcome_path, &"operations"),
						"Map Event outcomes require at least one operation."
				)
			var reward_pool_count: int = 0
			for operation_index: int in range(outcome.operations.size()):
				var operation: MapEventOperationDefinition = (
					outcome.operations[operation_index]
				)
				var operation_path: StringName = _indexed_path(
						_child_path(outcome_path, &"operations"),
						operation_index
				)
				_validate_map_operation(operation, operation_path, result)
				if operation is OpenRewardPoolMapOperationDefinition:
					reward_pool_count += 1
					if operation_index != outcome.operations.size() - 1:
						result.add_issue(
								GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
								operation_path,
								"Reward-pool operations must be the final Event operation."
						)
			if reward_pool_count > 1:
				result.add_issue(
						GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
						outcome_path,
						"Map Event outcomes may open at most one Reward pool."
				)


func _validate_map_operation(
	operation: MapEventOperationDefinition,
	field_path: StringName,
	result: DefinitionValidationResult
) -> void:
	if operation == null:
		result.add_issue(
				GameEnums.DefinitionValidationCode.NULL_REFERENCE,
				field_path,
				"Map Event operations cannot be null."
		)
		return
	if operation is ChangeGoldMapOperationDefinition:
		if (operation as ChangeGoldMapOperationDefinition).amount == 0:
			_add_invalid_map_event(result, field_path, "Gold change cannot be zero.")
	elif operation is HealUnitMapOperationDefinition:
		if (operation as HealUnitMapOperationDefinition).amount <= 0:
			_add_invalid_map_event(result, field_path, "Healing must be positive.")
	elif operation is DamageUnitMapOperationDefinition:
		if (operation as DamageUnitMapOperationDefinition).amount <= 0:
			_add_invalid_map_event(result, field_path, "Damage must be positive.")
	elif operation is ConsumeScrollMapOperationDefinition:
		if (operation as ConsumeScrollMapOperationDefinition).quantity <= 0:
			_add_invalid_map_event(result, field_path, "Scroll consumption must be positive.")
	elif operation is RemoveRelicMapOperationDefinition:
		pass
	elif operation is GrantRewardMapOperationDefinition:
		var grant: GrantRewardMapOperationDefinition = (
			operation as GrantRewardMapOperationDefinition
		)
		if grant.payload == null:
			result.add_issue(
					GameEnums.DefinitionValidationCode.NULL_REFERENCE,
					_child_path(field_path, &"payload"),
					"Reward operations require a payload."
			)
		else:
			_validate_reward_payload(grant.payload, _child_path(field_path, &"payload"), result)
	elif operation is OpenRewardPoolMapOperationDefinition:
		var open: OpenRewardPoolMapOperationDefinition = (
			operation as OpenRewardPoolMapOperationDefinition
		)
		if _validate_reference(open.reward_pool, _child_path(field_path, &"reward_pool"), result):
			_append_prefixed_issues(
					result,
					validate(open.reward_pool),
					_child_path(field_path, &"reward_pool")
			)
			if open.reward_pool.offer_rule == GameEnums.RewardOfferRule.PURCHASE_ANY:
				_add_invalid_map_event(result, field_path, "Event rewards cannot open a shop offer.")
	else:
		_add_invalid_map_event(result, field_path, "Map Event operation type is unsupported.")


func _validate_map_reward_pool(
	pool: RewardPoolDefinition,
	field_path: StringName,
	expected_rule: GameEnums.RewardOfferRule,
	result: DefinitionValidationResult
) -> void:
	if not _validate_reference(pool, field_path, result):
		return
	_append_prefixed_issues(result, validate(pool), field_path)
	if pool.offer_rule != expected_rule:
		_add_invalid_map(result, field_path, "Reward pool rule does not match its Map node.")


func _coordinate_in_bounds(
	coordinate: Vector2i,
	width: int,
	height: int
) -> bool:
	return (
		coordinate.x >= 0
		and coordinate.y >= 0
		and coordinate.x < width
		and coordinate.y < height
	)


func _battlefield_terrain_at(
	definition: BattlefieldDefinition,
	coordinate: Vector2i
) -> TerrainDefinition:
	if definition == null:
		return null
	for placement: BattlefieldTerrainPlacement in definition.terrain_overrides:
		if placement != null and placement.coordinate == coordinate:
			return placement.terrain
	return definition.default_terrain


func _add_invalid_map(
	result: DefinitionValidationResult,
	field_path: StringName,
	message: String
) -> void:
	result.add_issue(
			GameEnums.DefinitionValidationCode.INVALID_MAP,
			field_path,
			message
	)


func _add_invalid_map_event(
	result: DefinitionValidationResult,
	field_path: StringName,
	message: String
) -> void:
	result.add_issue(
			GameEnums.DefinitionValidationCode.INVALID_MAP_EVENT,
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

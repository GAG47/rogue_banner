class_name CoreDataLayerTest
extends RefCounted

const TEST_RESOURCE_PATH: String = "user://core_data_layer_unit.tres"


static func run(suite: TestSuite) -> void:
	_test_valid_definitions(suite)
	_test_invalid_definition_data(suite)
	_test_tag_installation_validation(suite)
	_test_default_art_installation_validation(suite)
	_test_upgrade_cycle_validation(suite)
	_test_upgrade_variant_validation(suite)
	_test_event_context_validation(suite)
	_test_rule_contract_values(suite)
	_test_definition_state_separation(suite)
	_test_resource_round_trip(suite)


static func _test_valid_definitions(suite: TestSuite) -> void:
	var fixture: CoreDataFixture = CoreDataFixture.create()
	var validator: DefinitionValidator = DefinitionValidator.new()
	var definitions: Array[DefinitionResource] = [
		fixture.tag,
		fixture.active_art,
		fixture.passive_art,
		fixture.unit,
		fixture.relic,
		fixture.scroll,
		fixture.enemy,
		fixture.terrain,
		fixture.hero,
	]

	for definition: DefinitionResource in definitions:
		var result: DefinitionValidationResult = validator.validate(definition)
		suite.assert_true(
				result.is_valid(),
				"Expected %s to be valid." % definition.get_class()
		)
		suite.assert_int_equal(
				0,
				result.issues.size(),
				"Valid definitions must not produce validation issues."
		)


static func _test_invalid_definition_data(suite: TestSuite) -> void:
	var validator: DefinitionValidator = DefinitionValidator.new()

	var tag: TagDefinition = TagDefinition.new()
	var tag_result: DefinitionValidationResult = validator.validate(tag)
	suite.assert_true(
			tag_result.has_code(GameEnums.DefinitionValidationCode.EMPTY_ID),
			"Empty content IDs must be rejected."
	)

	var unit: UnitDefinition = UnitDefinition.new()
	unit.content_id = &"invalid_unit"
	unit.max_health = 0
	unit.base_attack = -1
	unit.max_ap = 0
	unit.slot_count = -1
	unit.tags.append(null)
	var unit_result: DefinitionValidationResult = validator.validate(unit)
	suite.assert_true(
			unit_result.has_code(GameEnums.DefinitionValidationCode.INVALID_VALUE),
			"Invalid Unit numeric values must be rejected."
	)
	suite.assert_true(
			unit_result.has_code(GameEnums.DefinitionValidationCode.NULL_REFERENCE),
			"Null Unit tag references must be rejected."
	)

	var art: ArtDefinition = ArtDefinition.new()
	art.content_id = &"invalid_art"
	art.ap_cost = -1
	art.cooldown = -1
	art.installation_conditions.append(null)
	var art_result: DefinitionValidationResult = validator.validate(art)
	suite.assert_true(
			art_result.has_code(GameEnums.DefinitionValidationCode.INVALID_VALUE),
			"Invalid Art costs must be rejected."
	)
	suite.assert_true(
			art_result.has_code(GameEnums.DefinitionValidationCode.NULL_REFERENCE),
			"Missing Art targeting and null conditions must be rejected."
	)
	suite.assert_true(
			art_result.has_code(GameEnums.DefinitionValidationCode.MISSING_EFFECT),
			"Active Arts without effects must be rejected."
	)

	var targeting: TargetingDefinition = TargetingDefinition.new()
	targeting.minimum_range = 2
	targeting.maximum_range = 1
	var fixture: CoreDataFixture = CoreDataFixture.create()
	fixture.scroll.targeting = targeting
	var targeting_result: DefinitionValidationResult = validator.validate(fixture.scroll)
	suite.assert_true(
			targeting_result.has_code(GameEnums.DefinitionValidationCode.INVALID_TARGETING),
			"Invalid targeting ranges must be rejected."
	)

	var enemy: EnemyDefinition = EnemyDefinition.new()
	enemy.content_id = &"invalid_enemy"
	var enemy_result: DefinitionValidationResult = validator.validate(enemy)
	suite.assert_true(
			enemy_result.has_code(GameEnums.DefinitionValidationCode.NULL_REFERENCE),
			"Enemy definitions require a Unit definition."
	)

	var terrain: TerrainDefinition = TerrainDefinition.new()
	terrain.content_id = &"invalid_terrain"
	terrain.movement_cost = 0
	var terrain_result: DefinitionValidationResult = validator.validate(terrain)
	suite.assert_true(
			terrain_result.has_code(GameEnums.DefinitionValidationCode.INVALID_VALUE),
			"Terrain movement cost must be positive."
	)

	var hero: HeroDefinition = HeroDefinition.new()
	hero.content_id = &"invalid_hero"
	var tag_weight: TagWeight = TagWeight.new()
	tag_weight.weight = 0.0
	hero.preferred_tags.append(tag_weight)
	var hero_result: DefinitionValidationResult = validator.validate(hero)
	suite.assert_true(
			hero_result.has_code(GameEnums.DefinitionValidationCode.NULL_REFERENCE),
			"Preferred tag entries require a Tag definition."
	)
	suite.assert_true(
			hero_result.has_code(GameEnums.DefinitionValidationCode.INVALID_VALUE),
			"Preferred tag weights must be positive."
	)


static func _test_tag_installation_validation(suite: TestSuite) -> void:
	var fixture: CoreDataFixture = CoreDataFixture.create()
	var unavailable_tag: TagDefinition = TagDefinition.new()
	unavailable_tag.content_id = &"arcane"
	fixture.active_art.required_tags.clear()
	fixture.active_art.required_tags.append(unavailable_tag)

	var result: DefinitionValidationResult = DefinitionValidator.new().validate(fixture.unit)
	suite.assert_true(
			result.has_code(GameEnums.DefinitionValidationCode.INVALID_INSTALL_CONDITION),
			"Default Arts must satisfy Unit tag requirements."
	)


static func _test_default_art_installation_validation(
		suite: TestSuite
) -> void:
	var fixture: CoreDataFixture = CoreDataFixture.create()
	fixture.active_art.installation_conditions.append(
			FailingConditionDefinition.new()
	)
	var result: DefinitionValidationResult = (
		DefinitionValidator.new().validate(fixture.unit)
	)
	suite.assert_true(
			result.has_code(
					GameEnums.DefinitionValidationCode.INVALID_INSTALL_CONDITION
			),
			"Default Arts should evaluate their installation Conditions."
	)
	suite.assert_true(
			RunUnitState.create(1, fixture.unit) == null,
			"Invalid default Art loadouts should not create Run Unit state."
	)
	suite.assert_true(
			RunState.create(fixture.hero, 1) == null,
			"Invalid starting Unit loadouts should reject Run creation."
	)


static func _test_upgrade_cycle_validation(suite: TestSuite) -> void:
	var first: ArtDefinition = _create_minimal_active_art(&"first_variant")
	var second: ArtDefinition = _create_minimal_active_art(&"second_variant")
	first.upgraded_variant = second
	second.upgraded_variant = first

	var result: DefinitionValidationResult = DefinitionValidator.new().validate(first)
	suite.assert_true(
			result.has_code(GameEnums.DefinitionValidationCode.INVALID_REFERENCE),
			"Art upgrade cycles must be rejected."
	)
	first.upgraded_variant = null
	second.upgraded_variant = null


static func _test_upgrade_variant_validation(suite: TestSuite) -> void:
	var base_art: ArtDefinition = _create_minimal_active_art(&"upgrade_base")
	var invalid_variant: ArtDefinition = _create_minimal_active_art(
			&"invalid_upgrade"
	)
	invalid_variant.effects.clear()
	base_art.upgraded_variant = invalid_variant
	var result: DefinitionValidationResult = (
		DefinitionValidator.new().validate(base_art)
	)
	suite.assert_true(
			result.has_code(GameEnums.DefinitionValidationCode.MISSING_EFFECT),
			"Base Art validation should include every configured upgrade variant."
	)

	base_art.upgraded_variant = null
	var unit_definition: UnitDefinition = UnitDefinition.new()
	unit_definition.content_id = &"upgrade_unit"
	unit_definition.max_health = 5
	unit_definition.max_ap = 3
	unit_definition.slot_count = 1
	var run_unit: RunUnitState = RunUnitState.create(1, unit_definition)
	var service: ArtLoadoutService = ArtLoadoutService.new()
	suite.assert_true(
			service.install(run_unit, base_art, 0).succeeded(),
			"Valid base Arts should install before an upgrade is configured."
	)
	base_art.upgraded_variant = invalid_variant
	suite.assert_int_equal(
			GameEnums.ArtLoadoutCode.INVALID_ART,
			service.upgrade(run_unit, 0).code,
			"Upgrade execution should fully validate the resulting Art."
	)


static func _test_event_context_validation(suite: TestSuite) -> void:
	var invalid_effect: ShieldEffectDefinition = ShieldEffectDefinition.new()
	invalid_effect.target_source = (
		GameEnums.EffectTargetSource.EVENT_TARGET_UNIT
	)
	var missing_unit_trigger: TriggerDefinition = TriggerDefinition.new()
	missing_unit_trigger.event_kind = GameEnums.BattleEventKind.TURN_STARTED
	missing_unit_trigger.effects.append(invalid_effect)
	var missing_unit_result: DefinitionValidationResult = (
		DefinitionValidationResult.new()
	)
	missing_unit_trigger.validate_configuration(
			missing_unit_result,
			&"trigger"
	)
	suite.assert_false(
			missing_unit_result.is_valid(),
			"Turn events should reject effects that require event Units."
	)
	var removed_source_trigger: TriggerDefinition = TriggerDefinition.new()
	removed_source_trigger.event_kind = GameEnums.BattleEventKind.BUFF_REMOVED
	var removed_source_effect: ShieldEffectDefinition = (
		ShieldEffectDefinition.new()
	)
	removed_source_effect.target_source = (
		GameEnums.EffectTargetSource.EVENT_SOURCE_UNIT
	)
	removed_source_effect.flat_amount = 1
	removed_source_trigger.effects.append(removed_source_effect)
	var removed_source_result: DefinitionValidationResult = (
		DefinitionValidationResult.new()
	)
	removed_source_trigger.validate_configuration(
			removed_source_result,
			&"trigger"
	)
	suite.assert_false(
			removed_source_result.is_valid(),
			"Buff removal should reject dependencies on a non-guaranteed source."
	)

	var unit_relation: EventUnitRelationConditionDefinition = (
		EventUnitRelationConditionDefinition.new()
	)
	var actor_effect: ShieldEffectDefinition = ShieldEffectDefinition.new()
	actor_effect.target_source = GameEnums.EffectTargetSource.ACTOR
	actor_effect.flat_amount = 1
	var invalid_condition_trigger: TriggerDefinition = TriggerDefinition.new()
	invalid_condition_trigger.event_kind = (
		GameEnums.BattleEventKind.TURN_ENDED
	)
	invalid_condition_trigger.conditions.append(unit_relation)
	invalid_condition_trigger.effects.append(actor_effect)
	var invalid_condition_result: DefinitionValidationResult = (
		DefinitionValidationResult.new()
	)
	invalid_condition_trigger.validate_configuration(
			invalid_condition_result,
			&"trigger"
	)
	suite.assert_false(
			invalid_condition_result.is_valid(),
			"Turn events should reject Conditions that require event Units."
	)

	var side_relation: EventSideRelationConditionDefinition = (
		EventSideRelationConditionDefinition.new()
	)
	var valid_trigger: TriggerDefinition = TriggerDefinition.new()
	valid_trigger.event_kind = GameEnums.BattleEventKind.TURN_STARTED
	valid_trigger.conditions.append(side_relation)
	valid_trigger.effects.append(actor_effect)
	var valid_result: DefinitionValidationResult = (
		DefinitionValidationResult.new()
	)
	valid_trigger.validate_configuration(valid_result, &"trigger")
	suite.assert_true(
			valid_result.is_valid(),
			"Turn events should accept reusable event-side Conditions."
	)


static func _test_rule_contract_values(suite: TestSuite) -> void:
	var condition: TestConditionDefinition = TestConditionDefinition.new()
	var condition_result: ConditionResult = condition.evaluate(ConditionContext.new())
	suite.assert_true(condition_result.passed(), "Test conditions must return typed results.")

	var effect_result: EffectResult = EffectResult.success()
	suite.assert_true(effect_result.succeeded(), "Effect results must expose typed status.")

	var selection: TargetSelection = TargetSelection.new()
	selection.unit_instance_ids.append(1)
	selection.cells.append(Vector2i(2, 3))
	selection.targets_battle = true
	suite.assert_int_equal(3, selection.count(), "Target selection must count typed targets.")

	var coordinate: GridCoordinate = GridCoordinate.new(Vector2i(4, 5))
	suite.assert_vector_equal(
			Vector2i(4, 5),
			coordinate.value,
			"Grid coordinates must retain their Vector2i value."
	)


static func _test_definition_state_separation(suite: TestSuite) -> void:
	var fixture: CoreDataFixture = CoreDataFixture.create()

	var unit_state: UnitState = UnitState.create(
			1,
			fixture.unit,
			GameEnums.BattleSide.PLAYER
	)
	unit_state.current_health = 2
	unit_state.current_ap = 0
	unit_state.arts[0].current_cooldown = 3

	suite.assert_int_equal(
			12,
			fixture.unit.max_health,
			"Changing UnitState health must not change UnitDefinition."
	)
	suite.assert_int_equal(
			4,
			fixture.unit.max_ap,
			"Changing UnitState AP must not change UnitDefinition."
	)
	suite.assert_int_equal(
			0,
			fixture.active_art.cooldown,
			"Changing ArtState cooldown must not change ArtDefinition."
	)

	var run_state: RunState = RunState.create(fixture.hero, 321)
	run_state.gold = 50
	run_state.team[0].current_health = 4
	run_state.team[0].installed_arts.clear()
	run_state.relics.clear()

	suite.assert_int_equal(
			12,
			fixture.unit.max_health,
			"Changing RunUnitState must not change UnitDefinition."
	)
	suite.assert_int_equal(
			1,
			fixture.unit.default_arts.size(),
			"Run Art installation state must not share the Definition array."
	)
	suite.assert_int_equal(
			1,
			fixture.hero.starting_relics.size(),
			"Run relic state must not share the Hero Definition array."
	)

	var battle_grid: GridState = GridState.create(2, 2, fixture.terrain)
	var battle_state: BattleState = BattleState.create(battle_grid)
	var placement: BattlePlacementResult = BattlePlacementService.new().place_unit_definition(
			battle_state,
			fixture.unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	battle_state.phase = GameEnums.BattlePhase.PLAYER_TURN
	battle_state.round_number = 1
	suite.assert_true(placement.succeeded(), "Valid Battle Units must be placeable.")
	suite.assert_int_equal(
			1,
			battle_state.unit_count(),
			"BattleState must own Battle UnitState references."
	)
	suite.assert_false(unit_state.is_defeated(), "Positive health Units must remain active.")


static func _test_resource_round_trip(suite: TestSuite) -> void:
	var fixture: CoreDataFixture = CoreDataFixture.create()
	var save_error: Error = ResourceSaver.save(fixture.unit, TEST_RESOURCE_PATH)
	suite.assert_int_equal(
			OK,
			save_error,
			"Unit definitions must be serializable Godot Resources."
	)

	var loaded: UnitDefinition = ResourceLoader.load(TEST_RESOURCE_PATH) as UnitDefinition
	suite.assert_true(loaded != null, "Serialized Unit definitions must load with their type.")
	if loaded != null:
		suite.assert_int_equal(
				fixture.unit.max_health,
				loaded.max_health,
				"Serialized Unit definition values must survive a round trip."
		)
		suite.assert_int_equal(
				fixture.unit.default_arts.size(),
				loaded.default_arts.size(),
				"Serialized typed Resource references must survive a round trip."
		)

	loaded = null
	var remove_error: Error = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(TEST_RESOURCE_PATH)
	)
	suite.assert_int_equal(OK, remove_error, "Test Resources must be removed after use.")


static func _create_minimal_active_art(content_id: StringName) -> ArtDefinition:
	var art: ArtDefinition = ArtDefinition.new()
	art.content_id = content_id
	art.targeting = TargetingDefinition.new()
	art.effects.append(TestEffectDefinition.new())
	return art

class_name ArtRuleTest
extends RefCounted


static func run(suite: TestSuite) -> void:
	_test_definition_validation(suite)
	_test_target_resolution(suite)
	_test_line_of_sight(suite)
	_test_buff_stacking_and_attributes(suite)
	_test_condition_composition(suite)
	_test_art_loadout(suite)


static func _test_definition_validation(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var validator: DefinitionValidator = DefinitionValidator.new()
	var definitions: Array[DefinitionResource] = [
		fixture.strike,
		fixture.guard,
		fixture.focus,
		fixture.reactive_guard,
		fixture.attack_buff,
		fixture.player_definition,
	]
	for definition: DefinitionResource in definitions:
		suite.assert_true(
				validator.validate(definition).is_valid(),
				"Valid v3 definitions should pass validation."
		)
	var invalid_modifier: ModifierDefinition = ModifierDefinition.new()
	invalid_modifier.value = INF
	var invalid_buff: BuffDefinition = BuffDefinition.new()
	invalid_buff.content_id = &"invalid_modifier_buff"
	invalid_buff.modifiers.append(invalid_modifier)
	suite.assert_false(
			validator.validate(invalid_buff).is_valid(),
			"Non-finite modifier values should fail validation."
	)
	var invalid_move_art: ArtDefinition = ArtDefinition.new()
	invalid_move_art.content_id = &"invalid_move_art"
	invalid_move_art.targeting = fixture.guard.targeting
	var move_effect: MoveEffectDefinition = MoveEffectDefinition.new()
	move_effect.target_source = GameEnums.EffectTargetSource.ACTOR
	invalid_move_art.effects.append(move_effect)
	suite.assert_false(
			validator.validate(invalid_move_art).is_valid(),
			"Move Arts should require exactly one selected Cell."
	)
	var invalid_targeting: TargetingDefinition = TargetingDefinition.new()
	invalid_targeting.affected_offsets.append(Vector2i.ZERO)
	var targeting_result: DefinitionValidationResult = (
		DefinitionValidationResult.new()
	)
	invalid_targeting.validate_configuration(targeting_result, &"targeting")
	suite.assert_true(
			targeting_result.has_code(
					GameEnums.DefinitionValidationCode.INVALID_TARGETING
			),
			"Duplicate affected Cell offsets should fail validation."
	)


static func _test_target_resolution(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var resolver: BattleTargetResolver = BattleTargetResolver.new()
	var enemy_selection: TargetSelection = fixture.create_cell_selection(
			Vector2i(2, 1)
	)
	var context: BattleTargetingContext = BattleTargetingContext.create(
			fixture.battle,
			fixture.player_unit_id,
			enemy_selection
	)
	var accepted: TargetResolutionResult = resolver.resolve(
			fixture.strike.targeting,
			context,
			enemy_selection
	)
	suite.assert_true(accepted.is_valid, "Adjacent enemy Cells should be valid aims.")
	suite.assert_true(
			accepted.resolved_targets.hit_unit_ids.has(fixture.enemy_unit_id),
			"Spatial resolution should record matching Units in affected Cells."
	)

	var empty_selection: TargetSelection = fixture.create_cell_selection(
			Vector2i(1, 0)
	)
	var accepted_empty: TargetResolutionResult = resolver.resolve(
			fixture.strike.targeting,
			BattleTargetingContext.create(
					fixture.battle,
					fixture.player_unit_id,
					empty_selection
			),
			empty_selection
	)
	suite.assert_true(
			accepted_empty.is_valid,
			"Spatial targeting should allow valid empty aim Cells."
	)
	suite.assert_int_equal(
			0,
			accepted_empty.resolved_targets.hit_unit_ids.size(),
			"Empty aim Cells should resolve to zero Unit hits."
	)

	var duplicate_selection: TargetSelection = fixture.create_cell_selection(
			Vector2i(2, 1)
	)
	duplicate_selection.cells.append(Vector2i(2, 1))
	var rejected_duplicate: TargetResolutionResult = resolver.resolve(
			fixture.strike.targeting,
			BattleTargetingContext.create(
					fixture.battle,
					fixture.player_unit_id,
					duplicate_selection
			),
			duplicate_selection
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION,
			rejected_duplicate.failure_code,
			"Duplicate targets should be rejected."
	)

	var unit_targeting: TargetingDefinition = TargetingDefinition.new()
	unit_targeting.target_kind = GameEnums.TargetKind.UNIT
	unit_targeting.target_relation = GameEnums.TargetRelation.ENEMY
	unit_targeting.minimum_range = 0
	unit_targeting.maximum_range = 1
	var self_selection: TargetSelection = fixture.create_unit_selection(
			fixture.player_unit_id
	)
	var rejected_relation: TargetResolutionResult = resolver.resolve(
			unit_targeting,
			BattleTargetingContext.create(
					fixture.battle,
					fixture.player_unit_id,
					self_selection
			),
			self_selection
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.TARGET_RELATION_INVALID,
			rejected_relation.failure_code,
			"Direct enemy Unit targeting should reject the actor."
	)

	fixture.strike.targeting.affected_offsets.append(Vector2i(1, 1))
	var area_result: TargetResolutionResult = resolver.resolve(
			fixture.strike.targeting,
			BattleTargetingContext.create(
					fixture.battle,
					fixture.player_unit_id,
					empty_selection
			),
			empty_selection
	)
	suite.assert_true(
			area_result.resolved_targets.affected_cells.has(Vector2i(2, 1)),
			"Configured offsets should expand affected Cells from the aim Cell."
	)
	suite.assert_true(
			area_result.resolved_targets.hit_unit_ids.has(fixture.enemy_unit_id),
			"Expanded affected Cells should resolve matching Unit hits."
	)


static func _test_line_of_sight(suite: TestSuite) -> void:
	var terrain: TerrainDefinition = TerrainDefinition.new()
	terrain.content_id = &"line_ground"
	var wall: TerrainDefinition = TerrainDefinition.new()
	wall.content_id = &"line_wall"
	wall.blocks_line_of_sight = true
	var grid: GridState = GridState.create(3, 1, terrain)
	grid.set_terrain(Vector2i(1, 0), wall)
	suite.assert_false(
			GridLineOfSight.new().has_line_of_sight(
					grid,
					Vector2i.ZERO,
					Vector2i(2, 0)
			),
			"Blocking Terrain should interrupt line of sight."
	)
	suite.assert_true(
			GridLineOfSight.new().has_line_of_sight(
					grid,
					Vector2i.ZERO,
					Vector2i.ZERO
			),
			"A Cell should have line of sight to itself."
	)


static func _test_buff_stacking_and_attributes(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var unit: UnitState = fixture.battle.get_unit(fixture.player_unit_id)
	var calculator: AttributeCalculator = AttributeCalculator.new()
	var buff_service: BuffService = BuffService.new(calculator)
	var source: BattleSource = BattleSource.unit(unit.instance_id, unit.side)
	buff_service.apply_buff(unit, fixture.attack_buff, source)
	buff_service.apply_buff(unit, fixture.attack_buff, source)

	suite.assert_int_equal(
			2,
			unit.find_buff(fixture.attack_buff).stacks,
			"Add-stacks Buffs should respect their stack count."
	)
	suite.assert_int_equal(
			7,
			calculator.calculate(unit, GameEnums.AttributeType.BASE_ATTACK),
			"Buff stacks should contribute deterministic flat modifiers."
	)
	buff_service.advance_turn(unit)
	suite.assert_true(
			unit.find_buff(fixture.attack_buff) != null,
			"Buffs should remain until their duration expires."
	)
	buff_service.advance_turn(unit)
	suite.assert_true(
			unit.find_buff(fixture.attack_buff) == null,
			"Expired Buffs should be removed."
	)


static func _test_condition_composition(suite: TestSuite) -> void:
	var passing: TestConditionDefinition = TestConditionDefinition.new()
	var failing: FailingConditionDefinition = FailingConditionDefinition.new()
	var all_condition: AllConditionDefinition = AllConditionDefinition.new()
	all_condition.conditions.assign([passing, failing])
	var any_condition: AnyConditionDefinition = AnyConditionDefinition.new()
	any_condition.conditions.assign([failing, passing])
	var not_condition: NotConditionDefinition = NotConditionDefinition.new()
	not_condition.condition = failing
	var context: ConditionContext = ConditionContext.new()
	suite.assert_false(
			all_condition.evaluate(context).passed(),
			"All conditions should fail when one child fails."
	)
	suite.assert_true(
			any_condition.evaluate(context).passed(),
			"Any conditions should pass when one child passes."
	)
	suite.assert_true(
			not_condition.evaluate(context).passed(),
			"Not conditions should invert their child result."
	)


static func _test_art_loadout(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var unit_definition: UnitDefinition = UnitDefinition.new()
	unit_definition.content_id = &"loadout_unit"
	unit_definition.max_health = 5
	unit_definition.max_ap = 3
	unit_definition.slot_count = 1
	var run_unit: RunUnitState = RunUnitState.create(1, unit_definition)
	var service: ArtLoadoutService = ArtLoadoutService.new()
	var art: RunArtState = RunArtState.create(1, fixture.strike)
	var installed: ArtLoadoutResult = service.install(run_unit, art, 0)
	suite.assert_true(installed.succeeded(), "Valid Arts should install.")
	suite.assert_int_equal(
			GameEnums.ArtLoadoutCode.SLOT_OCCUPIED,
			service.install(
					run_unit,
					RunArtState.create(2, fixture.guard),
					0
			).code,
			"Occupied Art slots should reject installation."
	)
	var upgraded: ArtLoadoutResult = service.upgrade(run_unit, art, 0)
	suite.assert_true(upgraded.succeeded(), "Configured Art variants should upgrade.")
	suite.assert_true(
			art.definition == fixture.upgraded_strike,
			"Upgrades should replace the installed Definition reference."
	)
	suite.assert_true(
			service.remove(run_unit, 0).succeeded(),
			"Installed Arts should be removable."
	)

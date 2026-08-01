class_name BattleReadModelTest
extends RefCounted


static func run(suite: TestSuite) -> void:
	_test_model_is_detached_from_authoritative_battle(suite)
	_test_model_exposes_arts_buffs_and_terminal_state(suite)


static func _test_model_is_detached_from_authoritative_battle(
		suite: TestSuite
) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var service: BattleReadModelService = BattleReadModelService.new()
	var model: BattleReadModel = service.build(fixture.battle)
	suite.assert_true(model != null, "Battle UI should build a read model.")
	if model == null:
		return
	suite.assert_int_equal(
		5,
		model.grid_width,
		"Battle read models should expose Grid width."
	)
	suite.assert_int_equal(
		3,
		model.grid_height,
		"Battle read models should expose Grid height."
	)
	suite.assert_int_equal(
		2,
		model.units.size(),
		"Battle read models should expose all placed Units."
	)
	var player: BattleUnitReadModel = model.get_unit(fixture.player_unit_id)
	suite.assert_true(
		player != null,
		"Battle read models should expose Units by instance ID."
	)
	if player == null:
		return
	suite.assert_vector_equal(
		Vector2i(1, 1),
		player.coordinate,
		"Battle read models should copy authoritative Unit coordinates."
	)
	suite.assert_true(
		model.get_cell(Vector2i(1, 1)).has_unit(),
		"Battle read models should copy authoritative occupancy."
	)
	player.current_health = 999
	suite.assert_int_equal(
		10,
		fixture.battle.get_unit(fixture.player_unit_id).current_health,
		"Mutating a read model must not mutate authoritative Battle state."
	)
	fixture.action_service.execute(
		fixture.battle,
		MoveActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			fixture.player_unit_id,
			Vector2i(0, 1)
		)
	)
	suite.assert_vector_equal(
		Vector2i(1, 1),
		player.coordinate,
		"Existing read models should remain stable after Battle changes."
	)
	var refreshed: BattleReadModel = service.build(fixture.battle)
	suite.assert_vector_equal(
		Vector2i(0, 1),
		refreshed.get_unit(fixture.player_unit_id).coordinate,
		"A refreshed read model should expose the latest Battle state."
	)


static func _test_model_exposes_arts_buffs_and_terminal_state(
		suite: TestSuite
) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var focus_result: ActionExecutionResult = fixture.action_service.execute(
		fixture.battle,
		UseArtActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			fixture.player_unit_id,
			2,
			fixture.create_unit_selection(fixture.player_unit_id)
		)
	)
	suite.assert_true(
		focus_result.is_successful,
		"The fixture should apply a Buff before presentation."
	)
	var model: BattleReadModel = BattleReadModelService.new().build(
		fixture.battle
	)
	var player: BattleUnitReadModel = model.get_unit(fixture.player_unit_id)
	suite.assert_int_equal(
		3,
		player.arts.size(),
		"Battle read models should expose installed Arts."
	)
	suite.assert_int_equal(
		1,
		player.buffs.size(),
		"Battle read models should expose active Buffs."
	)
	suite.assert_true(
		player.get_art(0).display_name == fixture.strike.display_name,
		"Battle read models should preserve Art display data."
	)
	fixture.battle.phase = GameEnums.BattlePhase.VICTORY
	var terminal: BattleReadModel = BattleReadModelService.new().build(
		fixture.battle
	)
	suite.assert_true(
		terminal.is_terminal(),
		"Battle read models should expose terminal Battle phases."
	)

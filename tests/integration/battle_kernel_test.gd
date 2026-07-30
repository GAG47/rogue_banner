class_name BattleKernelTest
extends RefCounted


static func run(suite: TestSuite) -> void:
	_test_placement_and_ids(suite)
	_test_movement_and_ap(suite)
	_test_invalid_actions_are_atomic(suite)
	_test_turn_transitions_and_refresh(suite)
	_test_use_art_entry_is_non_committing(suite)
	_test_defeated_unit_cleanup(suite)


static func _test_placement_and_ids(suite: TestSuite) -> void:
	var fixture: BattleKernelFixture = BattleKernelFixture.create()
	fixture.grid.set_terrain(Vector2i(1, 0), fixture.blocked_terrain)

	var out_of_bounds: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i(-1, 0)
	)
	suite.assert_int_equal(
			GameEnums.BattlePlacementCode.OUT_OF_BOUNDS,
			out_of_bounds.code,
			"Out-of-bounds Unit placement must be rejected."
	)

	var blocked: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i(1, 0)
	)
	suite.assert_int_equal(
			GameEnums.BattlePlacementCode.TERRAIN_BLOCKED,
			blocked.code,
			"Blocking Terrain must reject Unit placement."
	)

	var player_placement: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	suite.assert_true(player_placement.succeeded(), "Run Units must enter Battle.")
	suite.assert_int_equal(
			1,
			player_placement.unit_id,
			"First successful Battle Unit ID must start at one."
	)

	var player: UnitState = fixture.battle.get_unit(player_placement.unit_id)
	suite.assert_int_equal(
			fixture.run_unit.instance_id,
			player.source_run_unit_id,
			"Battle Unit state must retain its source Run Unit ID."
	)
	suite.assert_not_same(
			fixture.run_unit,
			player,
			"Battle Unit state must be independent from Run Unit state."
	)
	player.current_health = 1
	player.arts[0].current_cooldown = 2
	suite.assert_int_equal(
			12,
			fixture.run_unit.current_health,
			"Battle health changes must not modify Run Unit state."
	)

	var duplicate_cell: BattlePlacementResult = (
			fixture.placement_service.place_unit_definition(
					fixture.battle,
					fixture.core.unit,
					GameEnums.BattleSide.ENEMY,
					Vector2i.ZERO
			)
	)
	suite.assert_int_equal(
			GameEnums.BattlePlacementCode.CELL_OCCUPIED,
			duplicate_cell.code,
			"Battle placement cannot overwrite an occupied Cell."
	)

	var enemy_placement: BattlePlacementResult = (
			fixture.placement_service.place_unit_definition(
					fixture.battle,
					fixture.core.unit,
					GameEnums.BattleSide.ENEMY,
					Vector2i(4, 0)
			)
	)
	suite.assert_int_equal(
			2,
			enemy_placement.unit_id,
			"Invalid placements must not consume Battle Unit IDs."
	)

	suite.assert_true(
			fixture.placement_service.remove_unit(
					fixture.battle,
					player_placement.unit_id
			).succeeded(),
			"Removing a Battle Unit must release its state and occupancy."
	)
	var replacement: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	suite.assert_int_equal(
			3,
			replacement.unit_id,
			"Removed Battle Unit IDs must never be reused."
	)


static func _test_movement_and_ap(suite: TestSuite) -> void:
	var fixture: BattleKernelFixture = BattleKernelFixture.create()
	fixture.grid.set_terrain(Vector2i(1, 1), fixture.difficult_terrain)
	var player: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i(0, 1)
	)
	fixture.placement_service.place_unit_definition(
			fixture.battle,
			fixture.core.unit,
			GameEnums.BattleSide.ENEMY,
			Vector2i(4, 1)
	)
	fixture.turn_service.start_battle(fixture.battle)

	var move: MoveActionRequest = MoveActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			player.unit_id,
			Vector2i(2, 1)
	)
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			move
	)
	suite.assert_true(result.is_successful, "A valid Move action must execute.")
	suite.assert_int_equal(
			3,
			result.ap_spent,
			"Move AP cost must sum entered Terrain costs."
	)
	suite.assert_int_equal(
			1,
			fixture.battle.get_unit(player.unit_id).current_ap,
			"Successful movement must spend AP exactly once."
	)
	var position: GridCoordinate = fixture.placement_service.get_unit_position(
			fixture.battle,
			player.unit_id
	)
	suite.assert_true(position != null, "Moved Units must remain placed.")
	if position != null:
		suite.assert_vector_equal(
				Vector2i(2, 1),
				position.value,
				"Move actions must update Grid occupancy."
		)


static func _test_invalid_actions_are_atomic(suite: TestSuite) -> void:
	var fixture: BattleKernelFixture = BattleKernelFixture.create()
	var player: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	var enemy: BattlePlacementResult = fixture.placement_service.place_unit_definition(
			fixture.battle,
			fixture.core.unit,
			GameEnums.BattleSide.ENEMY,
			Vector2i(2, 0)
	)
	fixture.turn_service.start_battle(fixture.battle)
	var player_state: UnitState = fixture.battle.get_unit(player.unit_id)

	var occupied_move: MoveActionRequest = MoveActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			player.unit_id,
			Vector2i(2, 0)
	)
	var occupied_result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			occupied_move
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.DESTINATION_OCCUPIED,
			occupied_result.failure_code,
			"Occupied Move destinations must be rejected."
	)
	suite.assert_int_equal(
			fixture.core.unit.max_ap,
			player_state.current_ap,
			"Rejected Move actions must not spend AP."
	)

	var wrong_actor: MoveActionRequest = MoveActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			enemy.unit_id,
			Vector2i(3, 0)
	)
	var wrong_actor_result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			wrong_actor
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.ACTOR_SIDE_MISMATCH,
			wrong_actor_result.failure_code,
			"Actions cannot control a Unit from the other side."
	)

	player_state.current_ap = 0
	var insufficient_move: MoveActionRequest = MoveActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			player.unit_id,
			Vector2i(1, 0)
	)
	var insufficient_result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			insufficient_move
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.INSUFFICIENT_AP,
			insufficient_result.failure_code,
			"Move actions must reject insufficient AP."
	)
	var position: GridCoordinate = fixture.placement_service.get_unit_position(
			fixture.battle,
			player.unit_id
	)
	if position != null:
		suite.assert_vector_equal(
				Vector2i.ZERO,
				position.value,
				"Rejected actions must not change Grid position."
		)
	suite.assert_int_equal(
			0,
			player_state.current_ap,
			"Rejected actions must preserve the existing AP value."
	)


static func _test_turn_transitions_and_refresh(suite: TestSuite) -> void:
	var fixture: BattleKernelFixture = BattleKernelFixture.create()
	var player: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	var enemy: BattlePlacementResult = fixture.placement_service.place_unit_definition(
			fixture.battle,
			fixture.core.unit,
			GameEnums.BattleSide.ENEMY,
			Vector2i(4, 0)
	)
	var player_state: UnitState = fixture.battle.get_unit(player.unit_id)
	var enemy_state: UnitState = fixture.battle.get_unit(enemy.unit_id)
	player_state.current_ap = 0
	enemy_state.current_ap = 0
	player_state.arts[0].current_cooldown = 2
	enemy_state.arts[0].current_cooldown = 1

	var start: TurnTransitionResult = fixture.turn_service.start_battle(fixture.battle)
	suite.assert_true(start.succeeded, "Battle setup must start the player turn.")
	suite.assert_int_equal(1, fixture.battle.round_number, "Battle must start at round one.")
	suite.assert_int_equal(
			fixture.core.unit.max_ap,
			player_state.current_ap,
			"Starting a side turn must refresh its living Units' AP."
	)
	suite.assert_int_equal(
			1,
			player_state.arts[0].current_cooldown,
			"Starting a side turn must advance its cooldowns."
	)
	suite.assert_int_equal(
			0,
			enemy_state.current_ap,
			"Inactive side Units must not refresh."
	)

	var wrong_end: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			EndTurnActionRequest.create(GameEnums.BattleSide.ENEMY)
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.WRONG_TURN,
			wrong_end.failure_code,
			"Only the active side may end its turn."
	)
	suite.assert_int_equal(
			GameEnums.BattlePhase.PLAYER_TURN,
			fixture.battle.phase,
			"Rejected End Turn actions must not change phase."
	)

	var player_end: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			EndTurnActionRequest.create(GameEnums.BattleSide.PLAYER)
	)
	suite.assert_true(player_end.is_successful, "Player End Turn must start enemy turn.")
	suite.assert_int_equal(
			GameEnums.BattlePhase.ENEMY_TURN,
			fixture.battle.phase,
			"Player End Turn must set enemy phase."
	)
	suite.assert_int_equal(
			fixture.core.unit.max_ap,
			enemy_state.current_ap,
			"Enemy turn start must refresh enemy AP."
	)
	suite.assert_int_equal(
			0,
			enemy_state.arts[0].current_cooldown,
			"Enemy turn start must advance enemy cooldowns."
	)

	var enemy_end: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			EndTurnActionRequest.create(GameEnums.BattleSide.ENEMY)
	)
	suite.assert_true(enemy_end.is_successful, "Enemy End Turn must start player turn.")
	suite.assert_int_equal(
			2,
			fixture.battle.round_number,
			"A completed enemy turn must advance the round."
	)
	suite.assert_int_equal(
			0,
			player_state.arts[0].current_cooldown,
			"The next player turn must advance player cooldowns."
	)


static func _test_use_art_entry_is_non_committing(suite: TestSuite) -> void:
	var fixture: BattleKernelFixture = BattleKernelFixture.create()
	var player: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	var enemy: BattlePlacementResult = fixture.placement_service.place_unit_definition(
			fixture.battle,
			fixture.core.unit,
			GameEnums.BattleSide.ENEMY,
			Vector2i(1, 0)
	)
	fixture.turn_service.start_battle(fixture.battle)

	var targets: TargetSelection = TargetSelection.new()
	targets.unit_instance_ids.append(enemy.unit_id)
	var request: UseArtActionRequest = UseArtActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			player.unit_id,
			0,
			targets
	)
	var player_state: UnitState = fixture.battle.get_unit(player.unit_id)
	var original_ap: int = player_state.current_ap
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			request
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.EFFECT_PLAN_INVALID,
			result.failure_code,
			"Unknown Effect definitions must fail during effect planning."
	)
	suite.assert_int_equal(
			original_ap,
			player_state.current_ap,
			"Failed Effect planning must not spend AP."
	)
	suite.assert_int_equal(
			0,
			player_state.arts[0].current_cooldown,
			"Failed Effect planning must not start cooldown."
	)


static func _test_defeated_unit_cleanup(suite: TestSuite) -> void:
	var fixture: BattleKernelFixture = BattleKernelFixture.create()
	var player: BattlePlacementResult = fixture.placement_service.place_run_unit(
			fixture.battle,
			fixture.run_unit,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	var enemy: BattlePlacementResult = fixture.placement_service.place_unit_definition(
			fixture.battle,
			fixture.core.unit,
			GameEnums.BattleSide.ENEMY,
			Vector2i(2, 0)
	)
	fixture.battle.get_unit(enemy.unit_id).current_health = 0

	var removed: Array[int] = fixture.placement_service.remove_defeated_units(
			fixture.battle
	)
	suite.assert_int_equal(1, removed.size(), "Defeated cleanup must remove defeated Units.")
	suite.assert_int_equal(
			enemy.unit_id,
			removed[0],
			"Defeated cleanup must report removed Battle Unit IDs."
	)
	suite.assert_int_equal(
			1,
			fixture.battle.unit_count(),
			"Defeated cleanup must preserve living Units."
	)
	suite.assert_true(
			fixture.placement_service.get_unit_position(
					fixture.battle,
					enemy.unit_id
			) == null,
			"Defeated cleanup must release Grid occupancy."
	)
	suite.assert_true(
			fixture.battle.get_unit(player.unit_id) != null,
			"Defeated cleanup must not remove living Units."
	)

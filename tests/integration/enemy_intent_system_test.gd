class_name EnemyIntentSystemTest
extends RefCounted


static func run(suite: TestSuite) -> void:
	_test_locked_intent_does_not_retarget(suite)
	_test_locked_cell_and_object_commitments(suite)
	_test_pattern_preview_tracks_forced_movement(suite)
	_test_blocked_move_does_not_cancel_art(suite)
	_test_fizzle_continues_and_terminal_stops(suite)
	_test_seeded_priority_is_deterministic(suite)
	_test_boss_phase_changes_on_next_generation(suite)
	_test_enemy_state_is_removed_with_unit(suite)


static func _test_locked_intent_does_not_retarget(
		suite: TestSuite
) -> void:
	var terrain: TerrainDefinition = _terrain(&"locked_ground")
	var player_definition: UnitDefinition = _unit(&"locked_player", 12, 5)
	var shot: ArtDefinition = _damage_art(
			&"locked_shot",
			GameEnums.TargetKind.UNIT,
			GameEnums.TargetRelation.ENEMY,
			1,
			3,
			2
	)
	var archer: EnemyDefinition = _enemy(
			&"locked_archer",
			_unit_with_art(&"locked_archer_unit", 8, 3, shot),
			_intent(
					&"locked_unit_intent",
					GameEnums.IntentKind.LOCKED,
					shot,
					GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
			)
	)
	var battle: BattleState = BattleState.create(
			GridState.create(7, 3, terrain),
			17
	)
	var placement: BattlePlacementService = BattlePlacementService.new()
	var first_player: BattlePlacementResult = placement.place_unit_definition(
			battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i(2, 1)
	)
	var second_player: BattlePlacementResult = placement.place_unit_definition(
			battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i(1, 2)
	)
	var enemy_result: BattlePlacementResult = placement.place_enemy_definition(
			battle,
			archer,
			Vector2i(5, 1)
	)
	var action_service: BattleActionService = BattleActionService.new()
	var flow: BattleFlowService = BattleFlowService.new(action_service)
	var start: BattleFlowResult = flow.start_battle(battle)
	suite.assert_true(start.succeeded, "Battle flow should start and generate Intents.")
	var plan: IntentPlan = battle.get_enemy_state(
			enemy_result.unit_id
	).current_intent
	suite.assert_true(plan != null, "The first player turn should expose an Intent.")
	suite.assert_int_equal(
			first_player.unit_id,
			plan.locked_targets.unit_instance_ids[0],
			"Locked Intents should retain the selected Unit identity."
	)

	var move: ActionExecutionResult = action_service.execute(
			battle,
			MoveActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					first_player.unit_id,
					Vector2i(0, 0)
			)
	)
	suite.assert_true(move.is_successful, "The locked target should be able to move.")
	var first_health: int = battle.get_unit(first_player.unit_id).current_health
	var second_health: int = battle.get_unit(second_player.unit_id).current_health
	var turn: BattleFlowResult = flow.end_player_turn(battle)
	suite.assert_true(turn.succeeded, "A disrupted Intent should not fail the turn.")
	suite.assert_int_equal(
			first_health,
			battle.get_unit(first_player.unit_id).current_health,
			"An out-of-range locked target should make the Art fizzle."
	)
	suite.assert_int_equal(
			second_health,
			battle.get_unit(second_player.unit_id).current_health,
			"A locked Intent must not retarget another valid player Unit."
	)
	suite.assert_true(
			turn.enemy_turn_result.executions[0].steps[0].status
			== GameEnums.IntentStepStatus.FIZZLED,
			"Battlefield invalidation should be reported as a normal fizzle."
	)


static func _test_pattern_preview_tracks_forced_movement(
		suite: TestSuite
) -> void:
	var terrain: TerrainDefinition = _terrain(&"pattern_ground")
	var push: ArtDefinition = _push_art(&"pattern_push")
	var player_definition: UnitDefinition = _unit_with_art(
			&"pattern_player",
			10,
			5,
			push
	)
	var sweep: ArtDefinition = _pattern_art(&"pattern_sweep")
	var pattern_intent: IntentDefinition = _intent(
			&"pattern_intent",
			GameEnums.IntentKind.PATTERN,
			sweep,
			GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
	)
	pattern_intent.direction_rule = GameEnums.IntentDirectionRule.TOWARD_TARGET
	var heavy: EnemyDefinition = _enemy(
			&"pattern_heavy",
			_unit_with_art(&"pattern_heavy_unit", 15, 4, sweep),
			pattern_intent
	)
	var battle: BattleState = BattleState.create(
			GridState.create(7, 3, terrain),
			21
	)
	var placement: BattlePlacementService = BattlePlacementService.new()
	var player_result: BattlePlacementResult = placement.place_unit_definition(
			battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i(3, 1)
	)
	var enemy_result: BattlePlacementResult = placement.place_enemy_definition(
			battle,
			heavy,
			Vector2i(4, 1)
	)
	var action_service: BattleActionService = BattleActionService.new()
	var flow: BattleFlowService = BattleFlowService.new(action_service)
	flow.start_battle(battle)
	var preview_service: IntentPreviewService = IntentPreviewService.new()
	var before: IntentPreview = preview_service.build_all(battle)[0]
	suite.assert_true(
			before.affected_cells.has(Vector2i(3, 1)),
			"Pattern preview should resolve from the enemy's current position."
	)

	var selection: TargetSelection = TargetSelection.new()
	selection.cells.append(Vector2i(4, 1))
	var pushed: ActionExecutionResult = action_service.execute(
			battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					player_result.unit_id,
					0,
					selection
			)
	)
	suite.assert_true(pushed.is_successful, "Generic forced movement should execute.")
	suite.assert_vector_equal(
			Vector2i(5, 1),
			battle.grid.find_occupant(
					GameEnums.GridOccupantKind.UNIT,
					enemy_result.unit_id
			).value,
			"Forced movement should update authoritative Grid occupancy."
	)
	var after: IntentPreview = preview_service.build_all(battle)[0]
	suite.assert_true(
			after.affected_cells.has(Vector2i(4, 1)),
			"Pattern danger Cells should follow the displaced enemy."
	)
	suite.assert_false(
			after.affected_cells.has(Vector2i(1, 1)),
			"Pattern preview must not retain stale absolute Cells."
	)


static func _test_locked_cell_and_object_commitments(
		suite: TestSuite
) -> void:
	var terrain: TerrainDefinition = _terrain(&"locked_spatial_ground")
	var player_definition: UnitDefinition = _unit(&"locked_spatial_player", 10, 4)
	var cell_art: ArtDefinition = _damage_art(
			&"locked_cell_art",
			GameEnums.TargetKind.CELL,
			GameEnums.TargetRelation.ENEMY,
			1,
			5,
			2
	)
	var cell_intent: IntentDefinition = _intent(
			&"locked_cell_intent",
			GameEnums.IntentKind.LOCKED,
			cell_art,
			GameEnums.IntentTargetRule.NEAREST_OPPONENT_CELL
	)
	var cell_enemy: EnemyDefinition = _enemy(
			&"locked_cell_enemy",
			_unit_with_art(&"locked_cell_unit", 7, 3, cell_art),
			cell_intent
	)
	var cell_battle: BattleState = BattleState.create(
			GridState.create(6, 1, terrain),
			44
	)
	var placement: BattlePlacementService = BattlePlacementService.new()
	var player_result: BattlePlacementResult = placement.place_unit_definition(
			cell_battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i(1, 0)
	)
	var enemy_result: BattlePlacementResult = placement.place_enemy_definition(
			cell_battle,
			cell_enemy,
			Vector2i(4, 0)
	)
	var action_service: BattleActionService = BattleActionService.new()
	var flow: BattleFlowService = BattleFlowService.new(action_service)
	flow.start_battle(cell_battle)
	var cell_plan: IntentPlan = cell_battle.get_enemy_state(
			enemy_result.unit_id
	).current_intent
	suite.assert_vector_equal(
			Vector2i(1, 0),
			cell_plan.locked_targets.cells[0],
			"Locked Cell Intents should save the generated coordinate."
	)
	action_service.execute(
			cell_battle,
			MoveActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					player_result.unit_id,
					Vector2i.ZERO
			)
	)
	var health_before: int = cell_battle.get_unit(
			player_result.unit_id
	).current_health
	var cell_turn: BattleFlowResult = flow.end_player_turn(cell_battle)
	suite.assert_true(
			cell_turn.enemy_turn_result.executions[0].steps[0].status
			== GameEnums.IntentStepStatus.EXECUTED,
			"Locked empty Cells should still execute the configured Art."
	)
	suite.assert_int_equal(
			health_before,
			cell_battle.get_unit(player_result.unit_id).current_health,
			"Leaving a locked Cell should allow its Unit hit to miss."
	)

	var object_art: ArtDefinition = _damage_art(
			&"locked_object_art",
			GameEnums.TargetKind.TERRAIN_OBJECT,
			GameEnums.TargetRelation.NEUTRAL,
			1,
			5,
			1
	)
	var object_intent: IntentDefinition = _intent(
			&"locked_object_intent",
			GameEnums.IntentKind.LOCKED,
			object_art,
			GameEnums.IntentTargetRule.NEAREST_SCENE_OBJECT
	)
	var object_enemy: EnemyDefinition = _enemy(
			&"locked_object_enemy",
			_unit_with_art(&"locked_object_unit", 7, 3, object_art),
			object_intent
	)
	var object_grid: GridState = GridState.create(6, 1, terrain)
	object_grid.place_occupant(GridOccupant.scene_object(9), Vector2i(2, 0))
	var object_battle: BattleState = BattleState.create(object_grid, 45)
	placement.place_unit_definition(
			object_battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	var object_enemy_result: BattlePlacementResult = (
		placement.place_enemy_definition(
				object_battle,
				object_enemy,
				Vector2i(4, 0)
		)
	)
	var object_flow: BattleFlowService = BattleFlowService.new()
	object_flow.start_battle(object_battle)
	var object_plan: IntentPlan = object_battle.get_enemy_state(
			object_enemy_result.unit_id
	).current_intent
	suite.assert_int_equal(
			9,
			object_plan.locked_targets.terrain_object_instance_ids[0],
			"Locked object Intents should save scene-object identity."
	)
	object_battle.grid.remove_occupant(
			GameEnums.GridOccupantKind.SCENE_OBJECT,
			9
	)
	var object_turn: BattleFlowResult = object_flow.end_player_turn(
			object_battle
	)
	suite.assert_true(
			object_turn.enemy_turn_result.executions[0].steps[0].status
			== GameEnums.IntentStepStatus.FIZZLED,
			"A removed locked object should fizzle without selecting a replacement."
	)


static func _test_blocked_move_does_not_cancel_art(
		suite: TestSuite
) -> void:
	var terrain: TerrainDefinition = _terrain(&"blocked_move_ground")
	var player_definition: UnitDefinition = _unit(&"blocked_move_player", 15, 5)
	var shot: ArtDefinition = _damage_art(
			&"blocked_move_shot",
			GameEnums.TargetKind.UNIT,
			GameEnums.TargetRelation.ENEMY,
			1,
			6,
			2
	)
	var moving_intent: IntentDefinition = _intent(
			&"blocked_move_intent",
			GameEnums.IntentKind.LOCKED,
			shot,
			GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
	)
	moving_intent.movement_rule = GameEnums.IntentMovementRule.TOWARD_TARGET
	moving_intent.sequence = GameEnums.IntentSequence.MOVE_THEN_ART
	var enemy: EnemyDefinition = _enemy(
			&"blocked_move_enemy",
			_unit_with_art(&"blocked_move_enemy_unit", 9, 4, shot),
			moving_intent
	)
	var battle: BattleState = BattleState.create(
			GridState.create(7, 1, terrain),
			33
	)
	var placement: BattlePlacementService = BattlePlacementService.new()
	var player_result: BattlePlacementResult = placement.place_unit_definition(
			battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	var enemy_result: BattlePlacementResult = placement.place_enemy_definition(
			battle,
			enemy,
			Vector2i(5, 0)
	)
	var action_service: BattleActionService = BattleActionService.new()
	var flow: BattleFlowService = BattleFlowService.new(action_service)
	flow.start_battle(battle)
	var plan: IntentPlan = battle.get_enemy_state(
			enemy_result.unit_id
	).current_intent
	suite.assert_true(
			plan.has_move_destination,
			"Move-before-Art Intents should publish a fixed destination."
	)
	var occupy_destination: ActionExecutionResult = action_service.execute(
			battle,
			MoveActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					player_result.unit_id,
					plan.move_destination
			)
	)
	suite.assert_true(
			occupy_destination.is_successful,
			"The player should be able to occupy the published destination."
	)
	var health_before: int = battle.get_unit(player_result.unit_id).current_health
	var turn: BattleFlowResult = flow.end_player_turn(battle)
	var execution: IntentExecutionResult = turn.enemy_turn_result.executions[0]
	suite.assert_true(turn.succeeded, "A blocked move should remain a normal turn.")
	suite.assert_true(
			execution.steps[0].status == GameEnums.IntentStepStatus.FIZZLED,
			"The occupied movement destination should fizzle without replanning."
	)
	suite.assert_true(
			execution.steps[1].status == GameEnums.IntentStepStatus.EXECUTED,
			"A later Art should still execute when legal from the current Cell."
	)
	suite.assert_int_equal(
			health_before - 2,
			battle.get_unit(player_result.unit_id).current_health,
			"Enemy Arts should use the existing damage action pipeline."
	)


static func _test_seeded_priority_is_deterministic(
		suite: TestSuite
) -> void:
	var first_battle: BattleState = _priority_battle(808)
	var second_battle: BattleState = _priority_battle(808)
	var first_flow: BattleFlowService = BattleFlowService.new()
	var second_flow: BattleFlowService = BattleFlowService.new()
	first_flow.start_battle(first_battle)
	second_flow.start_battle(second_battle)
	var first_plan: IntentPlan = first_battle.get_enemy_states()[0].current_intent
	var second_plan: IntentPlan = second_battle.get_enemy_states()[0].current_intent
	suite.assert_true(
			first_plan != null and second_plan != null,
			"Priority policies should produce eligible plans."
	)
	suite.assert_true(
			first_plan.definition.content_id == second_plan.definition.content_id,
			"Equal seed and Battle state should choose the same weighted Intent."
	)


static func _test_fizzle_continues_and_terminal_stops(
		suite: TestSuite
) -> void:
	var terrain: TerrainDefinition = _terrain(&"continuation_ground")
	var kill_art: ArtDefinition = _damage_art(
			&"continuation_kill",
			GameEnums.TargetKind.CELL,
			GameEnums.TargetRelation.ENEMY,
			1,
			1,
			99
	)
	var player_definition: UnitDefinition = _unit_with_art(
			&"continuation_player",
			12,
			4,
			kill_art
	)
	var blessing: ArtDefinition = _shield_art(&"continuation_blessing")
	var priest_intent: IntentDefinition = _intent(
			&"continuation_priest_intent",
			GameEnums.IntentKind.ENHANCE,
			blessing,
			GameEnums.IntentTargetRule.LOWEST_HEALTH_ALLY_UNIT
	)
	var priest: EnemyDefinition = _enemy(
			&"continuation_priest",
			_unit_with_art(&"continuation_priest_unit", 8, 3, blessing),
			priest_intent
	)
	var shot: ArtDefinition = _damage_art(
			&"continuation_shot",
			GameEnums.TargetKind.UNIT,
			GameEnums.TargetRelation.ENEMY,
			1,
			6,
			2
	)
	var archer: EnemyDefinition = _enemy(
			&"continuation_archer",
			_unit_with_art(&"continuation_archer_unit", 7, 3, shot),
			_intent(
					&"continuation_archer_intent",
					GameEnums.IntentKind.LOCKED,
					shot,
					GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
			)
	)
	var battle: BattleState = BattleState.create(
			GridState.create(7, 1, terrain),
			52
	)
	var placement: BattlePlacementService = BattlePlacementService.new()
	var player: BattlePlacementResult = placement.place_unit_definition(
			battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	placement.place_enemy_definition(battle, priest, Vector2i(4, 0))
	var doomed_ally: BattlePlacementResult = placement.place_unit_definition(
			battle,
			_unit(&"continuation_doomed_ally", 3, 2),
			GameEnums.BattleSide.ENEMY,
			Vector2i(1, 0)
	)
	placement.place_enemy_definition(battle, archer, Vector2i(6, 0))
	var action_service: BattleActionService = BattleActionService.new()
	var flow: BattleFlowService = BattleFlowService.new(action_service)
	flow.start_battle(battle)
	suite.assert_int_equal(
			doomed_ally.unit_id,
			battle.get_enemy_states()[0].current_intent.locked_targets.unit_instance_ids[0],
			"Enhance Intents should lock the selected allied Unit."
	)
	var kill_selection: TargetSelection = TargetSelection.new()
	kill_selection.cells.append(Vector2i(1, 0))
	action_service.execute(
			battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					player.unit_id,
					0,
					kill_selection
			)
	)
	var player_health: int = battle.get_unit(player.unit_id).current_health
	var turn: BattleFlowResult = flow.end_player_turn(battle)
	suite.assert_true(
			turn.succeeded,
			"One fizzled enemy should not stop later enemy Intents."
	)
	suite.assert_int_equal(
			2,
			turn.enemy_turn_result.executions.size(),
			"Only surviving configured enemies should receive execution attempts."
	)
	suite.assert_true(
			turn.enemy_turn_result.executions[0].steps[0].status
			== GameEnums.IntentStepStatus.FIZZLED,
			"An Enhance target defeated during the player turn should fizzle."
	)
	suite.assert_true(
			turn.enemy_turn_result.executions[1].steps[0].status
			== GameEnums.IntentStepStatus.EXECUTED,
			"Later enemies should continue after a normal fizzle."
	)
	suite.assert_int_equal(
			player_health - 2,
			battle.get_unit(player.unit_id).current_health,
			"The later enemy should resolve its published attack."
	)

	var terminal_player: UnitDefinition = _unit(
			&"terminal_player",
			1,
			2
	)
	var terminal_battle: BattleState = BattleState.create(
			GridState.create(5, 1, terrain),
			53
	)
	placement.place_unit_definition(
			terminal_battle,
			terminal_player,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	var first_archer: EnemyDefinition = _enemy(
			&"terminal_first_archer",
			_unit_with_art(&"terminal_first_unit", 5, 2, shot),
			_intent(
					&"terminal_first_intent",
					GameEnums.IntentKind.LOCKED,
					shot,
					GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
			)
	)
	var second_archer: EnemyDefinition = _enemy(
			&"terminal_second_archer",
			_unit_with_art(&"terminal_second_unit", 5, 2, shot),
			_intent(
					&"terminal_second_intent",
					GameEnums.IntentKind.LOCKED,
					shot,
					GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
			)
	)
	placement.place_enemy_definition(
			terminal_battle,
			first_archer,
			Vector2i(2, 0)
	)
	placement.place_enemy_definition(
			terminal_battle,
			second_archer,
			Vector2i(3, 0)
	)
	var terminal_flow: BattleFlowService = BattleFlowService.new()
	terminal_flow.start_battle(terminal_battle)
	var terminal_turn: BattleFlowResult = terminal_flow.end_player_turn(
			terminal_battle
	)
	suite.assert_true(
			terminal_battle.phase == GameEnums.BattlePhase.FAILURE,
			"Enemy damage should resolve terminal Battle failure immediately."
	)
	suite.assert_int_equal(
			1,
			terminal_turn.enemy_turn_result.executions.size(),
			"Terminal resolution should stop all remaining enemy Intents."
	)


static func _test_boss_phase_changes_on_next_generation(
		suite: TestSuite
) -> void:
	var terrain: TerrainDefinition = _terrain(&"phase_ground")
	var player_definition: UnitDefinition = _unit(&"phase_player", 20, 5)
	var normal_art: ArtDefinition = _damage_art(
			&"phase_normal_art",
			GameEnums.TargetKind.UNIT,
			GameEnums.TargetRelation.ENEMY,
			1,
			5,
			1
	)
	var phase_art: ArtDefinition = _damage_art(
			&"phase_changed_art",
			GameEnums.TargetKind.UNIT,
			GameEnums.TargetRelation.ENEMY,
			1,
			5,
			1
	)
	var boss_unit: UnitDefinition = _unit_with_arts(
			&"phase_boss_unit",
			20,
			4,
			[normal_art, phase_art]
	)
	var normal_intent: IntentDefinition = _intent(
			&"phase_normal_intent",
			GameEnums.IntentKind.LOCKED,
			normal_art,
			GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
	)
	var changed_intent: IntentDefinition = _intent(
			&"phase_changed_intent",
			GameEnums.IntentKind.LOCKED,
			phase_art,
			GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
	)
	var boss: EnemyDefinition = EnemyDefinition.new()
	boss.content_id = &"phase_boss"
	boss.unit_definition = boss_unit
	boss.rank = GameEnums.EnemyRank.BOSS
	boss.available_intents.assign([normal_intent, changed_intent])
	boss.default_decision = _fixed_policy(normal_intent)
	var phase: EnemyPhaseDefinition = EnemyPhaseDefinition.new()
	phase.phase_id = &"wounded"
	phase.priority = 10
	var health_condition: UnitHealthRatioConditionDefinition = (
		UnitHealthRatioConditionDefinition.new()
	)
	health_condition.threshold = 0.5
	phase.entry_conditions.append(health_condition)
	phase.decision_policy = _fixed_policy(changed_intent)
	boss.phases.append(phase)

	var battle: BattleState = BattleState.create(
			GridState.create(6, 1, terrain),
			99
	)
	var placement: BattlePlacementService = BattlePlacementService.new()
	placement.place_unit_definition(
			battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	var boss_result: BattlePlacementResult = placement.place_enemy_definition(
			battle,
			boss,
			Vector2i(4, 0)
	)
	var flow: BattleFlowService = BattleFlowService.new()
	flow.start_battle(battle)
	var state: EnemyState = battle.get_enemy_state(boss_result.unit_id)
	suite.assert_true(
			state.current_intent.definition == normal_intent,
			"Full-health Bosses should publish the default-phase Intent."
	)
	battle.get_unit(boss_result.unit_id).current_health = 10
	suite.assert_true(
			state.current_intent.definition == normal_intent,
			"Crossing a phase threshold must not replace the published Intent."
	)
	flow.end_player_turn(battle)
	state = battle.get_enemy_state(boss_result.unit_id)
	suite.assert_true(
			state.current_phase_id == &"wounded",
			"Boss phases should change at the next Intent generation boundary."
	)
	suite.assert_true(
			state.current_intent.definition == changed_intent,
			"The next published Intent should use the selected Boss phase policy."
	)


static func _test_enemy_state_is_removed_with_unit(suite: TestSuite) -> void:
	var battle: BattleState = _priority_battle(12)
	var enemy_id: int = battle.get_enemy_states()[0].unit_instance_id
	var removal: BattlePlacementResult = BattlePlacementService.new().remove_unit(
			battle,
			enemy_id
	)
	suite.assert_true(removal.succeeded(), "Enemy Unit removal should succeed.")
	suite.assert_true(
			battle.get_enemy_state(enemy_id) == null,
			"Enemy runtime state and its Intent must share Unit cleanup."
	)


static func _priority_battle(seed: int) -> BattleState:
	var terrain: TerrainDefinition = _terrain(&"priority_ground")
	var player_definition: UnitDefinition = _unit(&"priority_player", 10, 4)
	var first_art: ArtDefinition = _damage_art(
			&"priority_first_art",
			GameEnums.TargetKind.UNIT,
			GameEnums.TargetRelation.ENEMY,
			1,
			5,
			1
	)
	var second_art: ArtDefinition = _damage_art(
			&"priority_second_art",
			GameEnums.TargetKind.UNIT,
			GameEnums.TargetRelation.ENEMY,
			1,
			5,
			1
	)
	var first_intent: IntentDefinition = _intent(
			&"priority_first",
			GameEnums.IntentKind.LOCKED,
			first_art,
			GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
	)
	var second_intent: IntentDefinition = _intent(
			&"priority_second",
			GameEnums.IntentKind.LOCKED,
			second_art,
			GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
	)
	var policy: PriorityDecisionDefinition = PriorityDecisionDefinition.new()
	var first_candidate: IntentCandidateDefinition = (
		IntentCandidateDefinition.new()
	)
	first_candidate.intent = first_intent
	first_candidate.priority = 2
	first_candidate.weight = 1.0
	var second_candidate: IntentCandidateDefinition = (
		IntentCandidateDefinition.new()
	)
	second_candidate.intent = second_intent
	second_candidate.priority = 2
	second_candidate.weight = 3.0
	policy.candidates.assign([first_candidate, second_candidate])
	var enemy: EnemyDefinition = EnemyDefinition.new()
	enemy.content_id = &"priority_enemy"
	enemy.unit_definition = _unit_with_arts(
			&"priority_enemy_unit",
			8,
			4,
			[first_art, second_art]
	)
	enemy.available_intents.assign([first_intent, second_intent])
	enemy.default_decision = policy
	var battle: BattleState = BattleState.create(
			GridState.create(6, 1, terrain),
			seed
	)
	var placement: BattlePlacementService = BattlePlacementService.new()
	placement.place_unit_definition(
			battle,
			player_definition,
			GameEnums.BattleSide.PLAYER,
			Vector2i.ZERO
	)
	placement.place_enemy_definition(battle, enemy, Vector2i(4, 0))
	return battle


static func _terrain(content_id: StringName) -> TerrainDefinition:
	var terrain: TerrainDefinition = TerrainDefinition.new()
	terrain.content_id = content_id
	return terrain


static func _unit(
		content_id: StringName,
		health: int,
		ap: int
) -> UnitDefinition:
	var unit: UnitDefinition = UnitDefinition.new()
	unit.content_id = content_id
	unit.max_health = health
	unit.max_ap = ap
	return unit


static func _unit_with_art(
		content_id: StringName,
		health: int,
		ap: int,
		art: ArtDefinition
) -> UnitDefinition:
	return _unit_with_arts(content_id, health, ap, [art])


static func _unit_with_arts(
		content_id: StringName,
		health: int,
		ap: int,
		arts: Array[ArtDefinition]
) -> UnitDefinition:
	var unit: UnitDefinition = _unit(content_id, health, ap)
	unit.slot_count = arts.size()
	unit.default_arts.assign(arts)
	return unit


static func _damage_art(
		content_id: StringName,
		target_kind: GameEnums.TargetKind,
		relation: GameEnums.TargetRelation,
		minimum_range: int,
		maximum_range: int,
		damage: int
) -> ArtDefinition:
	var targeting: TargetingDefinition = TargetingDefinition.new()
	targeting.target_kind = target_kind
	targeting.target_relation = relation
	targeting.minimum_range = minimum_range
	targeting.maximum_range = maximum_range
	var effect: DamageEffectDefinition = DamageEffectDefinition.new()
	effect.flat_amount = damage
	effect.attribute_multiplier = 0.0
	var art: ArtDefinition = ArtDefinition.new()
	art.content_id = content_id
	art.ap_cost = 1
	art.targeting = targeting
	art.effects.append(effect)
	return art


static func _pattern_art(content_id: StringName) -> ArtDefinition:
	var art: ArtDefinition = _damage_art(
			content_id,
			GameEnums.TargetKind.CELL,
			GameEnums.TargetRelation.ENEMY,
			1,
			1,
			2
	)
	art.targeting.affected_offsets.assign([
		Vector2i.ZERO,
		Vector2i.RIGHT,
		Vector2i(2, 0),
	])
	return art


static func _shield_art(content_id: StringName) -> ArtDefinition:
	var targeting: TargetingDefinition = TargetingDefinition.new()
	targeting.target_kind = GameEnums.TargetKind.UNIT
	targeting.target_relation = GameEnums.TargetRelation.ALLY
	targeting.minimum_range = 1
	targeting.maximum_range = 6
	var shield: ShieldEffectDefinition = ShieldEffectDefinition.new()
	shield.flat_amount = 2
	shield.attribute_multiplier = 0.0
	var art: ArtDefinition = ArtDefinition.new()
	art.content_id = content_id
	art.ap_cost = 1
	art.targeting = targeting
	art.effects.append(shield)
	return art


static func _push_art(content_id: StringName) -> ArtDefinition:
	var targeting: TargetingDefinition = TargetingDefinition.new()
	targeting.target_kind = GameEnums.TargetKind.CELL
	targeting.target_relation = GameEnums.TargetRelation.ENEMY
	targeting.minimum_range = 1
	targeting.maximum_range = 1
	var push: ForcedMovementEffectDefinition = (
		ForcedMovementEffectDefinition.new()
	)
	push.distance = 1
	var art: ArtDefinition = ArtDefinition.new()
	art.content_id = content_id
	art.ap_cost = 1
	art.targeting = targeting
	art.effects.append(push)
	return art


static func _intent(
		content_id: StringName,
		kind: GameEnums.IntentKind,
		art: ArtDefinition,
		target_rule: GameEnums.IntentTargetRule
) -> IntentDefinition:
	var intent: IntentDefinition = IntentDefinition.new()
	intent.content_id = content_id
	intent.kind = kind
	intent.art = art
	intent.target_rule = target_rule
	return intent


static func _enemy(
		content_id: StringName,
		unit: UnitDefinition,
		intent: IntentDefinition
) -> EnemyDefinition:
	var enemy: EnemyDefinition = EnemyDefinition.new()
	enemy.content_id = content_id
	enemy.unit_definition = unit
	enemy.available_intents.append(intent)
	enemy.default_decision = _fixed_policy(intent)
	return enemy


static func _fixed_policy(
		intent: IntentDefinition
) -> FixedCycleDecisionDefinition:
	var policy: FixedCycleDecisionDefinition = (
		FixedCycleDecisionDefinition.new()
	)
	policy.sequence.append(intent)
	return policy

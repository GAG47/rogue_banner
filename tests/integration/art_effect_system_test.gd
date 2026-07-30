class_name ArtEffectSystemTest
extends RefCounted


static func run(suite: TestSuite) -> void:
	_test_strike_execution(suite)
	_test_empty_spatial_attack(suite)
	_test_hit_requirement(suite)
	_test_invalid_target_is_atomic(suite)
	_test_shield_and_cooldown(suite)
	_test_passive_trigger(suite)
	_test_buff_changes_art_damage(suite)
	_test_buff_expiry_event(suite)
	_test_common_effect_execution(suite)
	_test_failed_condition_is_atomic(suite)
	_test_defeat_and_victory(suite)


static func _test_strike_execution(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var request: UseArtActionRequest = UseArtActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			fixture.player_unit_id,
			0,
			fixture.create_cell_selection(Vector2i(2, 1))
	)
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			request
	)
	var player: UnitState = fixture.battle.get_unit(fixture.player_unit_id)
	var enemy: UnitState = fixture.battle.get_unit(fixture.enemy_unit_id)
	suite.assert_true(result.is_successful, "Valid strikes should execute.")
	suite.assert_int_equal(3, player.current_ap, "Strikes should spend configured AP.")
	suite.assert_int_equal(
			1,
			player.arts[0].current_cooldown,
			"Strikes should start configured cooldown."
	)
	suite.assert_int_equal(4, enemy.current_health, "Attack scaling should apply damage.")
	suite.assert_true(
			result.events[0] is DamageAppliedEvent,
			"Damage should publish a typed event first."
	)
	suite.assert_true(
			result.events[1] is ArtUsedEvent,
			"Completed Art use should publish a typed event."
	)


static func _test_empty_spatial_attack(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var player: UnitState = fixture.battle.get_unit(fixture.player_unit_id)
	var enemy: UnitState = fixture.battle.get_unit(fixture.enemy_unit_id)
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					0,
					fixture.create_cell_selection(Vector2i(1, 0))
			)
	)
	suite.assert_true(
			result.is_successful,
			"Spatial attacks should execute against valid empty Cells."
	)
	suite.assert_int_equal(
			3,
			player.current_ap,
			"Empty spatial attacks should still spend their AP."
	)
	suite.assert_int_equal(
			1,
			player.arts[0].current_cooldown,
			"Empty spatial attacks should still start cooldown."
	)
	suite.assert_int_equal(
			7,
			enemy.current_health,
			"Empty spatial attacks should resolve without Unit damage."
	)
	suite.assert_int_equal(
			1,
			result.events.size(),
			"Empty spatial attacks should only publish Art use by default."
	)
	suite.assert_true(
			result.events[0] is ArtUsedEvent,
			"Empty spatial attacks should still publish Art use."
	)


static func _test_hit_requirement(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var hit_requirement: HitRequirementConditionDefinition = (
		HitRequirementConditionDefinition.new()
	)
	hit_requirement.hit_target_kind = GameEnums.HitTargetKind.UNIT
	fixture.strike.use_conditions.append(hit_requirement)
	var player: UnitState = fixture.battle.get_unit(fixture.player_unit_id)
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					0,
					fixture.create_cell_selection(Vector2i(1, 0))
			)
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.CONDITION_FAILED,
			result.failure_code,
			"Explicit hit requirements should reject zero-hit attacks."
	)
	suite.assert_int_equal(
			5,
			player.current_ap,
			"Failed hit requirements should not spend AP."
	)
	suite.assert_int_equal(
			0,
			player.arts[0].current_cooldown,
			"Failed hit requirements should not start cooldown."
	)
	var hit_result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					0,
					fixture.create_cell_selection(Vector2i(2, 1))
			)
	)
	suite.assert_true(
			hit_result.is_successful,
			"Explicit hit requirements should accept matching resolved hits."
	)
	suite.assert_int_equal(
			4,
			fixture.battle.get_unit(
					fixture.enemy_unit_id
			).current_health,
			"Accepted hit requirements should continue to effect execution."
	)


static func _test_invalid_target_is_atomic(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var player: UnitState = fixture.battle.get_unit(fixture.player_unit_id)
	var initial_ap: int = player.current_ap
	var request: UseArtActionRequest = UseArtActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			fixture.player_unit_id,
			0,
			fixture.create_cell_selection(Vector2i(4, 1))
	)
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			request
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.TARGET_OUT_OF_RANGE,
			result.failure_code,
			"Out-of-range aim Cells should be rejected."
	)
	suite.assert_int_equal(
			initial_ap,
			player.current_ap,
			"Rejected targeting should not spend AP."
	)
	suite.assert_int_equal(
			0,
			player.arts[0].current_cooldown,
			"Rejected targeting should not start cooldown."
	)


static func _test_shield_and_cooldown(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var self_selection: TargetSelection = fixture.create_unit_selection(
			fixture.player_unit_id
	)
	var request: UseArtActionRequest = UseArtActionRequest.create(
			GameEnums.BattleSide.PLAYER,
			fixture.player_unit_id,
			1,
			self_selection
	)
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			request
	)
	var player: UnitState = fixture.battle.get_unit(fixture.player_unit_id)
	suite.assert_true(result.is_successful, "Self shield Arts should execute.")
	suite.assert_int_equal(3, player.current_shield, "Shield effects should add shield.")
	suite.assert_int_equal(
			2,
			player.arts[1].current_cooldown,
			"Shield Arts should start cooldown."
	)
	fixture.action_service.execute(
			fixture.battle,
			EndTurnActionRequest.create(GameEnums.BattleSide.PLAYER)
	)
	fixture.action_service.execute(
			fixture.battle,
			EndTurnActionRequest.create(GameEnums.BattleSide.ENEMY)
	)
	suite.assert_int_equal(
			1,
			player.arts[1].current_cooldown,
			"Cooldowns should advance at the owning side's turn start."
	)


static func _test_passive_trigger(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create(true)
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					0,
					fixture.create_cell_selection(Vector2i(2, 1))
			)
	)
	var enemy: UnitState = fixture.battle.get_unit(fixture.enemy_unit_id)
	suite.assert_true(result.is_successful, "Triggered strike should complete.")
	suite.assert_int_equal(
			2,
			enemy.current_shield,
			"Passive triggers should execute configured effects."
	)
	suite.assert_int_equal(
			0,
			fixture.battle.get_unit(
					fixture.second_enemy_unit_id
			).current_shield,
			"Event relation Conditions should filter unrelated passive owners."
	)
	suite.assert_int_equal(
			3,
			result.events.size(),
			"Damage, Art use, and triggered shield should publish three events."
	)
	for index: int in range(result.events.size()):
		suite.assert_int_equal(
				index + 1,
				result.events[index].sequence_id,
				"Battle events should receive deterministic sequence IDs."
		)


static func _test_buff_changes_art_damage(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var self_selection: TargetSelection = fixture.create_unit_selection(
			fixture.player_unit_id
	)
	var focus_result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					2,
					self_selection
			)
	)
	suite.assert_true(focus_result.is_successful, "Buff Arts should execute.")
	var strike_result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					0,
					fixture.create_cell_selection(Vector2i(2, 1))
			)
	)
	suite.assert_true(strike_result.is_successful, "Buffed strikes should execute.")
	suite.assert_int_equal(
			2,
			fixture.battle.get_unit(fixture.enemy_unit_id).current_health,
			"Attribute Buffs should change planned Art damage."
	)


static func _test_common_effect_execution(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	var executor: BattleEffectExecutor = BattleEffectExecutor.new()
	var player: UnitState = fixture.battle.get_unit(fixture.player_unit_id)
	var player_selection: TargetSelection = fixture.create_unit_selection(
			fixture.player_unit_id
	)
	player.current_health = 4
	player.current_shield = 3

	var damage: DamageEffectDefinition = DamageEffectDefinition.new()
	damage.flat_amount = 5
	var damage_result: EffectResult = executor.execute(
			damage,
			EffectContext.create(
					fixture.battle,
					fixture.enemy_unit_id,
					player_selection
			)
	)
	suite.assert_true(damage_result.succeeded(), "Damage effects should execute.")
	suite.assert_int_equal(0, player.current_shield, "Shield should absorb damage first.")
	suite.assert_int_equal(
			2,
			player.current_health,
			"Damage remaining after shield should reduce health."
	)

	var healing: HealingEffectDefinition = HealingEffectDefinition.new()
	healing.flat_amount = 20
	var healing_result: EffectResult = executor.execute(
			healing,
			EffectContext.create(
					fixture.battle,
					fixture.player_unit_id,
					player_selection
			)
	)
	suite.assert_true(healing_result.succeeded(), "Healing effects should execute.")
	suite.assert_int_equal(
			10,
			player.current_health,
			"Healing should clamp to calculated maximum health."
	)

	var apply_buff: ApplyBuffEffectDefinition = ApplyBuffEffectDefinition.new()
	apply_buff.buff = fixture.attack_buff
	suite.assert_true(
			executor.execute(
					apply_buff,
					EffectContext.create(
							fixture.battle,
							fixture.player_unit_id,
							player_selection
					)
			).succeeded(),
			"Apply Buff effects should execute."
	)
	suite.assert_true(
			player.find_buff(fixture.attack_buff) != null,
			"Apply Buff effects should add runtime Buff state."
	)
	var remove_buff: RemoveBuffEffectDefinition = RemoveBuffEffectDefinition.new()
	remove_buff.buff = fixture.attack_buff
	suite.assert_true(
			executor.execute(
					remove_buff,
					EffectContext.create(
							fixture.battle,
							fixture.player_unit_id,
							player_selection
					)
			).succeeded(),
			"Remove Buff effects should execute."
	)
	suite.assert_true(
			player.find_buff(fixture.attack_buff) == null,
			"Remove Buff effects should remove matching runtime Buff state."
	)

	var movement: MoveEffectDefinition = MoveEffectDefinition.new()
	movement.target_source = GameEnums.EffectTargetSource.ACTOR
	var cell_selection: TargetSelection = TargetSelection.new()
	cell_selection.cells.append(Vector2i(0, 1))
	var movement_result: EffectResult = executor.execute(
			movement,
			EffectContext.create(
					fixture.battle,
					fixture.player_unit_id,
					cell_selection
			)
	)
	suite.assert_true(movement_result.succeeded(), "Move effects should execute.")
	suite.assert_true(
			fixture.battle.grid.find_occupant(
					GameEnums.GridOccupantKind.UNIT,
					fixture.player_unit_id
			).value == Vector2i(0, 1),
			"Move effects should update the Grid occupancy authority."
	)


static func _test_buff_expiry_event(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					2,
					fixture.create_unit_selection(fixture.player_unit_id)
			)
	)
	for cycle: int in range(2):
		fixture.action_service.execute(
				fixture.battle,
				EndTurnActionRequest.create(GameEnums.BattleSide.PLAYER)
		)
		var player_turn_result: ActionExecutionResult = (
			fixture.action_service.execute(
					fixture.battle,
					EndTurnActionRequest.create(GameEnums.BattleSide.ENEMY)
			)
		)
		if cycle == 1:
			suite.assert_true(
					player_turn_result.is_successful,
					"Turn transitions should complete when a Buff expires."
			)
			suite.assert_true(
					_has_event_kind(
							player_turn_result.events,
							GameEnums.BattleEventKind.BUFF_REMOVED
					),
					"Buff expiry should publish a typed removal event."
			)
	suite.assert_true(
			fixture.battle.get_unit(fixture.player_unit_id).find_buff(
					fixture.attack_buff
			) == null,
			"Expired Buff state should be removed at the owning side's turn start."
	)


static func _test_failed_condition_is_atomic(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	fixture.strike.use_conditions.append(FailingConditionDefinition.new())
	var player: UnitState = fixture.battle.get_unit(fixture.player_unit_id)
	var enemy: UnitState = fixture.battle.get_unit(fixture.enemy_unit_id)
	var initial_ap: int = player.current_ap
	var initial_health: int = enemy.current_health
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					0,
					fixture.create_cell_selection(Vector2i(2, 1))
			)
	)
	suite.assert_int_equal(
			GameEnums.ActionFailureCode.CONDITION_FAILED,
			result.failure_code,
			"Failed use conditions should reject Art actions."
	)
	suite.assert_int_equal(
			initial_ap,
			player.current_ap,
			"Failed use conditions should not spend AP."
	)
	suite.assert_int_equal(
			initial_health,
			enemy.current_health,
			"Failed use conditions should not execute effects."
	)


static func _test_defeat_and_victory(suite: TestSuite) -> void:
	var fixture: ArtEffectFixture = ArtEffectFixture.create()
	fixture.battle.get_unit(fixture.enemy_unit_id).current_health = 3
	fixture.strike.effects.append(fixture.shield_effect)
	var result: ActionExecutionResult = fixture.action_service.execute(
			fixture.battle,
			UseArtActionRequest.create(
					GameEnums.BattleSide.PLAYER,
					fixture.player_unit_id,
					0,
					fixture.create_cell_selection(Vector2i(2, 1))
			)
	)
	suite.assert_true(
			result.is_successful,
			"Ordered effects after a lethal effect should skip defeated targets."
	)
	suite.assert_true(
			fixture.battle.phase == GameEnums.BattlePhase.VICTORY,
			"Removing the final enemy should produce victory."
	)
	suite.assert_true(
			fixture.battle.get_unit(fixture.enemy_unit_id) == null,
			"Defeated Units should be removed after trigger processing."
	)
	suite.assert_true(
			result.events[result.events.size() - 1] is BattleEndedEvent,
			"Terminal resolution should publish a Battle-ended event."
	)


static func _has_event_kind(
	events: Array[BattleEvent],
	kind: GameEnums.BattleEventKind
) -> bool:
	for event: BattleEvent in events:
		if event.kind == kind:
			return true
	return false

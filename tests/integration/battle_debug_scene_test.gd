class_name BattleDebugSceneTest
extends RefCounted

const SCENE_PATH: String = "res://scenes/debug/battle_debug.tscn"


static func run(suite: TestSuite) -> void:
	var packed_scene: PackedScene = load(SCENE_PATH) as PackedScene
	suite.assert_true(
			packed_scene != null,
			"Battle debug scene should load."
	)
	if packed_scene == null:
		return

	var controller: BattleDebugController = (
		packed_scene.instantiate() as BattleDebugController
	)
	suite.assert_true(
			controller != null,
			"Battle debug scene should instantiate its typed controller."
	)
	if controller == null:
		return

	suite.assert_true(
			controller.rebuild_debug_battle(),
			"Battle debug scene should compose a valid debug battle."
	)
	var validator: DefinitionValidator = DefinitionValidator.new()
	var debug_definitions: Array[DefinitionResource] = [
		controller.ground_terrain,
		controller.difficult_terrain,
		controller.blocked_terrain,
		controller.player_unit_definition,
		controller.archer_enemy_definition,
		controller.heavy_enemy_definition,
		controller.priest_enemy_definition,
	]
	for art: ArtDefinition in controller.player_unit_definition.default_arts:
		debug_definitions.append(art)
	var debug_enemies: Array[EnemyDefinition] = [
		controller.archer_enemy_definition,
		controller.heavy_enemy_definition,
		controller.priest_enemy_definition,
	]
	for enemy: EnemyDefinition in debug_enemies:
		for art: ArtDefinition in enemy.unit_definition.default_arts:
			debug_definitions.append(art)
		for intent: IntentDefinition in enemy.available_intents:
			debug_definitions.append(intent)
	debug_definitions.append(
			load("res://content/buffs/debug_battle_focus.tres") as BuffDefinition
	)
	for definition: DefinitionResource in debug_definitions:
		suite.assert_true(
				validator.validate(definition).is_valid(),
				"Battle debug content should pass Definition validation."
		)
	var battle: BattleState = controller.get_battle_state()
	suite.assert_true(
			battle != null,
			"Battle debug controller should expose its composed Battle state."
	)
	if battle != null:
		suite.assert_int_equal(
				5,
				battle.unit_count(),
				"Battle debug scene should place two players and three enemies."
		)
		suite.assert_int_equal(
				6,
				battle.grid.occupant_count(),
				"Battle debug scene should include Units and one scene object."
		)
		suite.assert_int_equal(
				1,
				battle.round_number,
				"Battle debug scene should start round one."
		)
		suite.assert_true(
				battle.phase == GameEnums.BattlePhase.PLAYER_TURN,
				"Battle debug scene should start on the player turn."
		)
		suite.assert_true(
				controller.status_view.phase_label.text.contains("玩家回合"),
				"Battle debug phase label should use Chinese interface copy."
		)
		suite.assert_true(
				controller.status_view.end_turn_button.text == "结束玩家回合",
				"Battle debug turn button should use Chinese interface copy."
		)
		suite.assert_true(
				controller.status_view.art_selector != null,
				"Battle debug scene should expose its Art selector."
		)
		suite.assert_true(
				controller.status_view.use_art_button.text == "使用技艺",
				"Battle debug Art button should use Chinese interface copy."
		)
		suite.assert_int_equal(
				3,
				controller.get_intent_previews().size(),
				"All three debug enemies should publish first-turn Intents."
		)
		suite.assert_true(
				controller.status_view.round_label.text.contains("敌人意图"),
				"The Chinese status panel should list published enemy Intents."
		)
		controller._handle_coordinate_pressed(Vector2i(1, 1))
		suite.assert_int_equal(
				4,
				controller.status_view.art_selector.item_count,
				"Selecting a debug player Unit should list its four Arts."
		)
		controller._on_art_selected(0)
		controller._on_use_art_pressed()
		suite.assert_true(
				controller._art_range_cells.has(Vector2i(1, 0)),
				"Starting an Art should expose its geometric range."
		)
		suite.assert_true(
				controller._targetable_cells.has(Vector2i(1, 0)),
				"Valid empty Cells should be selectable Art aims."
		)
		controller._handle_coordinate_pressed(Vector2i(1, 0))
		suite.assert_int_equal(
				3,
				battle.get_unit(
						controller._selected_unit_id
				).current_ap,
				"Empty-cell attacks should execute through the debug interaction."
		)
		controller._on_art_selected(1)
		controller._on_use_art_pressed()
		suite.assert_true(
				controller._targetable_cells.has(Vector2i(1, 1)),
				"Self-targeted Arts should highlight the selected Unit's Cell."
		)
		controller._handle_coordinate_pressed(Vector2i(1, 1))
		var selected_occupant: GridOccupant = battle.grid.get_occupant(
				Vector2i(1, 1)
		)
		suite.assert_int_equal(
				3,
				battle.get_unit(selected_occupant.runtime_id).current_shield,
				"The debug Art interaction should execute through Battle actions."
		)
		controller._on_end_turn_pressed()
		suite.assert_true(
				battle.phase == GameEnums.BattlePhase.PLAYER_TURN,
				"The debug turn button should run the complete automatic enemy turn."
		)
		suite.assert_int_equal(
				2,
				battle.round_number,
				"Automatic enemy execution should return to the next player round."
		)
		suite.assert_true(
				not controller.get_intent_previews().is_empty(),
				"The next player round should already expose fresh enemy Intents."
		)
	controller.free()

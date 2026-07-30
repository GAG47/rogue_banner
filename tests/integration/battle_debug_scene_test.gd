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
		controller.enemy_unit_definition,
	]
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
				4,
				battle.unit_count(),
				"Battle debug scene should place four Units."
		)
		suite.assert_int_equal(
				5,
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
				controller.phase_label.text.contains("玩家回合"),
				"Battle debug phase label should use Chinese interface copy."
		)
		suite.assert_true(
				controller.end_turn_button.text == "结束玩家回合",
				"Battle debug turn button should use Chinese interface copy."
		)
	controller.free()

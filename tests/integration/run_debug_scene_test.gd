class_name RunDebugSceneTest
extends RefCounted

const SCENE_PATH: String = "res://scenes/debug/run_debug.tscn"


static func run(suite: TestSuite) -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	suite.assert_true(packed != null, "Run debug scene should load.")
	if packed == null:
		return
	var controller: RunDebugController = (
		packed.instantiate() as RunDebugController
	)
	suite.assert_true(
		controller != null,
		"Run debug scene should instantiate its typed controller."
	)
	if controller == null:
		return
	controller.reset_run()
	suite.assert_true(
		controller.get_run_state() != null,
		"Run debug scene should create its initial Run state."
	)
	suite.assert_true(
		controller.primary_action_button.text == "进入第一场战斗",
		"Run debug actions should use Chinese interface copy."
	)

	controller._on_primary_action_pressed()
	controller._on_primary_action_pressed()
	controller._on_primary_action_pressed()
	var run_state: RunState = controller.get_run_state()
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.CHOOSING_REWARD,
		"Run debug first Battle should reach reward selection."
	)
	var battle_offer: RewardOffer = run_state.get_active_offer()
	var art_index: int = _find_option_index(
			battle_offer,
			GameEnums.RewardKind.ART
	)
	controller._on_offer_option_pressed(art_index)
	controller._on_primary_action_pressed()
	controller._on_primary_action_pressed()
	suite.assert_true(
		run_state.get_phase() == GameEnums.RunPhase.SHOPPING,
		"Run debug should enter its fixed shop."
	)
	var shop: RewardOffer = run_state.get_active_offer()
	for index: int in range(shop.options.size()):
		controller._on_offer_option_pressed(index)
	controller._on_primary_action_pressed()
	controller._on_primary_action_pressed()
	controller._on_primary_action_pressed()
	controller._on_primary_action_pressed()
	suite.assert_int_equal(
		2,
		controller._completed_battles,
		"Run debug scene should carry its build through two Battles."
	)
	suite.assert_int_equal(
		2,
		run_state.get_units().size(),
		"Run debug scene should retain the recruited Unit."
	)
	suite.assert_int_equal(
		1,
		run_state.get_relics().size(),
		"Run debug scene should retain the purchased Relic."
	)
	controller.free()


static func _find_option_index(
		offer: RewardOffer,
		kind: GameEnums.RewardKind
) -> int:
	for index: int in range(offer.options.size()):
		if offer.options[index].payload.kind == kind:
			return index
	return -1


class_name RunScreenSceneTest
extends RefCounted

const SCENE_PATH: String = "res://scenes/run/run_screen.tscn"


static func run(suite: TestSuite) -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	suite.assert_true(packed != null, "The formal v8 Run Screen should load.")
	if packed == null:
		return
	var controller: RunScreenController = packed.instantiate() as RunScreenController
	suite.assert_true(
		controller != null,
		"The v8 scene should instantiate its typed session UI controller."
	)
	if controller == null:
		return
	suite.assert_true(
		controller.start_new_run(),
		"The v8 scene should create the fixed first playable Run."
	)
	var snapshot: RunSessionSnapshot = controller.get_snapshot()
	suite.assert_true(
		snapshot != null and snapshot.route == RunSessionRoute.Value.MAP,
		"The formal Run Screen should open on the authoritative Map route."
	)
	suite.assert_true(
		controller.map_panel.visible
		and controller.header_view.run_title_label.text.contains("远征"),
		"The first route should have a visible Chinese Map and summary header."
	)
	suite.assert_false(
		controller.battle_host.visible,
		"The Battle host should stay hidden until a Battle is started."
	)
	controller.free()


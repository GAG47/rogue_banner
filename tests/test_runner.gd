extends SceneTree


func _init() -> void:
	var suite: TestSuite = TestSuite.new()
	CoreDataLayerTest.run(suite)
	GridStateTest.run(suite)
	BattleKernelTest.run(suite)
	ArtRuleTest.run(suite)
	ArtEffectSystemTest.run(suite)
	BattleDebugSceneTest.run(suite)

	if suite.passed():
		print("PASS: %d project assertions." % suite.assertion_count)
		suite = null
		quit(0)
		return

	for failure: String in suite.failures:
		push_error(failure)
	print(
			"FAIL: %d of %d project assertions failed."
			% [suite.failures.size(), suite.assertion_count]
	)
	suite = null
	quit(1)

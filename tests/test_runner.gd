extends SceneTree


func _init() -> void:
	var suite: TestSuite = TestSuite.new()
	CoreDataLayerTest.run(suite)
	GridStateTest.run(suite)
	BattleKernelTest.run(suite)
	ArtRuleTest.run(suite)
	ArtEffectSystemTest.run(suite)
	EnemyIntentSystemTest.run(suite)
	BattleReadModelTest.run(suite)
	BattleDebugSceneTest.run(suite)
	BattleScreenSceneTest.run(suite)
	RunRewardSystemTest.run(suite)
	RunFlowSystemTest.run(suite)
	MapSystemTest.run(suite)
	MapFlowSystemTest.run(suite)
	RunDebugSceneTest.run(suite)

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

extends SceneTree


func _init() -> void:
	var suite: TestSuite = TestSuite.new()
	CoreDataLayerTest.run(suite)

	if suite.passed():
		print("PASS: %d core data layer assertions." % suite.assertion_count)
		suite = null
		quit(0)
		return

	for failure: String in suite.failures:
		push_error(failure)
	print(
			"FAIL: %d of %d core data layer assertions failed."
			% [suite.failures.size(), suite.assertion_count]
	)
	suite = null
	quit(1)

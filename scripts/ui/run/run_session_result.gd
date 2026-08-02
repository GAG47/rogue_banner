class_name RunSessionResult
extends RefCounted

var succeeded: bool = true
var run_code: GameEnums.RunCommandCode = GameEnums.RunCommandCode.SUCCEEDED
var map_code: GameEnums.MapFlowCode = GameEnums.MapFlowCode.SUCCEEDED


static func success() -> RunSessionResult:
	return RunSessionResult.new()


static func run_failure(code: GameEnums.RunCommandCode) -> RunSessionResult:
	var result: RunSessionResult = RunSessionResult.new()
	result.succeeded = false
	result.run_code = code
	return result


static func map_failure(code: GameEnums.MapFlowCode) -> RunSessionResult:
	var result: RunSessionResult = RunSessionResult.new()
	result.succeeded = false
	result.map_code = code
	return result

class_name RunCommandResult
extends RefCounted

var code: GameEnums.RunCommandCode = GameEnums.RunCommandCode.SUCCEEDED
var unit_instance_id: int = 0
var art_instance_id: int = 0
var relic_instance_id: int = 0
var changed_quantity: int = 0


static func success() -> RunCommandResult:
	return RunCommandResult.new()


static func failure(
		failure_code: GameEnums.RunCommandCode
) -> RunCommandResult:
	var result: RunCommandResult = RunCommandResult.new()
	result.code = failure_code
	return result


func succeeded() -> bool:
	return code == GameEnums.RunCommandCode.SUCCEEDED


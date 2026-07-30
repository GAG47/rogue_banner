class_name GridOperationResult
extends RefCounted

var code: GameEnums.GridOperationCode = GameEnums.GridOperationCode.SUCCEEDED


static func success() -> GridOperationResult:
	return GridOperationResult.new()


static func failure(
		failure_code: GameEnums.GridOperationCode
) -> GridOperationResult:
	var result: GridOperationResult = GridOperationResult.new()
	result.code = failure_code
	return result


func succeeded() -> bool:
	return code == GameEnums.GridOperationCode.SUCCEEDED

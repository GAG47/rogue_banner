class_name BattleSetupResult
extends RefCounted

var code: GameEnums.RunCommandCode = GameEnums.RunCommandCode.SUCCEEDED
var setup: BattleSetup


static func success(value: BattleSetup) -> BattleSetupResult:
	var result: BattleSetupResult = BattleSetupResult.new()
	result.setup = value
	return result


static func failure(
		failure_code: GameEnums.RunCommandCode
) -> BattleSetupResult:
	var result: BattleSetupResult = BattleSetupResult.new()
	result.code = failure_code
	return result


func succeeded() -> bool:
	return (
		code == GameEnums.RunCommandCode.SUCCEEDED
		and setup != null
	)


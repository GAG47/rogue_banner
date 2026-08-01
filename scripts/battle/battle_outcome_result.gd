class_name BattleOutcomeResult
extends RefCounted

var code: GameEnums.RunCommandCode = GameEnums.RunCommandCode.SUCCEEDED
var outcome: BattleOutcome


static func success(value: BattleOutcome) -> BattleOutcomeResult:
	var result: BattleOutcomeResult = BattleOutcomeResult.new()
	result.outcome = value
	return result


static func failure(
		failure_code: GameEnums.RunCommandCode
) -> BattleOutcomeResult:
	var result: BattleOutcomeResult = BattleOutcomeResult.new()
	result.code = failure_code
	return result


func succeeded() -> bool:
	return (
		code == GameEnums.RunCommandCode.SUCCEEDED
		and outcome != null
	)


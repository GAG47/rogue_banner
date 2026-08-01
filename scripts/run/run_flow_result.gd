class_name RunFlowResult
extends RefCounted

var code: GameEnums.RunCommandCode = GameEnums.RunCommandCode.SUCCEEDED
var battle: BattleState
var outcome: BattleOutcome
var offer: RewardOffer


func succeeded() -> bool:
	return code == GameEnums.RunCommandCode.SUCCEEDED


static func success() -> RunFlowResult:
	return RunFlowResult.new()


static func failure(
		failure_code: GameEnums.RunCommandCode
) -> RunFlowResult:
	var result: RunFlowResult = RunFlowResult.new()
	result.code = failure_code
	return result


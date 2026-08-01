class_name BattleStartResult
extends RefCounted

var code: GameEnums.RunCommandCode = GameEnums.RunCommandCode.SUCCEEDED
var battle: BattleState
var flow_result: BattleFlowResult


static func success(
		battle_state: BattleState,
		result: BattleFlowResult
) -> BattleStartResult:
	var start: BattleStartResult = BattleStartResult.new()
	start.battle = battle_state
	start.flow_result = result
	return start


static func failure(
		failure_code: GameEnums.RunCommandCode
) -> BattleStartResult:
	var result: BattleStartResult = BattleStartResult.new()
	result.code = failure_code
	return result


func succeeded() -> bool:
	return (
		code == GameEnums.RunCommandCode.SUCCEEDED
		and battle != null
		and flow_result != null
		and flow_result.succeeded
	)


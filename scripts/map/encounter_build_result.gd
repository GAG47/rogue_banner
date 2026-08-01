class_name EncounterBuildResult
extends RefCounted

var code: GameEnums.MapFlowCode = GameEnums.MapFlowCode.SUCCEEDED
var request: RunBattleStartRequest


func succeeded() -> bool:
	return code == GameEnums.MapFlowCode.SUCCEEDED and request != null


static func success(value: RunBattleStartRequest) -> EncounterBuildResult:
	if value == null:
		return failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	var result: EncounterBuildResult = EncounterBuildResult.new()
	result.request = value
	return result


static func failure(failure_code: GameEnums.MapFlowCode) -> EncounterBuildResult:
	var result: EncounterBuildResult = EncounterBuildResult.new()
	result.code = failure_code
	return result

class_name MapGenerationResult
extends RefCounted

var code: GameEnums.MapFlowCode = GameEnums.MapFlowCode.SUCCEEDED
var map_state: MapState


func succeeded() -> bool:
	return code == GameEnums.MapFlowCode.SUCCEEDED and map_state != null


static func success(state: MapState) -> MapGenerationResult:
	if state == null:
		return failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	var result: MapGenerationResult = MapGenerationResult.new()
	result.map_state = state
	return result


static func failure(failure_code: GameEnums.MapFlowCode) -> MapGenerationResult:
	var result: MapGenerationResult = MapGenerationResult.new()
	result.code = failure_code
	return result

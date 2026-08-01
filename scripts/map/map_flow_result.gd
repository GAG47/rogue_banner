class_name MapFlowResult
extends RefCounted

var code: GameEnums.MapFlowCode = GameEnums.MapFlowCode.SUCCEEDED
var battle: BattleState
var outcome: BattleOutcome
var offer: RewardOffer
var read_model: MapReadModel


func succeeded() -> bool:
	return code == GameEnums.MapFlowCode.SUCCEEDED


static func success() -> MapFlowResult:
	return MapFlowResult.new()


static func failure(failure_code: GameEnums.MapFlowCode) -> MapFlowResult:
	var result: MapFlowResult = MapFlowResult.new()
	result.code = failure_code
	return result

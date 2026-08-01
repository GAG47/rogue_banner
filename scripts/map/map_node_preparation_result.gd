class_name MapNodePreparationResult
extends RefCounted

var code: GameEnums.MapFlowCode = GameEnums.MapFlowCode.SUCCEEDED
var offer: RewardOffer
var completes_immediately: bool = false


func succeeded() -> bool:
	return code == GameEnums.MapFlowCode.SUCCEEDED


static func success(
	generated_offer: RewardOffer = null,
	should_complete: bool = false
) -> MapNodePreparationResult:
	var result: MapNodePreparationResult = MapNodePreparationResult.new()
	result.offer = generated_offer
	result.completes_immediately = should_complete
	return result


static func failure(
	failure_code: GameEnums.MapFlowCode
) -> MapNodePreparationResult:
	var result: MapNodePreparationResult = MapNodePreparationResult.new()
	result.code = failure_code
	return result

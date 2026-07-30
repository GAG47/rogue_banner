class_name BattlePlacementResult
extends RefCounted

var code: GameEnums.BattlePlacementCode = GameEnums.BattlePlacementCode.SUCCEEDED
var unit_id: int = 0


static func success(placed_unit_id: int) -> BattlePlacementResult:
	var result: BattlePlacementResult = BattlePlacementResult.new()
	result.unit_id = placed_unit_id
	return result


static func failure(
		failure_code: GameEnums.BattlePlacementCode
) -> BattlePlacementResult:
	var result: BattlePlacementResult = BattlePlacementResult.new()
	result.code = failure_code
	return result


func succeeded() -> bool:
	return code == GameEnums.BattlePlacementCode.SUCCEEDED

class_name GridPathResult
extends RefCounted

var status: GameEnums.GridPathStatus = GameEnums.GridPathStatus.NO_PATH
var path: Array[Vector2i] = []
var total_cost: int = 0


static func found(
		found_path: Array[Vector2i],
		movement_cost: int
) -> GridPathResult:
	var result: GridPathResult = GridPathResult.new()
	result.status = GameEnums.GridPathStatus.FOUND
	result.path.assign(found_path)
	result.total_cost = movement_cost
	return result


static func failure(
		failure_status: GameEnums.GridPathStatus
) -> GridPathResult:
	var result: GridPathResult = GridPathResult.new()
	result.status = failure_status
	return result


func succeeded() -> bool:
	return status == GameEnums.GridPathStatus.FOUND

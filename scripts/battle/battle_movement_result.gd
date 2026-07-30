class_name BattleMovementResult
extends RefCounted

var succeeded: bool = false
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var ap_spent: int = 0
var path: Array[Vector2i] = []
var event: UnitMovedEvent


static func success(
		spent_ap: int,
		movement_path: Array[Vector2i],
		moved_event: UnitMovedEvent
) -> BattleMovementResult:
	var result: BattleMovementResult = BattleMovementResult.new()
	result.succeeded = true
	result.ap_spent = spent_ap
	result.path.assign(movement_path)
	result.event = moved_event
	return result


static func failure(
		code: GameEnums.ActionFailureCode
) -> BattleMovementResult:
	var result: BattleMovementResult = BattleMovementResult.new()
	result.failure_code = code
	return result

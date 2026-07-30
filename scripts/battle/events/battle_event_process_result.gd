class_name BattleEventProcessResult
extends RefCounted

var succeeded: bool = false
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var events: Array[BattleEvent] = []


static func success(
		processed_events: Array[BattleEvent]
) -> BattleEventProcessResult:
	var result: BattleEventProcessResult = BattleEventProcessResult.new()
	result.succeeded = true
	result.events.assign(processed_events)
	return result


static func failure(
		code: GameEnums.ActionFailureCode,
		processed_events: Array[BattleEvent] = []
) -> BattleEventProcessResult:
	var result: BattleEventProcessResult = BattleEventProcessResult.new()
	result.failure_code = code
	result.events.assign(processed_events)
	return result

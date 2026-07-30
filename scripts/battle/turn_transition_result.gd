class_name TurnTransitionResult
extends RefCounted

var succeeded: bool = false
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var previous_side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var active_side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var round_number: int = 0
var events: Array[BattleEvent] = []


static func success(
		old_side: GameEnums.BattleSide,
		new_side: GameEnums.BattleSide,
		new_round_number: int
) -> TurnTransitionResult:
	var result: TurnTransitionResult = TurnTransitionResult.new()
	result.succeeded = true
	result.previous_side = old_side
	result.active_side = new_side
	result.round_number = new_round_number
	return result


static func failure(
		code: GameEnums.ActionFailureCode
) -> TurnTransitionResult:
	var result: TurnTransitionResult = TurnTransitionResult.new()
	result.failure_code = code
	return result

class_name ActionExecutionResult
extends RefCounted

var is_successful: bool = false
var failure_code: GameEnums.ActionFailureCode = GameEnums.ActionFailureCode.NONE
var ap_spent: int = 0
var movement_path: Array[Vector2i] = []
var phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var active_side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var round_number: int = 0
var events: Array[BattleEvent] = []
var removed_unit_ids: Array[int] = []
var scroll_stack_instance_id: int = 0
var scrolls_consumed: int = 0


static func success(battle: BattleState) -> ActionExecutionResult:
	var result: ActionExecutionResult = ActionExecutionResult.new()
	result.is_successful = true
	if battle != null:
		result.phase = battle.phase
		result.active_side = battle.active_side
		result.round_number = battle.round_number
	return result


static func failure(
		code: GameEnums.ActionFailureCode
) -> ActionExecutionResult:
	var result: ActionExecutionResult = ActionExecutionResult.new()
	result.failure_code = code
	return result

class_name ActionExecutionPlan
extends RefCounted

var request: BattleActionRequest
var ap_cost: int = 0
var movement_path: Array[Vector2i] = []


static func create(
		action_request: BattleActionRequest,
		action_ap_cost: int = 0
) -> ActionExecutionPlan:
	var plan: ActionExecutionPlan = ActionExecutionPlan.new()
	plan.request = action_request
	plan.ap_cost = action_ap_cost
	return plan

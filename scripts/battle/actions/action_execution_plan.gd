class_name ActionExecutionPlan
extends RefCounted

var request: BattleActionRequest
var ap_cost: int = 0
var movement_path: Array[Vector2i] = []
var art_slot_index: int = -1
var art_definition: ArtDefinition
var scroll_definition: ScrollDefinition
var scroll_stack_instance_id: int = 0
var resolved_targets: ResolvedTargetSet
var cooldown_to_apply: int = 0
var effect_plans: Array[EffectExecutionPlan] = []


static func create(
		action_request: BattleActionRequest,
		action_ap_cost: int = 0
) -> ActionExecutionPlan:
	var plan: ActionExecutionPlan = ActionExecutionPlan.new()
	plan.request = action_request
	plan.ap_cost = action_ap_cost
	return plan

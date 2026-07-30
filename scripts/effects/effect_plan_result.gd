class_name EffectPlanResult
extends RefCounted

var is_valid: bool = false
var plans: Array[EffectExecutionPlan] = []


static func accepted(
		effect_plans: Array[EffectExecutionPlan]
) -> EffectPlanResult:
	var result: EffectPlanResult = EffectPlanResult.new()
	result.is_valid = true
	result.plans.assign(effect_plans)
	return result


static func rejected() -> EffectPlanResult:
	return EffectPlanResult.new()

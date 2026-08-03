class_name ScrollUiTextFormatter
extends RefCounted


static func effect_summary(definition: ScrollDefinition) -> String:
	if definition == null or definition.effects.is_empty():
		return "无直接效果"
	var parts: Array[String] = []
	for effect: EffectDefinition in definition.effects:
		parts.append(_effect_text(effect))
	return "；".join(parts)


static func _effect_text(effect: EffectDefinition) -> String:
	if effect is DamageEffectDefinition:
		return "造成%s点伤害" % _scaled_amount_text(
			effect as ScaledUnitEffectDefinition
		)
	if effect is HealingEffectDefinition:
		return "恢复%s点生命" % _scaled_amount_text(
			effect as ScaledUnitEffectDefinition
		)
	if effect is ShieldEffectDefinition:
		return "获得%s点护盾" % _scaled_amount_text(
			effect as ScaledUnitEffectDefinition
		)
	if effect is ApplyBuffEffectDefinition:
		var applied: ApplyBuffEffectDefinition = (
			effect as ApplyBuffEffectDefinition
		)
		return "施加%s" % (
			applied.buff.display_name if applied.buff != null else "状态"
		)
	if effect is RemoveBuffEffectDefinition:
		var removed: RemoveBuffEffectDefinition = (
			effect as RemoveBuffEffectDefinition
		)
		return "移除%s" % (
			removed.buff.display_name if removed.buff != null else "状态"
		)
	if effect is MoveEffectDefinition:
		return "移动使用者"
	if effect is ForcedMovementEffectDefinition:
		return "强制移动目标%d格" % (
			(effect as ForcedMovementEffectDefinition).distance
		)
	return "产生配置效果"


static func _scaled_amount_text(effect: ScaledUnitEffectDefinition) -> String:
	var parts: Array[String] = []
	if effect.flat_amount > 0:
		parts.append(str(effect.flat_amount))
	if not is_zero_approx(effect.attribute_multiplier):
		parts.append("%d%%基础攻击" % roundi(effect.attribute_multiplier * 100.0))
	return " + ".join(parts) if not parts.is_empty() else "0"

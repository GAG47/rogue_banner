class_name BattleUiTextFormatter
extends RefCounted


static func action_result_text(result: ActionExecutionResult) -> String:
	var summaries: Array[String] = []
	for event: BattleEvent in result.events:
		if event is DamageAppliedEvent:
			var damage: DamageAppliedEvent = event as DamageAppliedEvent
			summaries.append(
				"单位%d受到%d点生命伤害，护盾抵消%d点" % [
					damage.target_unit_id,
					damage.health_damage,
					damage.shield_absorbed,
				]
			)
		elif event is HealingAppliedEvent:
			var healing: HealingAppliedEvent = event as HealingAppliedEvent
			summaries.append(
				"单位%d恢复%d点生命" % [
					healing.target_unit_id,
					healing.restored_health,
				]
			)
		elif event is ShieldChangedEvent:
			var shield: ShieldChangedEvent = event as ShieldChangedEvent
			summaries.append(
				"单位%d的护盾变为%d" % [
					shield.target_unit_id,
					shield.current_shield,
				]
			)
		elif event is BuffAppliedEvent:
			var applied: BuffAppliedEvent = event as BuffAppliedEvent
			summaries.append(
				"单位%d获得%s（%d层）" % [
					applied.target_unit_id,
					applied.buff_definition.display_name,
					applied.stacks,
				]
			)
		elif event is BuffRemovedEvent:
			var removed: BuffRemovedEvent = event as BuffRemovedEvent
			summaries.append(
				"单位%d失去%s" % [
					removed.target_unit_id,
					removed.buff_definition.display_name,
				]
			)
		elif event is UnitDefeatedEvent:
			summaries.append("单位%d被击败" % event.target_unit_id)
		elif event is BattleEndedEvent:
			var ended: BattleEndedEvent = event as BattleEndedEvent
			summaries.append(
				"战斗%s" % (
					"胜利"
					if ended.final_phase == GameEnums.BattlePhase.VICTORY
					else "失败"
				)
			)
	if summaries.is_empty():
		return "技艺执行成功，消耗%d点行动点。" % result.ap_spent
	return "；".join(summaries) + "。"


static func battle_flow_text(result: BattleFlowResult) -> String:
	if result == null or not result.succeeded:
		return "敌方回合执行失败。"
	var summaries: Array[String] = []
	if result.enemy_turn_result != null:
		for execution: IntentExecutionResult in (
			result.enemy_turn_result.executions
		):
			var executed_steps: int = 0
			var fizzled_steps: int = 0
			for step: IntentStepResult in execution.steps:
				if step.status == GameEnums.IntentStepStatus.EXECUTED:
					executed_steps += 1
				elif step.status == GameEnums.IntentStepStatus.FIZZLED:
					fizzled_steps += 1
			summaries.append(
				"敌方单位%d执行%d步，落空%d步" % [
					execution.actor_unit_id,
					executed_steps,
					fizzled_steps,
				]
			)
	if summaries.is_empty():
		summaries.append("敌方没有可执行的意图")
	if result.generation_result != null and result.generation_result.succeeded:
		summaries.append(
			"已公布%d个新意图" % result.generation_result.plans.size()
		)
	return "；".join(summaries) + "。"


static func phase_text(phase: GameEnums.BattlePhase) -> String:
	match phase:
		GameEnums.BattlePhase.SETUP:
			return "战前部署"
		GameEnums.BattlePhase.PLAYER_TURN:
			return "玩家回合"
		GameEnums.BattlePhase.ENEMY_TURN:
			return "敌方回合"
		GameEnums.BattlePhase.VICTORY:
			return "战斗胜利"
		GameEnums.BattlePhase.FAILURE:
			return "战斗失败"
	return "未知阶段"


static func side_text(side: GameEnums.BattleSide) -> String:
	return "玩家" if side == GameEnums.BattleSide.PLAYER else "敌方"


static func intent_kind_text(kind: GameEnums.IntentKind) -> String:
	match kind:
		GameEnums.IntentKind.LOCKED:
			return "锁定"
		GameEnums.IntentKind.PATTERN:
			return "图形"
		GameEnums.IntentKind.ENHANCE:
			return "强化"
	return "未知"


static func art_category_text(category: GameEnums.ArtCategory) -> String:
	match category:
		GameEnums.ArtCategory.ATTACK:
			return "攻击"
		GameEnums.ArtCategory.SKILL:
			return "技能"
		GameEnums.ArtCategory.PASSIVE:
			return "被动"
	return "未知"


static func target_kind_text(kind: GameEnums.TargetKind) -> String:
	match kind:
		GameEnums.TargetKind.CELL:
			return "格子"
		GameEnums.TargetKind.UNIT:
			return "单位"
		GameEnums.TargetKind.TERRAIN_OBJECT:
			return "场景物体"
		GameEnums.TargetKind.BATTLE:
			return "整个战场"
	return "未知"


static func failure_code_text(code: GameEnums.ActionFailureCode) -> String:
	match code:
		GameEnums.ActionFailureCode.NONE:
			return "没有错误"
		GameEnums.ActionFailureCode.INVALID_REQUEST:
			return "行动请求无效"
		GameEnums.ActionFailureCode.INVALID_BATTLE:
			return "战斗状态无效"
		GameEnums.ActionFailureCode.INVALID_PHASE:
			return "当前阶段不允许此行动"
		GameEnums.ActionFailureCode.BATTLE_NOT_ACTIVE:
			return "战斗尚未进入行动阶段"
		GameEnums.ActionFailureCode.WRONG_TURN:
			return "当前不是该行动方的回合"
		GameEnums.ActionFailureCode.ACTOR_NOT_FOUND:
			return "找不到行动单位"
		GameEnums.ActionFailureCode.ACTOR_SIDE_MISMATCH:
			return "行动单位不属于请求方"
		GameEnums.ActionFailureCode.ACTOR_DEFEATED:
			return "行动单位已经被击败"
		GameEnums.ActionFailureCode.ACTOR_NOT_PLACED:
			return "行动单位尚未放置"
		GameEnums.ActionFailureCode.DESTINATION_OUT_OF_BOUNDS:
			return "目标格超出棋盘"
		GameEnums.ActionFailureCode.DESTINATION_BLOCKED:
			return "目标格不可通行"
		GameEnums.ActionFailureCode.DESTINATION_OCCUPIED:
			return "目标格已被占用"
		GameEnums.ActionFailureCode.DESTINATION_UNCHANGED:
			return "目标格就是当前位置"
		GameEnums.ActionFailureCode.NO_PATH:
			return "不存在可用路径"
		GameEnums.ActionFailureCode.INSUFFICIENT_AP:
			return "行动点不足"
		GameEnums.ActionFailureCode.ART_NOT_FOUND:
			return "找不到指定技艺"
		GameEnums.ActionFailureCode.ART_NOT_USABLE:
			return "该技艺不能主动使用"
		GameEnums.ActionFailureCode.ART_ON_COOLDOWN:
			return "该技艺仍在冷却"
		GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION:
			return "目标选择无效"
		GameEnums.ActionFailureCode.CONDITION_FAILED:
			return "使用条件未满足"
		GameEnums.ActionFailureCode.TARGET_OUT_OF_RANGE:
			return "目标超出射程"
		GameEnums.ActionFailureCode.TARGET_RELATION_INVALID:
			return "目标阵营不符合要求"
		GameEnums.ActionFailureCode.LINE_OF_SIGHT_BLOCKED:
			return "视线被阻挡"
		GameEnums.ActionFailureCode.EFFECT_PLAN_INVALID:
			return "效果计划无效"
		GameEnums.ActionFailureCode.EFFECT_EXECUTION_FAILED:
			return "效果执行失败"
		GameEnums.ActionFailureCode.TRIGGER_LIMIT_EXCEEDED:
			return "被动触发次数超过限制"
		GameEnums.ActionFailureCode.STATE_CHANGED:
			return "战斗状态已经变化，请重新操作"
		GameEnums.ActionFailureCode.CONDITION_CONTEXT_INVALID:
			return "条件所需数据不存在"
		GameEnums.ActionFailureCode.INTENT_GENERATION_FAILED:
			return "敌人意图生成失败"
		GameEnums.ActionFailureCode.INTENT_EXECUTION_FAILED:
			return "敌人意图执行失败"
		GameEnums.ActionFailureCode.SCROLL_NOT_FOUND:
			return "找不到卷轴"
		GameEnums.ActionFailureCode.SCROLL_EMPTY:
			return "卷轴已经用完"
		GameEnums.ActionFailureCode.SCROLL_NOT_USABLE:
			return "卷轴当前不可使用"
	return "内部错误"

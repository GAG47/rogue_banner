class_name RunUiTextFormatter
extends RefCounted


static func route_text(route: RunSessionRoute.Value) -> String:
	match route:
		RunSessionRoute.Value.MAP:
			return "路线地图"
		RunSessionRoute.Value.DEPLOYMENT:
			return "战前部署"
		RunSessionRoute.Value.BATTLE:
			return "战斗"
		RunSessionRoute.Value.REWARD:
			return "领取奖励"
		RunSessionRoute.Value.SHOP:
			return "商店"
		RunSessionRoute.Value.EVENT:
			return "节点事件"
		RunSessionRoute.Value.RESULT:
			return "远征结束"
	return "不可用"


static func node_kind_text(kind: GameEnums.MapNodeKind) -> String:
	match kind:
		GameEnums.MapNodeKind.START:
			return "起点"
		GameEnums.MapNodeKind.BATTLE:
			return "战斗"
		GameEnums.MapNodeKind.ELITE:
			return "精英"
		GameEnums.MapNodeKind.BOSS:
			return "首领"
		GameEnums.MapNodeKind.SHOP:
			return "商店"
		GameEnums.MapNodeKind.CAMP:
			return "营地"
		GameEnums.MapNodeKind.CHEST:
			return "宝箱"
		GameEnums.MapNodeKind.EVENT:
			return "事件"
	return "未知"


static func result_text(result: RunSessionResult) -> String:
	if result == null:
		return "操作没有返回结果。"
	if result.succeeded:
		return "操作完成。"
	if result.map_code != GameEnums.MapFlowCode.SUCCEEDED:
		return _map_failure_text(result.map_code)
	return _run_failure_text(result.run_code)


static func _map_failure_text(code: GameEnums.MapFlowCode) -> String:
	match code:
		GameEnums.MapFlowCode.INVALID_PHASE:
			return "当前流程阶段不能执行该操作。"
		GameEnums.MapFlowCode.NODE_NOT_REACHABLE:
			return "只能进入当前节点连接的下一处地点。"
		GameEnums.MapFlowCode.NODE_ALREADY_RESOLVED:
			return "该节点已经完成。"
		GameEnums.MapFlowCode.INVALID_DEPLOYMENT:
			return "部署无效：检查参战单位、重复位置和部署区域。"
		GameEnums.MapFlowCode.EVENT_CHOICE_UNAVAILABLE:
			return "当前条件不满足，不能选择这个事件选项。"
		GameEnums.MapFlowCode.REWARD_FAILED:
			return "奖励无法处理：检查金币、容量或目标。"
		GameEnums.MapFlowCode.BATTLE_FAILED:
			return "战斗尚未结束，不能提交结果。"
		GameEnums.MapFlowCode.STATE_CHANGED:
			return "状态已经变化，请按当前显示重试。"
	return "流程操作失败（%d）。" % code


static func _run_failure_text(code: GameEnums.RunCommandCode) -> String:
	match code:
		GameEnums.RunCommandCode.INVALID_PHASE:
			return "当前阶段不能修改队伍或物品。"
		GameEnums.RunCommandCode.INSUFFICIENT_GOLD:
			return "金币不足。"
		GameEnums.RunCommandCode.TEAM_FULL:
			return "队伍已经满员。"
		GameEnums.RunCommandCode.LAST_AVAILABLE_UNIT:
			return "不能移除最后一名可用单位。"
		GameEnums.RunCommandCode.INVALID_ART_SLOT:
			return "所选技艺插槽无效。"
		GameEnums.RunCommandCode.ART_RULE_REJECTED:
			return "该单位不满足技艺安装条件。"
		GameEnums.RunCommandCode.SCROLL_CAPACITY_EXCEEDED:
			return "卷轴背包已满。"
		GameEnums.RunCommandCode.INVALID_TARGET:
			return "请选择符合要求的目标。"
		GameEnums.RunCommandCode.OPTION_UNAVAILABLE:
			return "该选项当前不可用。"
	return "局内操作失败（%d）。" % code

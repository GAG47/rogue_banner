class_name UseScrollActionRequest
extends BattleActionRequest

var actor_unit_id: int = 0
var scroll_stack_instance_id: int = 0
var targets: TargetSelection


static func create(
		unit_id: int,
		stack_instance_id: int,
		target_selection: TargetSelection
) -> UseScrollActionRequest:
	var request: UseScrollActionRequest = UseScrollActionRequest.new()
	request.requesting_side = GameEnums.BattleSide.PLAYER
	request.actor_unit_id = unit_id
	request.scroll_stack_instance_id = stack_instance_id
	request.targets = target_selection
	return request


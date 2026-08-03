class_name DiscardScrollActionRequest
extends BattleActionRequest

var scroll_stack_instance_id: int = 0


static func create(stack_instance_id: int) -> DiscardScrollActionRequest:
	var request: DiscardScrollActionRequest = DiscardScrollActionRequest.new()
	request.requesting_side = GameEnums.BattleSide.PLAYER
	request.scroll_stack_instance_id = stack_instance_id
	return request

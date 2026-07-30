class_name MoveActionRequest
extends BattleActionRequest

var actor_unit_id: int = 0
var destination: Vector2i


static func create(
		side: GameEnums.BattleSide,
		unit_id: int,
		target_coordinate: Vector2i
) -> MoveActionRequest:
	var request: MoveActionRequest = MoveActionRequest.new()
	request.requesting_side = side
	request.actor_unit_id = unit_id
	request.destination = target_coordinate
	return request

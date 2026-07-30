class_name EndTurnActionRequest
extends BattleActionRequest


static func create(side: GameEnums.BattleSide) -> EndTurnActionRequest:
	var request: EndTurnActionRequest = EndTurnActionRequest.new()
	request.requesting_side = side
	return request

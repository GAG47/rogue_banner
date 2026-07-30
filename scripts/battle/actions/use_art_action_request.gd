class_name UseArtActionRequest
extends BattleActionRequest

var actor_unit_id: int = 0
var art_slot_index: int = -1
var targets: TargetSelection


static func create(
		side: GameEnums.BattleSide,
		unit_id: int,
		slot_index: int,
		target_selection: TargetSelection
) -> UseArtActionRequest:
	var request: UseArtActionRequest = UseArtActionRequest.new()
	request.requesting_side = side
	request.actor_unit_id = unit_id
	request.art_slot_index = slot_index
	request.targets = target_selection
	return request

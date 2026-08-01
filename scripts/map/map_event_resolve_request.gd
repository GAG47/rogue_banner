class_name MapEventResolveRequest
extends RefCounted

var unit_instance_id: int = 0
var art_instance_id: int = 0
var scroll_stack_instance_id: int = 0
var relic_instance_id: int = 0
var install_unit_instance_id: int = 0
var install_slot_index: int = -1


func to_reward_destination() -> RewardGrantDestination:
	var destination: RewardGrantDestination = RewardGrantDestination.none()
	destination.unit_instance_id = unit_instance_id
	destination.art_instance_id = art_instance_id
	destination.install_unit_instance_id = install_unit_instance_id
	destination.install_slot_index = install_slot_index
	return destination

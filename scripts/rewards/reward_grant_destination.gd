class_name RewardGrantDestination
extends RefCounted

var unit_instance_id: int = 0
var art_instance_id: int = 0
var install_unit_instance_id: int = 0
var install_slot_index: int = -1


static func none() -> RewardGrantDestination:
	return RewardGrantDestination.new()


static func unit(unit_id: int) -> RewardGrantDestination:
	var destination: RewardGrantDestination = RewardGrantDestination.new()
	destination.unit_instance_id = unit_id
	return destination


static func art(art_id: int) -> RewardGrantDestination:
	var destination: RewardGrantDestination = RewardGrantDestination.new()
	destination.art_instance_id = art_id
	return destination


static func install(unit_id: int, slot_index: int) -> RewardGrantDestination:
	var destination: RewardGrantDestination = RewardGrantDestination.new()
	destination.install_unit_instance_id = unit_id
	destination.install_slot_index = slot_index
	return destination


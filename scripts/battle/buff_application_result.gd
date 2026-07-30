class_name BuffApplicationResult
extends RefCounted

var succeeded: bool = false
var buff_instance_id: int = 0
var stacks: int = 0
var refreshed: bool = false


static func success(
		instance_id: int,
		current_stacks: int,
		was_refreshed: bool
) -> BuffApplicationResult:
	var result: BuffApplicationResult = BuffApplicationResult.new()
	result.succeeded = true
	result.buff_instance_id = instance_id
	result.stacks = current_stacks
	result.refreshed = was_refreshed
	return result


static func failure() -> BuffApplicationResult:
	return BuffApplicationResult.new()

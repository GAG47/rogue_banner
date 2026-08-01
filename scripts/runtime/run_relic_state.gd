class_name RunRelicState
extends RefCounted

var instance_id: int = 0
var definition: RelicDefinition


static func create(
		relic_instance_id: int,
		relic_definition: RelicDefinition
) -> RunRelicState:
	if relic_instance_id <= 0 or relic_definition == null:
		return null
	var state: RunRelicState = RunRelicState.new()
	state.instance_id = relic_instance_id
	state.definition = relic_definition
	return state


func duplicate_state() -> RunRelicState:
	return RunRelicState.create(instance_id, definition)


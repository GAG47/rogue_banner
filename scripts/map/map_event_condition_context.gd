class_name MapEventConditionContext
extends ConditionContext

var run: RunState
var node: MapNodeState
var session: MapEventSessionState
var floor_number: int = 1


static func create(
	run_state: RunState,
	node_state: MapNodeState,
	event_session: MapEventSessionState,
	floor: int
) -> MapEventConditionContext:
	var context: MapEventConditionContext = MapEventConditionContext.new()
	context.run = run_state
	context.node = node_state
	context.session = event_session
	context.floor_number = floor
	return context

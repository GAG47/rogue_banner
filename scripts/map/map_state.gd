class_name MapState
extends RefCounted

var definition: MapDefinition
var generation_index: int = 0
var _nodes: Dictionary[int, MapNodeState] = {}
var _connections: Array[MapConnection] = []
var _current_node_id: int = 0
var _active_session: MapNodeSessionState


func get_node(node_instance_id: int) -> MapNodeState:
	var node: MapNodeState = _get_node_mutable(node_instance_id)
	return node.duplicate_state() if node != null else null


func get_nodes() -> Array[MapNodeState]:
	var result: Array[MapNodeState] = []
	for node: MapNodeState in _get_nodes_mutable():
		result.append(node.duplicate_state())
	return result


func get_connections() -> Array[MapConnection]:
	var result: Array[MapConnection] = []
	for connection: MapConnection in _connections:
		result.append(
			connection.duplicate_state() if connection != null else null
		)
	return result


func get_current_node_id() -> int:
	return _current_node_id


func get_current_node() -> MapNodeState:
	return get_node(_current_node_id)


func get_current_layer() -> int:
	var node: MapNodeState = _get_node_mutable(_current_node_id)
	return node.layer_index if node != null else 0


func get_active_session() -> MapNodeSessionState:
	return (
		_active_session.duplicate_state()
		if _active_session != null
		else null
	)


func get_reachable_node_ids() -> Array[int]:
	var result: Array[int] = []
	var current: MapNodeState = _get_node_mutable(_current_node_id)
	if (
		_active_session != null
		or current == null
		or current.status != GameEnums.MapNodeStatus.RESOLVED
	):
		return result
	for connection: MapConnection in _connections:
		if connection == null or connection.from_node_id != _current_node_id:
			continue
		var target: MapNodeState = _get_node_mutable(connection.to_node_id)
		if target != null and target.status == GameEnums.MapNodeStatus.UNVISITED:
			result.append(target.instance_id)
	result.sort()
	return result


func get_visible_node_ids() -> Array[int]:
	var result: Array[int] = []
	for node: MapNodeState in _get_nodes_mutable():
		if node.status != GameEnums.MapNodeStatus.UNVISITED:
			result.append(node.instance_id)
	for node_id: int in get_reachable_node_ids():
		if not result.has(node_id):
			result.append(node_id)
	result.sort()
	return result


func is_valid() -> bool:
	if (
		definition == null
		or generation_index < 0
		or _nodes.is_empty()
		or _current_node_id <= 0
	):
		return false
	var current: MapNodeState = _get_node_mutable(_current_node_id)
	if current == null:
		return false
	if _active_session == null:
		if current.status != GameEnums.MapNodeStatus.RESOLVED:
			return false
	elif (
		_active_session.session_id <= 0
		or _active_session.node_instance_id != _current_node_id
		or current.status != GameEnums.MapNodeStatus.ENTERED
	):
		return false

	var maximum_layer: int = definition.layer_count + 1
	var start_count: int = 0
	var boss_count: int = 0
	var incoming: Dictionary[int, bool] = {}
	var outgoing: Dictionary[int, bool] = {}
	for node_id: int in _nodes:
		var node: MapNodeState = _nodes[node_id] as MapNodeState
		if (
			node == null
			or node.instance_id != node_id
			or node.definition == null
			or node.layer_index < 0
			or node.layer_index > maximum_layer
			or node.column_index < 0
		):
			return false
		if node.definition.kind == GameEnums.MapNodeKind.START:
			start_count += 1
			if node.layer_index != 0:
				return false
		elif node.definition.kind == GameEnums.MapNodeKind.BOSS:
			boss_count += 1
			if node.layer_index != maximum_layer:
				return false
		elif node.layer_index == 0 or node.layer_index == maximum_layer:
			return false
	var seen_connections: Array[String] = []
	for connection: MapConnection in _connections:
		if (
			connection == null
			or not _nodes.has(connection.from_node_id)
			or not _nodes.has(connection.to_node_id)
		):
			return false
		var source: MapNodeState = _get_node_mutable(
				connection.from_node_id
		)
		var target: MapNodeState = _get_node_mutable(
				connection.to_node_id
		)
		if target.layer_index != source.layer_index + 1:
			return false
		var key: String = "%d:%d" % [
			connection.from_node_id,
			connection.to_node_id,
		]
		if seen_connections.has(key):
			return false
		seen_connections.append(key)
		outgoing[connection.from_node_id] = true
		incoming[connection.to_node_id] = true
	if start_count != 1 or boss_count != 1:
		return false
	for node: MapNodeState in _get_nodes_mutable():
		if node.layer_index > 0 and not incoming.has(node.instance_id):
			return false
		if (
			node.layer_index < maximum_layer
			and not outgoing.has(node.instance_id)
		):
			return false
	return true


func duplicate_state() -> MapState:
	var state: MapState = MapState.new()
	state.definition = definition
	state.generation_index = generation_index
	for node: MapNodeState in _get_nodes_mutable():
		state._nodes[node.instance_id] = node.duplicate_state()
	for connection: MapConnection in _connections:
		state._connections.append(
			connection.duplicate_state() if connection != null else null
		)
	state._current_node_id = _current_node_id
	state._active_session = (
		_active_session.duplicate_state()
		if _active_session != null
		else null
	)
	return state


func _get_node_mutable(node_instance_id: int) -> MapNodeState:
	return _nodes.get(node_instance_id) as MapNodeState


func _get_nodes_mutable() -> Array[MapNodeState]:
	var ids: Array[int] = []
	for node_id: int in _nodes:
		ids.append(node_id)
	ids.sort()
	var result: Array[MapNodeState] = []
	for node_id: int in ids:
		result.append(_nodes[node_id])
	return result


func _get_connections_mutable() -> Array[MapConnection]:
	return _connections


func _get_active_session_mutable() -> MapNodeSessionState:
	return _active_session


func _add_node(node: MapNodeState) -> bool:
	if (
		node == null
		or node.instance_id <= 0
		or node.definition == null
		or node.layer_index < 0
		or node.column_index < 0
		or _nodes.has(node.instance_id)
	):
		return false
	_nodes[node.instance_id] = node
	return true


func _add_connection(connection: MapConnection) -> bool:
	if (
		connection == null
		or not _nodes.has(connection.from_node_id)
		or not _nodes.has(connection.to_node_id)
	):
		return false
	var source: MapNodeState = _get_node_mutable(connection.from_node_id)
	var target: MapNodeState = _get_node_mutable(connection.to_node_id)
	if target.layer_index != source.layer_index + 1:
		return false
	for existing: MapConnection in _connections:
		if (
			existing.from_node_id == connection.from_node_id
			and existing.to_node_id == connection.to_node_id
		):
			return false
	_connections.append(connection)
	return true


func _set_initial_node(node_instance_id: int) -> bool:
	var node: MapNodeState = _get_node_mutable(node_instance_id)
	if (
		node == null
		or node.layer_index != 0
		or node.definition.kind != GameEnums.MapNodeKind.START
	):
		return false
	node.status = GameEnums.MapNodeStatus.RESOLVED
	_current_node_id = node_instance_id
	return true


func _enter_node(session: MapNodeSessionState) -> bool:
	if (
		session == null
		or session.session_id <= 0
		or _active_session != null
	):
		return false
	if not get_reachable_node_ids().has(session.node_instance_id):
		return false
	var node: MapNodeState = _get_node_mutable(session.node_instance_id)
	if node == null or node.status != GameEnums.MapNodeStatus.UNVISITED:
		return false
	node.status = GameEnums.MapNodeStatus.ENTERED
	_current_node_id = node.instance_id
	_active_session = session
	return true


func _resolve_current_node() -> bool:
	if _active_session == null:
		return false
	var node: MapNodeState = _get_node_mutable(_current_node_id)
	if (
		node == null
		or node.instance_id != _active_session.node_instance_id
		or node.status != GameEnums.MapNodeStatus.ENTERED
	):
		return false
	node.status = GameEnums.MapNodeStatus.RESOLVED
	_active_session = null
	return true

class_name MapGenerationService
extends RefCounted


func generate(request: MapGenerationRequest) -> MapGenerationResult:
	if (
		request == null
		or request.definition == null
		or request.generation_index < 0
		or not DefinitionValidator.new().validate(
				request.definition
		).is_valid()
	):
		return MapGenerationResult.failure(
				GameEnums.MapFlowCode.INVALID_DEFINITION
		)
	var definition: MapDefinition = request.definition
	var random: SeededRandomSource = SeededRandomSource.new(
			_map_seed(
					request.run_seed,
					request.generation_index,
					definition.content_id
			)
	)
	var state: MapState = MapState.new()
	state.definition = definition
	state.generation_index = request.generation_index
	var layers: Array[Array] = []
	var next_node_id: int = 1

	var start: MapNodeState = MapNodeState.create(
			next_node_id,
			0,
			0,
			definition.start_node
	)
	if not state._add_node(start):
		return MapGenerationResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	layers.append([next_node_id])
	next_node_id += 1

	var layer_sizes: Array[int] = []
	var layer_assignments: Array[Array] = []
	for layer_index: int in range(1, definition.layer_count + 1):
		var layer_size: int = random.next_int(
				definition.minimum_nodes_per_layer,
				definition.maximum_nodes_per_layer
		)
		layer_sizes.append(layer_size)
		var assignments: Array[MapNodeDefinition] = []
		assignments.resize(layer_size)
		layer_assignments.append(assignments)

	var counts: Array[int] = []
	counts.resize(definition.node_pool.size())
	counts.fill(0)
	var required_entry_indices: Array[int] = []
	for entry_index: int in range(definition.node_pool.size()):
		var entry: MapNodePoolEntry = definition.node_pool[entry_index]
		for required_index: int in range(entry.minimum_copies):
			required_entry_indices.append(entry_index)
	var slot_owners: Dictionary[Vector2i, int] = {}
	var item_offsets: Array[int] = []
	for item_index: int in range(required_entry_indices.size()):
		item_offsets.append(random.next_int(0, 2147483647))
		var visited_slots: Dictionary[Vector2i, bool] = {}
		if not _assign_required_item(
				item_index,
				required_entry_indices,
				definition.node_pool,
				layer_assignments,
				slot_owners,
				visited_slots,
				item_offsets
		):
			return MapGenerationResult.failure(
					GameEnums.MapFlowCode.INVALID_DEFINITION
			)
	for slot: Vector2i in slot_owners:
		var owner_index: int = slot_owners[slot]
		var entry: MapNodePoolEntry = definition.node_pool[
				required_entry_indices[owner_index]
		]
		(layer_assignments[slot.x] as Array)[slot.y] = entry.node_definition
		counts[required_entry_indices[owner_index]] += 1

	for layer_offset: int in range(layer_assignments.size()):
		var layer_number: int = layer_offset + 1
		var assignments: Array = layer_assignments[layer_offset]
		for column_index: int in range(assignments.size()):
			if assignments[column_index] != null:
				continue
			var eligible: Array[MapNodePoolEntry] = []
			var eligible_indices: Array[int] = []
			var weights: Array[float] = []
			for entry_index: int in range(definition.node_pool.size()):
				var entry: MapNodePoolEntry = definition.node_pool[entry_index]
				if not _entry_can_fill(
						entry,
						layer_number,
						counts[entry_index]
				):
					continue
				eligible.append(entry)
				eligible_indices.append(entry_index)
				weights.append(entry.weight)
			if eligible.is_empty():
				return MapGenerationResult.failure(
						GameEnums.MapFlowCode.INVALID_DEFINITION
				)
			var selected_index: int = random.choose_weighted_index(weights)
			if selected_index < 0:
				return MapGenerationResult.failure(
						GameEnums.MapFlowCode.INTERNAL_FAILURE
				)
			var selected: MapNodePoolEntry = eligible[selected_index]
			assignments[column_index] = selected.node_definition
			counts[eligible_indices[selected_index]] += 1

		var layer_ids: Array[int] = []
		for column_index: int in range(assignments.size()):
			var node: MapNodeState = MapNodeState.create(
					next_node_id,
					layer_number,
					column_index,
					assignments[column_index] as MapNodeDefinition
			)
			if not state._add_node(node):
				return MapGenerationResult.failure(
						GameEnums.MapFlowCode.INTERNAL_FAILURE
				)
			layer_ids.append(next_node_id)
			next_node_id += 1
		layers.append(layer_ids)

	var boss: MapNodeState = MapNodeState.create(
			next_node_id,
			definition.layer_count + 1,
			0,
			definition.boss_node
	)
	if not state._add_node(boss):
		return MapGenerationResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	layers.append([next_node_id])

	for layer_index: int in range(layers.size() - 1):
		if not _connect_layers(
				state,
				layers[layer_index],
				layers[layer_index + 1],
				random,
				definition.extra_connection_chance
		):
			return MapGenerationResult.failure(
					GameEnums.MapFlowCode.INTERNAL_FAILURE
			)
	if not state._set_initial_node(start.instance_id) or not state.is_valid():
		return MapGenerationResult.failure(GameEnums.MapFlowCode.INTERNAL_FAILURE)
	return MapGenerationResult.success(state)


func _assign_required_item(
	item_index: int,
	required_entry_indices: Array[int],
	pool: Array[MapNodePoolEntry],
	layer_assignments: Array[Array],
	slot_owners: Dictionary[Vector2i, int],
	visited_slots: Dictionary[Vector2i, bool],
	item_offsets: Array[int]
) -> bool:
	var entry: MapNodePoolEntry = pool[required_entry_indices[item_index]]
	var candidates: Array[Vector2i] = []
	for layer_offset: int in range(layer_assignments.size()):
		var layer_number: int = layer_offset + 1
		if not _entry_allows_layer(entry, layer_number, layer_assignments.size()):
			continue
		var assignments: Array = layer_assignments[layer_offset]
		for column_index: int in range(assignments.size()):
			candidates.append(Vector2i(layer_offset, column_index))
	if candidates.is_empty():
		return false
	var offset: int = item_offsets[item_index] % candidates.size()
	for candidate_index: int in range(candidates.size()):
		var slot: Vector2i = candidates[
				(candidate_index + offset) % candidates.size()
		]
		if visited_slots.has(slot):
			continue
		visited_slots[slot] = true
		var previous_owner: int = slot_owners.get(slot, -1)
		if (
			previous_owner < 0
			or _assign_required_item(
					previous_owner,
					required_entry_indices,
					pool,
					layer_assignments,
					slot_owners,
					visited_slots,
					item_offsets
			)
		):
			slot_owners[slot] = item_index
			return true
	return false


func _entry_can_fill(
	entry: MapNodePoolEntry,
	layer_number: int,
	current_count: int
) -> bool:
	if entry == null or not _entry_allows_layer(entry, layer_number, 0):
		return false
	return (
		entry.maximum_copies == 0
		or current_count < entry.maximum_copies
	)


func _entry_allows_layer(
	entry: MapNodePoolEntry,
	layer_number: int,
	_layer_count: int
) -> bool:
	return (
		entry != null
		and layer_number >= entry.minimum_layer
		and (
			entry.maximum_layer == 0
			or layer_number <= entry.maximum_layer
		)
	)


func _connect_layers(
	state: MapState,
	sources: Array,
	targets: Array,
	random: SeededRandomSource,
	extra_chance: float
) -> bool:
	if sources.is_empty() or targets.is_empty():
		return false
	var offset: int = random.next_int(0, targets.size() - 1)
	for source_index: int in range(sources.size()):
		var target_index: int = (source_index + offset) % targets.size()
		if not _add_connection_if_missing(
				state,
				sources[source_index],
				targets[target_index]
		):
			return false

	for target_index: int in range(targets.size()):
		if _has_incoming(state, targets[target_index], sources):
			continue
		var source_index: int = (target_index + offset) % sources.size()
		if not _add_connection_if_missing(
				state,
				sources[source_index],
				targets[target_index]
		):
			return false

	if targets.size() > 1:
		for source_index: int in range(sources.size()):
			if random.next_float() > extra_chance:
				continue
			var target_index: int = (
					source_index + offset + 1
			) % targets.size()
			_add_connection_if_missing(
					state,
					sources[source_index],
					targets[target_index]
			)
	return true


func _has_incoming(state: MapState, target_id: int, sources: Array) -> bool:
	for connection: MapConnection in state._get_connections_mutable():
		if (
			connection.to_node_id == target_id
			and sources.has(connection.from_node_id)
		):
			return true
	return false


func _add_connection_if_missing(
	state: MapState,
	from_node_id: int,
	to_node_id: int
) -> bool:
	for connection: MapConnection in state._get_connections_mutable():
		if (
			connection.from_node_id == from_node_id
			and connection.to_node_id == to_node_id
		):
			return true
	return state._add_connection(MapConnection.create(from_node_id, to_node_id))


func _map_seed(
	run_seed: int,
	generation_index: int,
	map_id: StringName
) -> int:
	return (
		run_seed * 1664525
		+ generation_index * 1013904223
		+ String(map_id).hash()
	)

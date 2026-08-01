class_name BattleReadModelService
extends RefCounted

var _attribute_calculator: AttributeCalculator = AttributeCalculator.new()
var _intent_preview_service: IntentPreviewService = IntentPreviewService.new()


func build(source: BattleState) -> BattleReadModel:
	if source == null or source.grid == null:
		return null
	var battle: BattleState = source.duplicate_state()
	if battle == null or battle.grid == null:
		return null
	var model: BattleReadModel = BattleReadModel.new()
	model.phase = battle.phase
	model.active_side = battle.active_side
	model.round_number = battle.round_number
	model.grid_width = battle.grid.width
	model.grid_height = battle.grid.height
	_build_cells(battle, model)
	_build_units(battle, model)
	_build_intents(battle, model)
	return model


func _build_cells(battle: BattleState, model: BattleReadModel) -> void:
	for y: int in range(battle.grid.height):
		for x: int in range(battle.grid.width):
			var coordinate: Vector2i = Vector2i(x, y)
			var source_cell: CellState = battle.grid.get_cell(coordinate)
			var cell: BattleCellReadModel = BattleCellReadModel.new()
			cell.coordinate = coordinate
			if source_cell != null and source_cell.terrain != null:
				cell.terrain_name = source_cell.terrain.display_name
				cell.movement_cost = source_cell.terrain.movement_cost
				cell.blocks_movement = source_cell.terrain.blocks_movement
				cell.blocks_line_of_sight = (
					source_cell.terrain.blocks_line_of_sight
				)
			var occupant: GridOccupant = battle.grid.get_occupant(coordinate)
			if occupant != null:
				cell.occupant_kind = occupant.kind
				cell.occupant_runtime_id = occupant.runtime_id
			model.cells[coordinate] = cell


func _build_units(battle: BattleState, model: BattleReadModel) -> void:
	for source_unit: UnitState in battle.get_units():
		var unit: BattleUnitReadModel = BattleUnitReadModel.new()
		unit.instance_id = source_unit.instance_id
		unit.side = source_unit.side
		if source_unit.definition != null:
			unit.content_id = source_unit.definition.content_id
			unit.display_name = source_unit.definition.display_name
		unit.current_health = source_unit.current_health
		unit.maximum_health = _attribute_calculator.calculate(
				source_unit,
				GameEnums.AttributeType.MAX_HEALTH
		)
		unit.current_ap = source_unit.current_ap
		unit.maximum_ap = _attribute_calculator.calculate(
				source_unit,
				GameEnums.AttributeType.MAX_AP
		)
		unit.current_shield = source_unit.current_shield
		var position: GridCoordinate = battle.grid.find_occupant(
				GameEnums.GridOccupantKind.UNIT,
				source_unit.instance_id
		)
		if position != null:
			unit.has_coordinate = true
			unit.coordinate = position.value
		for slot_index: int in range(source_unit.arts.size()):
			var source_art: ArtState = source_unit.arts[slot_index]
			if source_art == null or source_art.definition == null:
				continue
			unit.arts.append(_build_art(source_art, slot_index))
		for source_buff: BuffState in source_unit.get_buffs():
			if source_buff == null or source_buff.definition == null:
				continue
			var buff: BattleBuffReadModel = BattleBuffReadModel.new()
			buff.instance_id = source_buff.instance_id
			buff.content_id = source_buff.definition.content_id
			buff.display_name = source_buff.definition.display_name
			buff.stacks = source_buff.stacks
			buff.remaining_turns = source_buff.remaining_turns
			unit.buffs.append(buff)
		model.units.append(unit)


func _build_art(
		source: ArtState,
		slot_index: int
) -> BattleArtReadModel:
	var art: BattleArtReadModel = BattleArtReadModel.new()
	art.slot_index = slot_index
	art.content_id = source.definition.content_id
	art.display_name = source.definition.display_name
	art.category = source.definition.category
	art.ap_cost = source.definition.ap_cost
	art.base_cooldown = source.definition.cooldown
	art.current_cooldown = source.current_cooldown
	if source.definition.targeting != null:
		var targeting: TargetingDefinition = source.definition.targeting
		art.target_kind = targeting.target_kind
		art.target_relation = targeting.target_relation
		art.minimum_range = targeting.minimum_range
		art.maximum_range = targeting.maximum_range
		art.minimum_targets = targeting.minimum_targets
		art.maximum_targets = targeting.maximum_targets
		art.requires_line_of_sight = targeting.requires_line_of_sight
	return art


func _build_intents(battle: BattleState, model: BattleReadModel) -> void:
	for source: IntentPreview in _intent_preview_service.build_all(battle):
		if source == null:
			continue
		var intent: BattleIntentReadModel = BattleIntentReadModel.new()
		intent.actor_unit_id = source.actor_unit_id
		var actor: BattleUnitReadModel = model.get_unit(source.actor_unit_id)
		if actor != null:
			intent.actor_name = actor.display_name
		intent.intent_name = source.intent_name
		if source.art_definition != null:
			intent.art_name = source.art_definition.display_name
		intent.kind = source.kind
		intent.generation_round = source.generation_round
		intent.phase_id = source.phase_id
		intent.direction = source.direction
		if source.locked_targets != null:
			intent.locked_unit_ids.assign(
					source.locked_targets.unit_instance_ids
			)
			intent.locked_cells.assign(source.locked_targets.cells)
			intent.locked_scene_object_ids.assign(
					source.locked_targets.terrain_object_instance_ids
			)
		intent.has_move_destination = source.has_move_destination
		intent.move_destination = source.move_destination
		intent.movement_path.assign(source.movement_path)
		intent.aim_cells.assign(source.aim_cells)
		intent.affected_cells.assign(source.affected_cells)
		intent.currently_valid = source.currently_valid
		model.intents.append(intent)

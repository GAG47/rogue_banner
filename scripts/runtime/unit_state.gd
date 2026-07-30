class_name UnitState
extends RefCounted

var instance_id: int = 0
var source_run_unit_id: int = 0
var definition: UnitDefinition
var side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var current_health: int = 0
var current_ap: int = 0
var current_shield: int = 0
var arts: Array[ArtState] = []
var _buffs: Array[BuffState] = []
var _next_buff_instance_id: int = 1


static func create(
		unit_instance_id: int,
		unit_definition: UnitDefinition,
		battle_side: GameEnums.BattleSide
) -> UnitState:
	var state: UnitState = UnitState.new()
	state.instance_id = unit_instance_id
	state.definition = unit_definition
	state.side = battle_side

	if unit_definition == null:
		return null
	var run_template: RunUnitState = RunUnitState.create(0, unit_definition)
	if run_template == null:
		return null

	state.current_health = unit_definition.max_health
	state.current_ap = unit_definition.max_ap
	state._initialize_art_slots(run_template.installed_arts)
	return state


static func create_from_run_unit(
		unit_instance_id: int,
		run_unit: RunUnitState,
		battle_side: GameEnums.BattleSide
) -> UnitState:
	var state: UnitState = UnitState.new()
	state.instance_id = unit_instance_id
	state.side = battle_side

	if (
		run_unit == null
		or run_unit.definition == null
		or not ArtLoadoutService.new().validate_loadout(run_unit).succeeded()
	):
		return null

	state.source_run_unit_id = run_unit.instance_id
	state.definition = run_unit.definition
	state.current_health = clampi(
			run_unit.current_health,
			0,
			run_unit.definition.max_health
	)
	state.current_ap = run_unit.definition.max_ap
	state._initialize_art_slots(run_unit.installed_arts)
	return state


func refresh_for_turn(maximum_ap: int = -1) -> void:
	if definition == null or is_defeated():
		return
	current_ap = definition.max_ap if maximum_ap < 0 else maximum_ap
	for art_state: ArtState in arts:
		if art_state != null:
			art_state.advance_cooldown()


func is_defeated() -> bool:
	return current_health <= 0


func duplicate_state() -> UnitState:
	var state: UnitState = UnitState.new()
	state._copy_from(self)
	return state


func _copy_from(source: UnitState) -> void:
	if source == null:
		return
	instance_id = source.instance_id
	source_run_unit_id = source.source_run_unit_id
	definition = source.definition
	side = source.side
	current_health = source.current_health
	current_ap = source.current_ap
	current_shield = source.current_shield
	_copy_art_states(source.arts)
	_copy_buff_states(source._buffs)
	_next_buff_instance_id = source._next_buff_instance_id


func get_buffs() -> Array[BuffState]:
	var result: Array[BuffState] = []
	result.assign(_buffs)
	return result


func find_buff(definition_to_find: BuffDefinition) -> BuffState:
	for buff: BuffState in _buffs:
		if buff != null and buff.definition == definition_to_find:
			return buff
	return null


func _allocate_buff_id() -> int:
	var allocated_id: int = _next_buff_instance_id
	_next_buff_instance_id += 1
	return allocated_id


func _add_buff(buff: BuffState) -> bool:
	if buff == null or buff.definition == null or buff.instance_id <= 0:
		return false
	_buffs.append(buff)
	return true


func _remove_buff(buff_instance_id: int) -> BuffState:
	for index: int in range(_buffs.size()):
		var buff: BuffState = _buffs[index]
		if buff != null and buff.instance_id == buff_instance_id:
			_buffs.remove_at(index)
			return buff
	return null


func _initialize_art_slots(definitions: Array[ArtDefinition]) -> void:
	arts.clear()
	var slot_count: int = definition.slot_count if definition != null else 0
	for slot_index: int in range(slot_count):
		var art_definition: ArtDefinition
		if slot_index < definitions.size():
			art_definition = definitions[slot_index]
		arts.append(
				ArtState.create(art_definition)
				if art_definition != null
				else null
		)


func _copy_art_states(source_arts: Array[ArtState]) -> void:
	while arts.size() > source_arts.size():
		arts.remove_at(arts.size() - 1)
	for index: int in range(source_arts.size()):
		var source_art: ArtState = source_arts[index]
		if index >= arts.size():
			arts.append(
					source_art.duplicate_state()
					if source_art != null
					else null
			)
		elif source_art == null:
			arts[index] = null
		elif arts[index] == null:
			arts[index] = source_art.duplicate_state()
		else:
			arts[index]._copy_from(source_art)


func _copy_buff_states(source_buffs: Array[BuffState]) -> void:
	var existing_by_id: Dictionary[int, BuffState] = {}
	for buff: BuffState in _buffs:
		if buff != null:
			existing_by_id[buff.instance_id] = buff

	var copied_buffs: Array[BuffState] = []
	for source_buff: BuffState in source_buffs:
		if source_buff == null:
			continue
		var copied_buff: BuffState = existing_by_id.get(
				source_buff.instance_id
		) as BuffState
		if copied_buff == null:
			copied_buff = source_buff.duplicate_state()
		else:
			copied_buff._copy_from(source_buff)
		copied_buffs.append(copied_buff)
	_buffs.assign(copied_buffs)

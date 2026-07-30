class_name BattleState
extends RefCounted

var grid: GridState
var phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var active_side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var round_number: int = 0
var _units: Dictionary[int, UnitState] = {}
var _next_unit_instance_id: int = 1
var _next_event_sequence_id: int = 1


static func create(grid_state: GridState) -> BattleState:
	var state: BattleState = BattleState.new()
	state.grid = grid_state
	return state


func get_unit(unit_id: int) -> UnitState:
	if not _units.has(unit_id):
		return null
	return _units[unit_id]


func get_units() -> Array[UnitState]:
	var unit_ids: Array[int] = []
	for unit_id: int in _units:
		unit_ids.append(unit_id)
	unit_ids.sort()

	var result: Array[UnitState] = []
	for unit_id: int in unit_ids:
		result.append(_units[unit_id])
	return result


func get_units_for_side(side: GameEnums.BattleSide) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit: UnitState in get_units():
		if unit.side == side:
			result.append(unit)
	return result


func unit_count() -> int:
	return _units.size()


func duplicate_state() -> BattleState:
	var state: BattleState = BattleState.new()
	state.grid = grid.duplicate_state() if grid != null else null
	state.phase = phase
	state.active_side = active_side
	state.round_number = round_number
	state._next_unit_instance_id = _next_unit_instance_id
	state._next_event_sequence_id = _next_event_sequence_id
	for unit: UnitState in get_units():
		state._units[unit.instance_id] = unit.duplicate_state()
	return state


func _commit_from(source: BattleState) -> bool:
	if (
		source == null
		or source.grid == null
		or grid == null
		or grid.width != source.grid.width
		or grid.height != source.grid.height
	):
		return false
	if not grid._copy_from(source.grid):
		return false

	var source_unit_ids: Dictionary[int, bool] = {}
	for source_unit: UnitState in source.get_units():
		source_unit_ids[source_unit.instance_id] = true
		var existing: UnitState = get_unit(source_unit.instance_id)
		if existing == null:
			_units[source_unit.instance_id] = source_unit.duplicate_state()
		else:
			existing._copy_from(source_unit)

	var removed_unit_ids: Array[int] = []
	for unit_id: int in _units:
		if not source_unit_ids.has(unit_id):
			removed_unit_ids.append(unit_id)
	for unit_id: int in removed_unit_ids:
		_units.erase(unit_id)

	phase = source.phase
	active_side = source.active_side
	round_number = source.round_number
	_next_unit_instance_id = source._next_unit_instance_id
	_next_event_sequence_id = source._next_event_sequence_id
	return true


func _allocate_unit_id() -> int:
	var allocated_id: int = _next_unit_instance_id
	_next_unit_instance_id += 1
	return allocated_id


func _register_unit(unit: UnitState) -> bool:
	if unit == null or unit.instance_id <= 0 or _units.has(unit.instance_id):
		return false
	_units[unit.instance_id] = unit
	return true


func _remove_unit(unit_id: int) -> UnitState:
	var unit: UnitState = get_unit(unit_id)
	if unit == null:
		return null
	_units.erase(unit_id)
	return unit


func _stamp_event(event: BattleEvent) -> bool:
	if event == null or event.sequence_id != 0:
		return false
	event.stamp(_next_event_sequence_id)
	_next_event_sequence_id += 1
	return true

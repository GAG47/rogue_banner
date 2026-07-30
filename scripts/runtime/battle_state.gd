class_name BattleState
extends RefCounted

var grid: GridState
var phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var active_side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var round_number: int = 0
var _units: Dictionary[int, UnitState] = {}
var _next_unit_instance_id: int = 1


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

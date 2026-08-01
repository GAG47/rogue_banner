class_name BattleState
extends RefCounted

var grid: GridState
var phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var active_side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var round_number: int = 0
var battle_seed: int = 0
var battle_session_id: int = 0
var _units: Dictionary[int, UnitState] = {}
var _enemy_states: Dictionary[int, EnemyState] = {}
var _relics: Dictionary[int, BattleRelicState] = {}
var _scrolls: Dictionary[int, BattleScrollStackState] = {}
var _run_participants: Dictionary[int, int] = {}
var _next_unit_instance_id: int = 1
var _next_event_sequence_id: int = 1


static func create(grid_state: GridState, seed: int = 0) -> BattleState:
	var state: BattleState = BattleState.new()
	state.grid = grid_state
	state.battle_seed = seed
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


func get_enemy_state(unit_id: int) -> EnemyState:
	if not _enemy_states.has(unit_id):
		return null
	return _enemy_states[unit_id]


func get_enemy_states() -> Array[EnemyState]:
	var unit_ids: Array[int] = []
	for unit_id: int in _enemy_states:
		unit_ids.append(unit_id)
	unit_ids.sort()
	var result: Array[EnemyState] = []
	for unit_id: int in unit_ids:
		result.append(_enemy_states[unit_id])
	return result


func get_relic(relic_instance_id: int) -> BattleRelicState:
	return _relics.get(relic_instance_id) as BattleRelicState


func get_relics() -> Array[BattleRelicState]:
	var ids: Array[int] = []
	for relic_id: int in _relics:
		ids.append(relic_id)
	ids.sort()
	var result: Array[BattleRelicState] = []
	for relic_id: int in ids:
		result.append(_relics[relic_id])
	return result


func get_scroll(stack_instance_id: int) -> BattleScrollStackState:
	return _scrolls.get(stack_instance_id) as BattleScrollStackState


func get_scrolls() -> Array[BattleScrollStackState]:
	var ids: Array[int] = []
	for stack_id: int in _scrolls:
		ids.append(stack_id)
	ids.sort()
	var result: Array[BattleScrollStackState] = []
	for stack_id: int in ids:
		result.append(_scrolls[stack_id])
	return result


func get_run_participant_battle_ids() -> Array[int]:
	var result: Array[int] = []
	for battle_unit_id: int in _run_participants:
		result.append(battle_unit_id)
	result.sort()
	return result


func get_run_unit_id(battle_unit_id: int) -> int:
	return _run_participants.get(battle_unit_id, 0)


func duplicate_state() -> BattleState:
	var state: BattleState = BattleState.new()
	state.grid = grid.duplicate_state() if grid != null else null
	state.phase = phase
	state.active_side = active_side
	state.round_number = round_number
	state.battle_seed = battle_seed
	state.battle_session_id = battle_session_id
	state._next_unit_instance_id = _next_unit_instance_id
	state._next_event_sequence_id = _next_event_sequence_id
	for unit: UnitState in get_units():
		state._units[unit.instance_id] = unit.duplicate_state()
	for enemy_state: EnemyState in get_enemy_states():
		state._enemy_states[enemy_state.unit_instance_id] = (
			enemy_state.duplicate_state()
		)
	for relic: BattleRelicState in get_relics():
		state._relics[relic.instance_id] = relic.duplicate_state()
	for stack: BattleScrollStackState in get_scrolls():
		state._scrolls[stack.instance_id] = stack.duplicate_state()
	for battle_unit_id: int in _run_participants:
		state._run_participants[battle_unit_id] = (
			_run_participants[battle_unit_id]
		)
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

	var source_enemy_ids: Dictionary[int, bool] = {}
	for source_enemy: EnemyState in source.get_enemy_states():
		source_enemy_ids[source_enemy.unit_instance_id] = true
		var existing_enemy: EnemyState = get_enemy_state(
				source_enemy.unit_instance_id
		)
		if existing_enemy == null:
			_enemy_states[source_enemy.unit_instance_id] = (
				source_enemy.duplicate_state()
			)
		else:
			existing_enemy._copy_from(source_enemy)
	var removed_enemy_ids: Array[int] = []
	for enemy_id: int in _enemy_states:
		if not source_enemy_ids.has(enemy_id):
			removed_enemy_ids.append(enemy_id)
	for enemy_id: int in removed_enemy_ids:
		_enemy_states.erase(enemy_id)

	_relics.clear()
	for source_relic: BattleRelicState in source.get_relics():
		_relics[source_relic.instance_id] = source_relic.duplicate_state()
	_scrolls.clear()
	for source_stack: BattleScrollStackState in source.get_scrolls():
		_scrolls[source_stack.instance_id] = source_stack.duplicate_state()
	_run_participants.clear()
	for battle_unit_id: int in source._run_participants:
		_run_participants[battle_unit_id] = (
			source._run_participants[battle_unit_id]
		)

	phase = source.phase
	active_side = source.active_side
	round_number = source.round_number
	battle_seed = source.battle_seed
	battle_session_id = source.battle_session_id
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


func _register_enemy_state(enemy_state: EnemyState) -> bool:
	if (
		enemy_state == null
		or enemy_state.unit_instance_id <= 0
		or not _units.has(enemy_state.unit_instance_id)
		or _enemy_states.has(enemy_state.unit_instance_id)
	):
		return false
	_enemy_states[enemy_state.unit_instance_id] = enemy_state
	return true


func _register_relic(relic: BattleRelicState) -> bool:
	if (
		relic == null
		or relic.instance_id <= 0
		or _relics.has(relic.instance_id)
	):
		return false
	_relics[relic.instance_id] = relic
	return true


func _register_scroll(stack: BattleScrollStackState) -> bool:
	if (
		stack == null
		or stack.instance_id <= 0
		or _scrolls.has(stack.instance_id)
	):
		return false
	_scrolls[stack.instance_id] = stack
	return true


func _register_run_participant(
		battle_unit_id: int,
		run_unit_id: int
) -> bool:
	if (
		battle_unit_id <= 0
		or run_unit_id <= 0
		or not _units.has(battle_unit_id)
		or _run_participants.has(battle_unit_id)
	):
		return false
	_run_participants[battle_unit_id] = run_unit_id
	return true


func _remove_unit(unit_id: int) -> UnitState:
	var unit: UnitState = get_unit(unit_id)
	if unit == null:
		return null
	_units.erase(unit_id)
	_enemy_states.erase(unit_id)
	return unit


func _stamp_event(event: BattleEvent) -> bool:
	if event == null or event.sequence_id != 0:
		return false
	event.stamp(_next_event_sequence_id)
	_next_event_sequence_id += 1
	return true

class_name RunState
extends RefCounted

var _hero_definition: HeroDefinition
var _run_seed: int = 0
var _team_capacity: int = 4
var _scroll_slot_capacity: int = 3
var _phase: GameEnums.RunPhase = GameEnums.RunPhase.READY
var _end_reason: GameEnums.RunEndReason = GameEnums.RunEndReason.NONE
var _gold: int = 0
var _units: Dictionary[int, RunUnitState] = {}
var _arts: Dictionary[int, RunArtState] = {}
var _relics: Dictionary[int, RunRelicState] = {}
var _scrolls: Dictionary[int, ScrollStackState] = {}
var _next_unit_instance_id: int = 1
var _next_art_instance_id: int = 1
var _next_relic_instance_id: int = 1
var _next_scroll_stack_instance_id: int = 1
var _next_battle_session_id: int = 1
var _next_offer_id: int = 1
var _next_progression_session_id: int = 1
var _reward_generation_count: int = 0
var _map_generation_count: int = 0
var _state_version: int = 1
var _active_battle_session: RunBattleSessionState
var _active_offer: RewardOffer
var _map_state: MapState


static func create(hero: HeroDefinition, seed: int) -> RunState:
	return create_from_setup(RunSetup.create(hero, seed))


static func create_from_setup(setup: RunSetup) -> RunState:
	if (
		setup == null
		or not setup.is_valid()
		or not DefinitionValidator.new().validate(
				setup.hero_definition
		).is_valid()
	):
		return null

	var state: RunState = RunState.new()
	state._hero_definition = setup.hero_definition
	state._run_seed = setup.seed
	state._team_capacity = setup.team_capacity
	state._scroll_slot_capacity = setup.scroll_slot_capacity
	state._gold = setup.starting_gold

	for unit_definition: UnitDefinition in setup.hero_definition.starting_units:
		if not state._create_unit_with_defaults(unit_definition):
			return null
	for relic_definition: RelicDefinition in setup.hero_definition.starting_relics:
		if not state._create_relic(relic_definition):
			return null
	return state


func get_phase() -> GameEnums.RunPhase:
	return _phase


func get_end_reason() -> GameEnums.RunEndReason:
	return _end_reason


func get_hero_definition() -> HeroDefinition:
	return _hero_definition


func get_run_seed() -> int:
	return _run_seed


func get_team_capacity() -> int:
	return _team_capacity


func get_scroll_slot_capacity() -> int:
	return _scroll_slot_capacity


func get_gold() -> int:
	return _gold


func get_state_version() -> int:
	return _state_version


func get_reward_generation_count() -> int:
	return _reward_generation_count


func get_map_generation_count() -> int:
	return _map_generation_count


func get_map_state() -> MapState:
	return _map_state.duplicate_state() if _map_state != null else null


func get_active_battle_session() -> RunBattleSessionState:
	return (
			_active_battle_session.duplicate_state()
			if _active_battle_session != null
			else null
	)


func get_active_offer() -> RewardOffer:
	return (
			_active_offer.duplicate_state()
			if _active_offer != null
			else null
	)


func get_unit(unit_instance_id: int) -> RunUnitState:
	var unit: RunUnitState = _get_unit_mutable(unit_instance_id)
	return unit.duplicate_state() if unit != null else null


func get_units() -> Array[RunUnitState]:
	var ids: Array[int] = []
	for unit_id: int in _units:
		ids.append(unit_id)
	ids.sort()
	var result: Array[RunUnitState] = []
	for unit_id: int in ids:
		result.append((_units[unit_id] as RunUnitState).duplicate_state())
	return result


func get_art(art_instance_id: int) -> RunArtState:
	var art: RunArtState = _get_art_mutable(art_instance_id)
	return art.duplicate_state() if art != null else null


func get_arts() -> Array[RunArtState]:
	var ids: Array[int] = []
	for art_id: int in _arts:
		ids.append(art_id)
	ids.sort()
	var result: Array[RunArtState] = []
	for art_id: int in ids:
		result.append((_arts[art_id] as RunArtState).duplicate_state())
	return result


func get_uninstalled_arts() -> Array[RunArtState]:
	var result: Array[RunArtState] = []
	for art: RunArtState in get_arts():
		if not is_art_installed(art.instance_id):
			result.append(art)
	return result


func get_relic(relic_instance_id: int) -> RunRelicState:
	var relic: RunRelicState = _get_relic_mutable(relic_instance_id)
	return relic.duplicate_state() if relic != null else null


func get_relics() -> Array[RunRelicState]:
	var ids: Array[int] = []
	for relic_id: int in _relics:
		ids.append(relic_id)
	ids.sort()
	var result: Array[RunRelicState] = []
	for relic_id: int in ids:
		result.append((_relics[relic_id] as RunRelicState).duplicate_state())
	return result


func get_scroll(stack_instance_id: int) -> ScrollStackState:
	var stack: ScrollStackState = _get_scroll_mutable(stack_instance_id)
	return stack.duplicate_state() if stack != null else null


func get_scrolls() -> Array[ScrollStackState]:
	var ids: Array[int] = []
	for stack_id: int in _scrolls:
		ids.append(stack_id)
	ids.sort()
	var result: Array[ScrollStackState] = []
	for stack_id: int in ids:
		result.append(
				(_scrolls[stack_id] as ScrollStackState).duplicate_state()
		)
	return result


func get_installed_art_states(
		unit: RunUnitState
) -> Array[RunArtState]:
	var result: Array[RunArtState] = []
	if unit == null or unit.definition == null:
		return result
	for art_id: int in unit.installed_art_instance_ids:
		result.append(get_art(art_id) if art_id > 0 else null)
	return result


func get_installed_art_definitions(
		unit: RunUnitState
) -> Array[ArtDefinition]:
	var result: Array[ArtDefinition] = []
	for art: RunArtState in get_installed_art_states(unit):
		result.append(art.definition if art != null else null)
	return result


func is_art_installed(art_instance_id: int) -> bool:
	if art_instance_id <= 0:
		return false
	for unit: RunUnitState in _get_units_mutable():
		if unit.installed_art_instance_ids.has(art_instance_id):
			return true
	return false


func find_art_owner(art_instance_id: int) -> RunUnitState:
	var unit: RunUnitState = _find_art_owner_mutable(art_instance_id)
	return unit.duplicate_state() if unit != null else null


func _find_art_owner_mutable(art_instance_id: int) -> RunUnitState:
	for unit: RunUnitState in _get_units_mutable():
		if unit.installed_art_instance_ids.has(art_instance_id):
			return unit
	return null


func count_available_units() -> int:
	var count: int = 0
	for unit: RunUnitState in _get_units_mutable():
		if not unit.is_defeated():
			count += 1
	return count


func count_relic_definition(definition: RelicDefinition) -> int:
	var count: int = 0
	for relic: RunRelicState in _get_relics_mutable():
		if relic.definition == definition:
			count += 1
	return count


func total_scroll_quantity(definition: ScrollDefinition) -> int:
	var total: int = 0
	for stack: ScrollStackState in _get_scrolls_mutable():
		if stack.definition == definition:
			total += stack.quantity
	return total


func duplicate_state() -> RunState:
	var state: RunState = RunState.new()
	state._copy_from(self)
	return state


func _copy_from(source: RunState) -> void:
	if source == null:
		return
	_hero_definition = source._hero_definition
	_run_seed = source._run_seed
	_team_capacity = source._team_capacity
	_scroll_slot_capacity = source._scroll_slot_capacity
	_phase = source._phase
	_end_reason = source._end_reason
	_gold = source._gold
	_units.clear()
	for unit: RunUnitState in source._get_units_mutable():
		_units[unit.instance_id] = unit.duplicate_state()
	_arts.clear()
	for art: RunArtState in source._get_arts_mutable():
		_arts[art.instance_id] = art.duplicate_state()
	_relics.clear()
	for relic: RunRelicState in source._get_relics_mutable():
		_relics[relic.instance_id] = relic.duplicate_state()
	_scrolls.clear()
	for stack: ScrollStackState in source._get_scrolls_mutable():
		_scrolls[stack.instance_id] = stack.duplicate_state()
	_next_unit_instance_id = source._next_unit_instance_id
	_next_art_instance_id = source._next_art_instance_id
	_next_relic_instance_id = source._next_relic_instance_id
	_next_scroll_stack_instance_id = source._next_scroll_stack_instance_id
	_next_battle_session_id = source._next_battle_session_id
	_next_offer_id = source._next_offer_id
	_next_progression_session_id = source._next_progression_session_id
	_reward_generation_count = source._reward_generation_count
	_map_generation_count = source._map_generation_count
	_state_version = source._state_version
	_active_battle_session = (
		source._active_battle_session.duplicate_state()
		if source._active_battle_session != null
		else null
	)
	_active_offer = (
		source._active_offer.duplicate_state()
		if source._active_offer != null
		else null
	)
	_map_state = (
		source._map_state.duplicate_state()
		if source._map_state != null
		else null
	)


func _commit_from(source: RunState, expected_version: int) -> bool:
	if source == null or _state_version != expected_version:
		return false
	_copy_from(source)
	_state_version += 1
	return true


func _set_phase(value: GameEnums.RunPhase) -> void:
	_phase = value


func _set_end_reason(value: GameEnums.RunEndReason) -> void:
	_end_reason = value


func _set_map_state(value: MapState) -> void:
	_map_state = value


func _get_map_state_mutable() -> MapState:
	return _map_state


func _set_active_battle_session(
		session: RunBattleSessionState
) -> void:
	_active_battle_session = session


func _get_active_battle_session_mutable() -> RunBattleSessionState:
	return _active_battle_session


func _set_active_offer(offer: RewardOffer) -> void:
	_active_offer = offer


func _get_active_offer_mutable() -> RewardOffer:
	return _active_offer


func _get_unit_mutable(unit_instance_id: int) -> RunUnitState:
	return _units.get(unit_instance_id) as RunUnitState


func _get_units_mutable() -> Array[RunUnitState]:
	var ids: Array[int] = []
	for unit_id: int in _units:
		ids.append(unit_id)
	ids.sort()
	var result: Array[RunUnitState] = []
	for unit_id: int in ids:
		result.append(_units[unit_id])
	return result


func _get_art_mutable(art_instance_id: int) -> RunArtState:
	return _arts.get(art_instance_id) as RunArtState


func _get_arts_mutable() -> Array[RunArtState]:
	var ids: Array[int] = []
	for art_id: int in _arts:
		ids.append(art_id)
	ids.sort()
	var result: Array[RunArtState] = []
	for art_id: int in ids:
		result.append(_arts[art_id])
	return result


func _get_relic_mutable(relic_instance_id: int) -> RunRelicState:
	return _relics.get(relic_instance_id) as RunRelicState


func _get_relics_mutable() -> Array[RunRelicState]:
	var ids: Array[int] = []
	for relic_id: int in _relics:
		ids.append(relic_id)
	ids.sort()
	var result: Array[RunRelicState] = []
	for relic_id: int in ids:
		result.append(_relics[relic_id])
	return result


func _get_scroll_mutable(stack_instance_id: int) -> ScrollStackState:
	return _scrolls.get(stack_instance_id) as ScrollStackState


func _get_scrolls_mutable() -> Array[ScrollStackState]:
	var ids: Array[int] = []
	for stack_id: int in _scrolls:
		ids.append(stack_id)
	ids.sort()
	var result: Array[ScrollStackState] = []
	for stack_id: int in ids:
		result.append(_scrolls[stack_id])
	return result


func _change_gold(amount: int) -> bool:
	if _gold + amount < 0:
		return false
	_gold += amount
	return true


func _allocate_unit_id() -> int:
	var result: int = _next_unit_instance_id
	_next_unit_instance_id += 1
	return result


func _allocate_art_id() -> int:
	var result: int = _next_art_instance_id
	_next_art_instance_id += 1
	return result


func _allocate_relic_id() -> int:
	var result: int = _next_relic_instance_id
	_next_relic_instance_id += 1
	return result


func _allocate_scroll_stack_id() -> int:
	var result: int = _next_scroll_stack_instance_id
	_next_scroll_stack_instance_id += 1
	return result


func _allocate_battle_session_id() -> int:
	var result: int = _next_battle_session_id
	_next_battle_session_id += 1
	return result


func _allocate_offer_id() -> int:
	var result: int = _next_offer_id
	_next_offer_id += 1
	return result


func _allocate_progression_session_id() -> int:
	var result: int = _next_progression_session_id
	_next_progression_session_id += 1
	return result


func _advance_reward_generation() -> int:
	var result: int = _reward_generation_count
	_reward_generation_count += 1
	return result


func _advance_map_generation() -> int:
	var result: int = _map_generation_count
	_map_generation_count += 1
	return result


func _add_unit(unit: RunUnitState) -> bool:
	if (
		unit == null
		or unit.instance_id <= 0
		or _units.has(unit.instance_id)
		or _units.size() >= _team_capacity
	):
		return false
	_units[unit.instance_id] = unit
	return true


func _remove_unit(unit_instance_id: int) -> RunUnitState:
	var unit: RunUnitState = _get_unit_mutable(unit_instance_id)
	if unit != null:
		_units.erase(unit_instance_id)
	return unit


func _add_art(art: RunArtState) -> bool:
	if art == null or art.instance_id <= 0 or _arts.has(art.instance_id):
		return false
	_arts[art.instance_id] = art
	return true


func _remove_art(art_instance_id: int) -> RunArtState:
	var art: RunArtState = _get_art_mutable(art_instance_id)
	if art != null:
		_arts.erase(art_instance_id)
	return art


func _add_relic(relic: RunRelicState) -> bool:
	if (
		relic == null
		or relic.instance_id <= 0
		or _relics.has(relic.instance_id)
	):
		return false
	_relics[relic.instance_id] = relic
	return true


func _remove_relic(relic_instance_id: int) -> RunRelicState:
	var relic: RunRelicState = _get_relic_mutable(relic_instance_id)
	if relic != null:
		_relics.erase(relic_instance_id)
	return relic


func _add_scroll_stack(stack: ScrollStackState) -> bool:
	if (
		stack == null
		or stack.instance_id <= 0
		or _scrolls.has(stack.instance_id)
		or _scrolls.size() >= _scroll_slot_capacity
	):
		return false
	_scrolls[stack.instance_id] = stack
	return true


func _remove_scroll_stack(stack_instance_id: int) -> ScrollStackState:
	var stack: ScrollStackState = _get_scroll_mutable(stack_instance_id)
	if stack != null:
		_scrolls.erase(stack_instance_id)
	return stack


func _create_unit_with_defaults(definition: UnitDefinition) -> bool:
	if definition == null or _units.size() >= _team_capacity:
		return false
	var unit: RunUnitState = RunUnitState.create(
			_allocate_unit_id(),
			definition
	)
	if unit == null or not _add_unit(unit):
		return false
	var loadout_service: ArtLoadoutService = ArtLoadoutService.new()
	for slot_index: int in range(definition.default_arts.size()):
		var art: RunArtState = RunArtState.create(
				_allocate_art_id(),
				definition.default_arts[slot_index]
		)
		if (
			art == null
			or not _add_art(art)
			or not loadout_service.install(
					unit,
					art,
					slot_index
			).succeeded()
		):
			return false
	return true


func _create_relic(definition: RelicDefinition) -> bool:
	if definition == null:
		return false
	var relic: RunRelicState = RunRelicState.create(
			_allocate_relic_id(),
			definition
	)
	return _add_relic(relic)

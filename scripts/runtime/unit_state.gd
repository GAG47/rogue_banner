class_name UnitState
extends RefCounted

var instance_id: int = 0
var source_run_unit_id: int = 0
var definition: UnitDefinition
var side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var current_health: int = 0
var current_ap: int = 0
var arts: Array[ArtState] = []


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
		return state

	state.current_health = unit_definition.max_health
	state.current_ap = unit_definition.max_ap
	for art_definition: ArtDefinition in unit_definition.default_arts:
		if art_definition != null:
			state.arts.append(ArtState.create(art_definition))
	return state


static func create_from_run_unit(
		unit_instance_id: int,
		run_unit: RunUnitState,
		battle_side: GameEnums.BattleSide
) -> UnitState:
	var state: UnitState = UnitState.new()
	state.instance_id = unit_instance_id
	state.side = battle_side

	if run_unit == null or run_unit.definition == null:
		return state

	state.source_run_unit_id = run_unit.instance_id
	state.definition = run_unit.definition
	state.current_health = clampi(
			run_unit.current_health,
			0,
			run_unit.definition.max_health
	)
	state.current_ap = run_unit.definition.max_ap
	for art_definition: ArtDefinition in run_unit.installed_arts:
		if art_definition != null:
			state.arts.append(ArtState.create(art_definition))
	return state


func refresh_for_turn() -> void:
	if definition == null or is_defeated():
		return
	current_ap = definition.max_ap
	for art_state: ArtState in arts:
		if art_state != null:
			art_state.advance_cooldown()


func is_defeated() -> bool:
	return current_health <= 0

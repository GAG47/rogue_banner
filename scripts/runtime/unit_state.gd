class_name UnitState
extends RefCounted

var instance_id: int = 0
var definition: UnitDefinition
var side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var current_health: int = 0
var current_ap: int = 0
var grid_position: GridCoordinate
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


func is_defeated() -> bool:
	return current_health <= 0

class_name BattleReadModel
extends RefCounted

var phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var active_side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var round_number: int = 0
var grid_width: int = 0
var grid_height: int = 0
var cells: Dictionary[Vector2i, BattleCellReadModel] = {}
var units: Array[BattleUnitReadModel] = []
var intents: Array[BattleIntentReadModel] = []


func get_cell(coordinate: Vector2i) -> BattleCellReadModel:
	return cells.get(coordinate) as BattleCellReadModel


func get_unit(unit_id: int) -> BattleUnitReadModel:
	for unit: BattleUnitReadModel in units:
		if unit != null and unit.instance_id == unit_id:
			return unit
	return null


func get_unit_at(coordinate: Vector2i) -> BattleUnitReadModel:
	var cell: BattleCellReadModel = get_cell(coordinate)
	if cell == null or not cell.has_unit():
		return null
	return get_unit(cell.occupant_runtime_id)


func get_units_for_side(
		battle_side: GameEnums.BattleSide
) -> Array[BattleUnitReadModel]:
	var result: Array[BattleUnitReadModel] = []
	for unit: BattleUnitReadModel in units:
		if unit != null and unit.side == battle_side:
			result.append(unit)
	return result


func is_in_bounds(coordinate: Vector2i) -> bool:
	return (
		coordinate.x >= 0
		and coordinate.y >= 0
		and coordinate.x < grid_width
		and coordinate.y < grid_height
	)


func is_terminal() -> bool:
	return (
		phase == GameEnums.BattlePhase.VICTORY
		or phase == GameEnums.BattlePhase.FAILURE
	)

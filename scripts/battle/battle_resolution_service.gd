class_name BattleResolutionService
extends RefCounted

var _placement_service: BattlePlacementService


func _init(placement_service: BattlePlacementService = null) -> void:
	_placement_service = placement_service
	if _placement_service == null:
		_placement_service = BattlePlacementService.new()


func resolve(battle: BattleState) -> BattleResolutionResult:
	var result: BattleResolutionResult = BattleResolutionResult.new()
	if battle == null:
		return result

	var living_player_count: int = _living_unit_count(
			battle,
			GameEnums.BattleSide.PLAYER
	)
	var living_enemy_count: int = _living_unit_count(
			battle,
			GameEnums.BattleSide.ENEMY
	)
	result.removed_unit_ids.assign(
			_placement_service.remove_defeated_units(battle)
	)

	if living_player_count == 0:
		battle.phase = GameEnums.BattlePhase.FAILURE
		result.battle_ended = true
	elif living_enemy_count == 0:
		battle.phase = GameEnums.BattlePhase.VICTORY
		result.battle_ended = true

	if result.battle_ended:
		result.event = BattleEndedEvent.create(
				battle.phase,
				battle.round_number
		)
		battle._stamp_event(result.event)
	return result


func _living_unit_count(
		battle: BattleState,
		side: GameEnums.BattleSide
) -> int:
	var count: int = 0
	for unit: UnitState in battle.get_units_for_side(side):
		if unit != null and not unit.is_defeated():
			count += 1
	return count

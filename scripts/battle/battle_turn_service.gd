class_name BattleTurnService
extends RefCounted


func start_battle(battle: BattleState) -> TurnTransitionResult:
	if battle == null or battle.grid == null or not battle.grid.is_valid():
		return TurnTransitionResult.failure(GameEnums.ActionFailureCode.INVALID_BATTLE)
	if battle.phase != GameEnums.BattlePhase.SETUP:
		return TurnTransitionResult.failure(GameEnums.ActionFailureCode.INVALID_PHASE)

	var previous_side: GameEnums.BattleSide = battle.active_side
	battle.phase = GameEnums.BattlePhase.PLAYER_TURN
	battle.active_side = GameEnums.BattleSide.PLAYER
	battle.round_number = 1
	_refresh_side(battle, GameEnums.BattleSide.PLAYER)
	return TurnTransitionResult.success(
			previous_side,
			battle.active_side,
			battle.round_number
	)


func end_turn(
		battle: BattleState,
		requesting_side: GameEnums.BattleSide
) -> TurnTransitionResult:
	if battle == null or battle.grid == null:
		return TurnTransitionResult.failure(GameEnums.ActionFailureCode.INVALID_BATTLE)
	if not _is_active_phase(battle.phase):
		return TurnTransitionResult.failure(GameEnums.ActionFailureCode.BATTLE_NOT_ACTIVE)
	if battle.active_side != requesting_side:
		return TurnTransitionResult.failure(GameEnums.ActionFailureCode.WRONG_TURN)

	var previous_side: GameEnums.BattleSide = battle.active_side
	if battle.active_side == GameEnums.BattleSide.PLAYER:
		battle.active_side = GameEnums.BattleSide.ENEMY
		battle.phase = GameEnums.BattlePhase.ENEMY_TURN
	else:
		battle.active_side = GameEnums.BattleSide.PLAYER
		battle.phase = GameEnums.BattlePhase.PLAYER_TURN
		battle.round_number += 1

	_refresh_side(battle, battle.active_side)
	return TurnTransitionResult.success(
			previous_side,
			battle.active_side,
			battle.round_number
	)


func _refresh_side(battle: BattleState, side: GameEnums.BattleSide) -> void:
	for unit: UnitState in battle.get_units_for_side(side):
		unit.refresh_for_turn()


func _is_active_phase(phase: GameEnums.BattlePhase) -> bool:
	return (
			phase == GameEnums.BattlePhase.PLAYER_TURN
			or phase == GameEnums.BattlePhase.ENEMY_TURN
	)

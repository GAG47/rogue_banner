class_name BattleTurnService
extends RefCounted

var _attribute_calculator: AttributeCalculator
var _buff_service: BuffService


func _init(
		attribute_calculator: AttributeCalculator = null,
		buff_service: BuffService = null
) -> void:
	_attribute_calculator = attribute_calculator
	if _attribute_calculator == null:
		_attribute_calculator = AttributeCalculator.new()
	_buff_service = buff_service
	if _buff_service == null:
		_buff_service = BuffService.new(_attribute_calculator)


func _start_battle(battle: BattleState) -> TurnTransitionResult:
	if battle == null or battle.grid == null or not battle.grid.is_valid():
		return TurnTransitionResult.failure(GameEnums.ActionFailureCode.INVALID_BATTLE)
	if battle.phase != GameEnums.BattlePhase.SETUP:
		return TurnTransitionResult.failure(GameEnums.ActionFailureCode.INVALID_PHASE)

	var previous_side: GameEnums.BattleSide = battle.active_side
	battle.phase = GameEnums.BattlePhase.PLAYER_TURN
	battle.active_side = GameEnums.BattleSide.PLAYER
	battle.round_number = 1
	var result: TurnTransitionResult = TurnTransitionResult.success(
			previous_side,
			battle.active_side,
			battle.round_number
	)
	result.events.assign(_refresh_side(battle, GameEnums.BattleSide.PLAYER))
	result.events.append(
			TurnStartedEvent.create(battle.active_side, battle.round_number)
	)
	return result


func _end_turn(
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
	var previous_round: int = battle.round_number
	if battle.active_side == GameEnums.BattleSide.PLAYER:
		battle.active_side = GameEnums.BattleSide.ENEMY
		battle.phase = GameEnums.BattlePhase.ENEMY_TURN
	else:
		battle.active_side = GameEnums.BattleSide.PLAYER
		battle.phase = GameEnums.BattlePhase.PLAYER_TURN
		battle.round_number += 1

	var result: TurnTransitionResult = TurnTransitionResult.success(
			previous_side,
			battle.active_side,
			battle.round_number
	)
	result.events.append(TurnEndedEvent.create(previous_side, previous_round))
	result.events.append_array(_refresh_side(battle, battle.active_side))
	result.events.append(
			TurnStartedEvent.create(battle.active_side, battle.round_number)
	)
	return result


func _refresh_side(
	battle: BattleState,
	side: GameEnums.BattleSide
) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for unit: UnitState in battle.get_units_for_side(side):
		var expired_buffs: Array[BuffState] = _buff_service.advance_turn(unit)
		for buff: BuffState in expired_buffs:
			events.append(
					BuffRemovedEvent.create(
							buff.source,
							unit.instance_id,
							buff.definition
					)
			)
		unit.refresh_for_turn(
				_attribute_calculator.calculate(
						unit,
						GameEnums.AttributeType.MAX_AP
				)
		)
	return events


func _is_active_phase(phase: GameEnums.BattlePhase) -> bool:
	return (
			phase == GameEnums.BattlePhase.PLAYER_TURN
			or phase == GameEnums.BattlePhase.ENEMY_TURN
	)

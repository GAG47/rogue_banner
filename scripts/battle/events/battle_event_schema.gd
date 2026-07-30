class_name BattleEventSchema
extends RefCounted


static func capabilities_for(kind: GameEnums.BattleEventKind) -> int:
	match kind:
		GameEnums.BattleEventKind.UNIT_MOVED:
			return (
					GameEnums.EventDataCapability.SOURCE_UNIT
					| GameEnums.EventDataCapability.TARGET_UNIT
					| GameEnums.EventDataCapability.POSITION
			)
		GameEnums.BattleEventKind.DAMAGE_APPLIED:
			return _unit_pair_capabilities()
		GameEnums.BattleEventKind.HEALING_APPLIED:
			return _unit_pair_capabilities()
		GameEnums.BattleEventKind.SHIELD_CHANGED:
			return _unit_pair_capabilities()
		GameEnums.BattleEventKind.BUFF_APPLIED:
			return (
					_unit_pair_capabilities()
					| GameEnums.EventDataCapability.BUFF
			)
		GameEnums.BattleEventKind.BUFF_REMOVED:
			return (
					GameEnums.EventDataCapability.TARGET_UNIT
					| GameEnums.EventDataCapability.BUFF
			)
		GameEnums.BattleEventKind.UNIT_DEFEATED:
			return _unit_pair_capabilities()
		GameEnums.BattleEventKind.ART_USED:
			return (
					_unit_pair_capabilities()
					| GameEnums.EventDataCapability.ART
			)
		GameEnums.BattleEventKind.TURN_STARTED:
			return (
					GameEnums.EventDataCapability.SIDE
					| GameEnums.EventDataCapability.ROUND
			)
		GameEnums.BattleEventKind.TURN_ENDED:
			return (
					GameEnums.EventDataCapability.SIDE
					| GameEnums.EventDataCapability.ROUND
			)
		GameEnums.BattleEventKind.BATTLE_ENDED:
			return (
					GameEnums.EventDataCapability.BATTLE_PHASE
					| GameEnums.EventDataCapability.ROUND
			)
	return 0


static func supports(
		kind: GameEnums.BattleEventKind,
		capability: GameEnums.EventDataCapability
) -> bool:
	return (capabilities_for(kind) & int(capability)) == int(capability)


static func is_valid_event(event: BattleEvent) -> bool:
	if event == null:
		return false
	var capabilities: int = capabilities_for(event.kind)
	if (
		(capabilities & GameEnums.EventDataCapability.SOURCE_UNIT) != 0
		and event.source_unit_id <= 0
	):
		return false
	if (
		(capabilities & GameEnums.EventDataCapability.TARGET_UNIT) != 0
		and event.target_unit_id <= 0
	):
		return false

	match event.kind:
		GameEnums.BattleEventKind.UNIT_MOVED:
			return event is UnitMovedEvent
		GameEnums.BattleEventKind.DAMAGE_APPLIED:
			return event is DamageAppliedEvent
		GameEnums.BattleEventKind.HEALING_APPLIED:
			return event is HealingAppliedEvent
		GameEnums.BattleEventKind.SHIELD_CHANGED:
			return event is ShieldChangedEvent
		GameEnums.BattleEventKind.BUFF_APPLIED:
			return (
					event is BuffAppliedEvent
					and (event as BuffAppliedEvent).buff_definition != null
			)
		GameEnums.BattleEventKind.BUFF_REMOVED:
			return (
					event is BuffRemovedEvent
					and (event as BuffRemovedEvent).buff_definition != null
			)
		GameEnums.BattleEventKind.UNIT_DEFEATED:
			return event is UnitDefeatedEvent
		GameEnums.BattleEventKind.ART_USED:
			return (
					event is ArtUsedEvent
					and (event as ArtUsedEvent).art_definition != null
					and (event as ArtUsedEvent).art_slot_index >= 0
			)
		GameEnums.BattleEventKind.TURN_STARTED:
			var started: TurnStartedEvent = event as TurnStartedEvent
			return (
					started != null
					and started.round_number > 0
					and _is_valid_side(started.side)
			)
		GameEnums.BattleEventKind.TURN_ENDED:
			var ended_turn: TurnEndedEvent = event as TurnEndedEvent
			return (
					ended_turn != null
					and ended_turn.round_number > 0
					and _is_valid_side(ended_turn.side)
			)
		GameEnums.BattleEventKind.BATTLE_ENDED:
			var ended: BattleEndedEvent = event as BattleEndedEvent
			return (
					ended != null
					and ended.final_round_number > 0
					and (
						ended.final_phase == GameEnums.BattlePhase.VICTORY
						or ended.final_phase == GameEnums.BattlePhase.FAILURE
					)
			)
	return false


static func _unit_pair_capabilities() -> int:
	return (
			GameEnums.EventDataCapability.SOURCE_UNIT
			| GameEnums.EventDataCapability.TARGET_UNIT
	)


static func _is_valid_side(side: GameEnums.BattleSide) -> bool:
	return (
			side == GameEnums.BattleSide.PLAYER
			or side == GameEnums.BattleSide.ENEMY
	)

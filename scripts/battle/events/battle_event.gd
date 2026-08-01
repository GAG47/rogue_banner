class_name BattleEvent
extends RefCounted

var sequence_id: int = 0
var kind: GameEnums.BattleEventKind = GameEnums.BattleEventKind.UNIT_MOVED
var source: BattleSource
var target_unit_id: int = 0

var source_unit_id: int:
	get:
		return source.acting_unit_id if source != null else 0


func stamp(event_sequence_id: int) -> void:
	if sequence_id == 0:
		sequence_id = event_sequence_id

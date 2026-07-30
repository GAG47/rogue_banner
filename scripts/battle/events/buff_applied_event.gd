class_name BuffAppliedEvent
extends BattleEvent

var buff_definition: BuffDefinition
var stacks: int = 0


static func create(
		source_id: int,
		target_id: int,
		definition: BuffDefinition,
		current_stacks: int
) -> BuffAppliedEvent:
	var event: BuffAppliedEvent = BuffAppliedEvent.new()
	event.kind = GameEnums.BattleEventKind.BUFF_APPLIED
	event.source_unit_id = source_id
	event.target_unit_id = target_id
	event.buff_definition = definition
	event.stacks = current_stacks
	return event

class_name IntentPlan
extends RefCounted

var actor_unit_id: int = 0
var definition: IntentDefinition
var art_slot_index: int = -1
var generation_round: int = 0
var phase_id: StringName = &""
var locked_targets: TargetSelection
var direction: GameEnums.CardinalDirection = GameEnums.CardinalDirection.RIGHT
var has_move_destination: bool = false
var move_destination: Vector2i = Vector2i.ZERO


func duplicate_plan() -> IntentPlan:
	var plan: IntentPlan = IntentPlan.new()
	plan.actor_unit_id = actor_unit_id
	plan.definition = definition
	plan.art_slot_index = art_slot_index
	plan.generation_round = generation_round
	plan.phase_id = phase_id
	plan.locked_targets = (
			locked_targets.duplicate_selection()
			if locked_targets != null
			else null
	)
	plan.direction = direction
	plan.has_move_destination = has_move_destination
	plan.move_destination = move_destination
	return plan

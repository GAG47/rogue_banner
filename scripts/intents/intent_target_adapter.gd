class_name IntentTargetAdapter
extends RefCounted


func create_selection(
		battle: BattleState,
		plan: IntentPlan
) -> TargetSelection:
	if (
		battle == null
		or battle.grid == null
		or plan == null
		or plan.definition == null
	):
		return null
	if plan.definition.kind != GameEnums.IntentKind.PATTERN:
		return (
			plan.locked_targets.duplicate_selection()
			if plan.locked_targets != null
			else null
		)
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			plan.actor_unit_id
	)
	if actor_position == null:
		return null
	var selection: TargetSelection = TargetSelection.new()
	selection.cells.append(
			actor_position.value + GridDirection.to_vector(plan.direction)
	)
	selection.has_orientation = true
	selection.orientation = plan.direction
	return selection

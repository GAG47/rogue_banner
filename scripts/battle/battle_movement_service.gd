class_name BattleMovementService
extends RefCounted


func commit_path(
		battle: BattleState,
		unit_id: int,
		path: Array[Vector2i],
		ap_cost: int = 0
) -> BattleMovementResult:
	if battle == null or battle.grid == null or path.size() < 2:
		return BattleMovementResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)
	var unit: UnitState = battle.get_unit(unit_id)
	if unit == null or unit.is_defeated() or unit.current_ap < ap_cost:
		return BattleMovementResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)
	var current_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			unit_id
	)
	if current_position == null or current_position.value != path[0]:
		return BattleMovementResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)

	var destination: Vector2i = path[path.size() - 1]
	var grid_result: GridOperationResult = battle.grid.move_occupant(
			GridOccupant.unit(unit_id),
			current_position.value,
			destination
	)
	if not grid_result.succeeded():
		return BattleMovementResult.failure(
				GameEnums.ActionFailureCode.STATE_CHANGED
		)

	unit.current_ap -= ap_cost
	return BattleMovementResult.success(
			ap_cost,
			path,
			UnitMovedEvent.create(
					unit_id,
					current_position.value,
					destination,
					path
			)
	)

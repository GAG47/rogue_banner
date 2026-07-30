class_name IntentPlanBuilder
extends RefCounted

class TargetFacts:
	extends RefCounted

	var selection: TargetSelection
	var coordinate: GridCoordinate


var _pathfinder: GridPathfinder
var _attribute_calculator: AttributeCalculator


func _init(
		pathfinder: GridPathfinder = null,
		attribute_calculator: AttributeCalculator = null
) -> void:
	_pathfinder = pathfinder
	if _pathfinder == null:
		_pathfinder = GridPathfinder.new()
	_attribute_calculator = attribute_calculator
	if _attribute_calculator == null:
		_attribute_calculator = AttributeCalculator.new()


func build(
		battle: BattleState,
		enemy_state: EnemyState,
		intent: IntentDefinition,
		phase_id: StringName
) -> IntentPlan:
	if (
		battle == null
		or battle.grid == null
		or enemy_state == null
		or intent == null
		or intent.art == null
	):
		return null
	var actor: UnitState = battle.get_unit(enemy_state.unit_instance_id)
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			enemy_state.unit_instance_id
	)
	if actor == null or actor.is_defeated() or actor_position == null:
		return null
	var art_slot_index: int = _find_art_slot(actor, intent.art)
	if art_slot_index < 0:
		return null
	var art_state: ArtState = actor.arts[art_slot_index]
	if (
		art_state == null
		or art_state.definition == null
		or art_state.definition.category == GameEnums.ArtCategory.PASSIVE
		or art_state.current_cooldown > 1
		or _attribute_calculator.calculate(
				actor,
				GameEnums.AttributeType.MAX_AP
		) < art_state.definition.ap_cost
	):
		return null

	var target_facts: TargetFacts = _select_target(
			battle,
			actor,
			intent.target_rule
	)
	if target_facts == null:
		return null

	var plan: IntentPlan = IntentPlan.new()
	plan.actor_unit_id = actor.instance_id
	plan.definition = intent
	plan.art_slot_index = art_slot_index
	plan.generation_round = battle.round_number
	plan.phase_id = phase_id
	if intent.kind != GameEnums.IntentKind.PATTERN:
		plan.locked_targets = target_facts.selection.duplicate_selection()

	if (
		intent.movement_rule == GameEnums.IntentMovementRule.TOWARD_TARGET
		and target_facts.coordinate != null
	):
		var destination: GridCoordinate = _choose_move_destination(
				battle,
				actor,
				actor_position.value,
				target_facts.coordinate.value,
				intent.art.ap_cost
		)
		if (
			destination != null
			and destination.value != actor_position.value
		):
			plan.has_move_destination = true
			plan.move_destination = destination.value

	if intent.direction_rule == GameEnums.IntentDirectionRule.FIXED:
		plan.direction = intent.fixed_direction
	elif target_facts.coordinate != null:
		var direction_origin: Vector2i = (
			plan.move_destination
			if (
				plan.has_move_destination
				and intent.sequence == GameEnums.IntentSequence.MOVE_THEN_ART
			)
			else actor_position.value
		)
		plan.direction = GridDirection.from_delta(
				target_facts.coordinate.value - direction_origin
		)
	return plan


func _select_target(
		battle: BattleState,
		actor: UnitState,
		rule: GameEnums.IntentTargetRule
) -> TargetFacts:
	match rule:
		GameEnums.IntentTargetRule.SELF:
			return _unit_target_facts(battle, actor.instance_id)
		GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT:
			var nearest_opponent: UnitState = _nearest_opponent(battle, actor)
			return (
				_unit_target_facts(battle, nearest_opponent.instance_id)
				if nearest_opponent != null
				else null
			)
		GameEnums.IntentTargetRule.NEAREST_OPPONENT_CELL:
			var cell_opponent: UnitState = _nearest_opponent(battle, actor)
			if cell_opponent == null:
				return null
			var opponent_position: GridCoordinate = battle.grid.find_occupant(
					GameEnums.GridOccupantKind.UNIT,
					cell_opponent.instance_id
			)
			if opponent_position == null:
				return null
			var cell_facts: TargetFacts = TargetFacts.new()
			cell_facts.coordinate = opponent_position
			cell_facts.selection = TargetSelection.new()
			cell_facts.selection.cells.append(opponent_position.value)
			return cell_facts
		GameEnums.IntentTargetRule.LOWEST_HEALTH_ALLY_UNIT:
			var ally: UnitState = _lowest_health_ally(battle, actor)
			return (
				_unit_target_facts(battle, ally.instance_id)
				if ally != null
				else null
			)
		GameEnums.IntentTargetRule.NEAREST_SCENE_OBJECT:
			return _nearest_scene_object(battle, actor)
	return null


func _unit_target_facts(
		battle: BattleState,
		unit_id: int
) -> TargetFacts:
	var position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			unit_id
	)
	if position == null:
		return null
	var facts: TargetFacts = TargetFacts.new()
	facts.coordinate = position
	facts.selection = TargetSelection.new()
	facts.selection.unit_instance_ids.append(unit_id)
	return facts


func _nearest_opponent(
		battle: BattleState,
		actor: UnitState
) -> UnitState:
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			actor.instance_id
	)
	if actor_position == null:
		return null
	var best: UnitState
	var best_distance: int = 2147483647
	for unit: UnitState in battle.get_units():
		if (
			unit == null
			or unit.is_defeated()
			or unit.side == actor.side
		):
			continue
		var position: GridCoordinate = battle.grid.find_occupant(
				GameEnums.GridOccupantKind.UNIT,
				unit.instance_id
		)
		if position == null:
			continue
		var distance: int = battle.grid.get_distance(
				actor_position.value,
				position.value
		)
		if (
			distance < best_distance
			or (
				distance == best_distance
				and (best == null or unit.instance_id < best.instance_id)
			)
		):
			best = unit
			best_distance = distance
	return best


func _lowest_health_ally(
		battle: BattleState,
		actor: UnitState
) -> UnitState:
	var best: UnitState
	var best_ratio: float = INF
	for unit: UnitState in battle.get_units():
		if (
			unit == null
			or unit.is_defeated()
			or unit.instance_id == actor.instance_id
			or unit.side != actor.side
		):
			continue
		var maximum_health: int = _attribute_calculator.calculate(
				unit,
				GameEnums.AttributeType.MAX_HEALTH
		)
		if maximum_health <= 0:
			continue
		var ratio: float = float(unit.current_health) / float(maximum_health)
		if (
			ratio < best_ratio
			or (
				is_equal_approx(ratio, best_ratio)
				and (best == null or unit.instance_id < best.instance_id)
			)
		):
			best = unit
			best_ratio = ratio
	return best


func _nearest_scene_object(
		battle: BattleState,
		actor: UnitState
) -> TargetFacts:
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			actor.instance_id
	)
	if actor_position == null:
		return null
	var best_id: int = 0
	var best_coordinate: Vector2i
	var best_distance: int = 2147483647
	for y: int in range(battle.grid.height):
		for x: int in range(battle.grid.width):
			var coordinate: Vector2i = Vector2i(x, y)
			var occupant: GridOccupant = battle.grid.get_occupant(coordinate)
			if (
				occupant == null
				or occupant.kind != GameEnums.GridOccupantKind.SCENE_OBJECT
			):
				continue
			var distance: int = battle.grid.get_distance(
					actor_position.value,
					coordinate
			)
			if (
				distance < best_distance
				or (
					distance == best_distance
					and (best_id == 0 or occupant.runtime_id < best_id)
				)
			):
				best_id = occupant.runtime_id
				best_coordinate = coordinate
				best_distance = distance
	if best_id <= 0:
		return null
	var facts: TargetFacts = TargetFacts.new()
	facts.coordinate = GridCoordinate.new(best_coordinate)
	facts.selection = TargetSelection.new()
	facts.selection.terrain_object_instance_ids.append(best_id)
	return facts


func _choose_move_destination(
		battle: BattleState,
		actor: UnitState,
		origin: Vector2i,
		target: Vector2i,
		art_ap_cost: int
) -> GridCoordinate:
	var maximum_ap: int = _attribute_calculator.calculate(
			actor,
			GameEnums.AttributeType.MAX_AP
	)
	var movement_budget: int = maxi(0, maximum_ap - art_ap_cost)
	var current_distance: int = battle.grid.get_distance(origin, target)
	var best_coordinate: Vector2i = origin
	var best_distance: int = current_distance
	var best_cost: int = 0

	for y: int in range(battle.grid.height):
		for x: int in range(battle.grid.width):
			var coordinate: Vector2i = Vector2i(x, y)
			if coordinate == origin or not battle.grid.is_cell_passable(coordinate):
				continue
			var path: GridPathResult = _pathfinder.find_path(
					battle.grid,
					origin,
					coordinate
			)
			if not path.succeeded() or path.total_cost > movement_budget:
				continue
			var distance: int = battle.grid.get_distance(coordinate, target)
			if (
				distance < best_distance
				or (
					distance == best_distance
					and (
						path.total_cost < best_cost
						or (
							path.total_cost == best_cost
							and _coordinate_before(coordinate, best_coordinate)
						)
					)
				)
			):
				best_coordinate = coordinate
				best_distance = distance
				best_cost = path.total_cost
	return GridCoordinate.new(best_coordinate)


func _find_art_slot(actor: UnitState, art: ArtDefinition) -> int:
	for slot_index: int in range(actor.arts.size()):
		var art_state: ArtState = actor.arts[slot_index]
		if (
			art_state != null
			and art_state.definition != null
			and (
				art_state.definition == art
				or (
					art_state.definition.content_id != &""
					and art_state.definition.content_id == art.content_id
				)
			)
		):
			return slot_index
	return -1


func _coordinate_before(left: Vector2i, right: Vector2i) -> bool:
	return left.y < right.y or (left.y == right.y and left.x < right.x)

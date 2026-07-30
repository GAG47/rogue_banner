class_name IntentPreviewService
extends RefCounted

var _pathfinder: GridPathfinder
var _target_resolver: BattleTargetResolver
var _target_adapter: IntentTargetAdapter
var _attribute_calculator: AttributeCalculator


func _init(
		pathfinder: GridPathfinder = null,
		target_resolver: BattleTargetResolver = null
) -> void:
	_pathfinder = pathfinder
	if _pathfinder == null:
		_pathfinder = GridPathfinder.new()
	_target_resolver = target_resolver
	if _target_resolver == null:
		_target_resolver = BattleTargetResolver.new()
	_target_adapter = IntentTargetAdapter.new()
	_attribute_calculator = AttributeCalculator.new()


func build_all(battle: BattleState) -> Array[IntentPreview]:
	var previews: Array[IntentPreview] = []
	if battle == null:
		return previews
	for enemy_state: EnemyState in battle.get_enemy_states():
		if enemy_state.current_intent == null:
			continue
		var preview: IntentPreview = build(battle, enemy_state.current_intent)
		if preview != null:
			previews.append(preview)
	return previews


func build(
		battle: BattleState,
		plan: IntentPlan
) -> IntentPreview:
	if (
		battle == null
		or battle.grid == null
		or plan == null
		or plan.definition == null
		or plan.definition.art == null
	):
		return null
	var actor: UnitState = battle.get_unit(plan.actor_unit_id)
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			plan.actor_unit_id
	)
	if actor == null or actor_position == null:
		return null

	var preview: IntentPreview = IntentPreview.new()
	preview.actor_unit_id = plan.actor_unit_id
	preview.intent_name = plan.definition.display_name
	preview.icon = plan.definition.icon
	preview.kind = plan.definition.kind
	preview.art_definition = plan.definition.art
	preview.art_slot_index = plan.art_slot_index
	preview.generation_round = plan.generation_round
	preview.phase_id = plan.phase_id
	preview.direction = plan.direction
	preview.locked_targets = (
		plan.locked_targets.duplicate_selection()
		if plan.locked_targets != null
		else null
	)
	preview.has_move_destination = plan.has_move_destination
	preview.move_destination = plan.move_destination

	var projected_battle: BattleState = battle.duplicate_state()
	if projected_battle == null:
		return preview
	if plan.has_move_destination:
		var path: GridPathResult = _pathfinder.find_path(
				battle.grid,
				actor_position.value,
				plan.move_destination
		)
		var movement_budget: int = maxi(
				0,
				_attribute_calculator.calculate(
						actor,
						GameEnums.AttributeType.MAX_AP
				) - plan.definition.art.ap_cost
		)
		if path.succeeded() and path.total_cost <= movement_budget:
			preview.movement_path.assign(path.path)
			if (
				plan.definition.sequence
				== GameEnums.IntentSequence.MOVE_THEN_ART
			):
				projected_battle.grid.move_occupant(
						GridOccupant.unit(plan.actor_unit_id),
						actor_position.value,
						plan.move_destination
				)

	var selection: TargetSelection = _target_adapter.create_selection(
			projected_battle,
			plan
	)
	if selection == null:
		return preview
	var resolution: TargetResolutionResult = _target_resolver.resolve(
			plan.definition.art.targeting,
			BattleTargetingContext.create(
					projected_battle,
					plan.actor_unit_id,
					selection
			),
			selection
	)
	if not resolution.is_valid:
		return preview
	preview.currently_valid = true
	preview.aim_cells.assign(resolution.resolved_targets.aim_cells)
	preview.affected_cells.assign(resolution.resolved_targets.affected_cells)
	return preview

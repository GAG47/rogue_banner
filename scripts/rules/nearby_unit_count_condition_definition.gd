class_name NearbyUnitCountConditionDefinition
extends ConditionDefinition

@export var relation: GameEnums.TargetRelation = GameEnums.TargetRelation.ENEMY
@export_range(0, 32, 1) var maximum_distance: int = 1
@export_range(1, 32, 1) var minimum_count: int = 1

var _relation_evaluator: UnitRelationEvaluator = UnitRelationEvaluator.new()


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if maximum_distance < 0 or minimum_count <= 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Nearby Unit conditions require a non-negative range and positive count."
		)
	if relation == GameEnums.TargetRelation.NEUTRAL:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Nearby Unit conditions cannot use a neutral Unit relation."
		)


func validate_context(
		context_kind: GameEnums.ConditionContextKind,
		_event_kind: GameEnums.BattleEventKind,
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if (
		context_kind != GameEnums.ConditionContextKind.ACTION_USE
		and context_kind != GameEnums.ConditionContextKind.EVENT_TRIGGER
		and context_kind != GameEnums.ConditionContextKind.ENEMY_DECISION
	):
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Nearby Unit conditions require a Battle Unit context."
		)


func evaluate(context: ConditionContext) -> ConditionResult:
	var battle: BattleState
	var actor_unit_id: int = 0
	if context is BattleConditionContext:
		var battle_context: BattleConditionContext = (
			context as BattleConditionContext
		)
		battle = battle_context.battle
		actor_unit_id = battle_context.actor_unit_id
	elif context is EnemyDecisionContext:
		var decision_context: EnemyDecisionContext = (
			context as EnemyDecisionContext
		)
		battle = decision_context.battle
		actor_unit_id = decision_context.actor_unit_id
	if battle == null or battle.grid == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	var actor: UnitState = battle.get_unit(actor_unit_id)
	var actor_position: GridCoordinate = battle.grid.find_occupant(
			GameEnums.GridOccupantKind.UNIT,
			actor_unit_id
	)
	if actor == null or actor_position == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)

	var count: int = 0
	for unit: UnitState in battle.get_units():
		if (
			unit == null
			or unit.is_defeated()
			or not _relation_evaluator.matches(actor, unit, relation)
		):
			continue
		var position: GridCoordinate = battle.grid.find_occupant(
				GameEnums.GridOccupantKind.UNIT,
				unit.instance_id
		)
		if (
			position != null
			and battle.grid.get_distance(
					actor_position.value,
					position.value
			) <= maximum_distance
		):
			count += 1
	return (
			ConditionResult.success()
			if count >= minimum_count
			else ConditionResult.failure()
	)


func requires_actor_unit() -> bool:
	return true

class_name UnitHealthRatioConditionDefinition
extends ConditionDefinition

@export_range(0.0, 1.0, 0.01) var threshold: float = 0.5
@export var comparison: GameEnums.NumericComparison = (
		GameEnums.NumericComparison.LESS_OR_EQUAL
)

var _attribute_calculator: AttributeCalculator = AttributeCalculator.new()


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if not is_finite(threshold) or threshold < 0.0 or threshold > 1.0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_VALUE,
				field_path,
				"Health ratio thresholds must be between zero and one."
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
				"Health ratio conditions require a Battle Unit context."
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
	if battle == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	var unit: UnitState = battle.get_unit(actor_unit_id)
	if unit == null:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	var maximum_health: int = _attribute_calculator.calculate(
			unit,
			GameEnums.AttributeType.MAX_HEALTH
	)
	if maximum_health <= 0:
		return ConditionResult.failure(GameEnums.ConditionStatus.INVALID_CONTEXT)
	var ratio: float = float(unit.current_health) / float(maximum_health)
	return (
			ConditionResult.success()
			if _compare(ratio)
			else ConditionResult.failure()
	)


func _compare(value: float) -> bool:
	match comparison:
		GameEnums.NumericComparison.LESS_THAN:
			return value < threshold
		GameEnums.NumericComparison.LESS_OR_EQUAL:
			return value <= threshold
		GameEnums.NumericComparison.GREATER_THAN:
			return value > threshold
		GameEnums.NumericComparison.GREATER_OR_EQUAL:
			return value >= threshold
	return false


func requires_actor_unit() -> bool:
	return true

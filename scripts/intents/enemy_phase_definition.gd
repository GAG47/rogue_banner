class_name EnemyPhaseDefinition
extends Resource

@export var phase_id: StringName = &""
@export var priority: int = 0
@export var entry_conditions: Array[ConditionDefinition] = []
@export var decision_policy: EnemyDecisionPolicyDefinition

class_name IntentCandidateDefinition
extends Resource

@export var intent: IntentDefinition
@export var priority: int = 0
@export_range(0.01, 1000.0, 0.01) var weight: float = 1.0
@export var conditions: Array[ConditionDefinition] = []

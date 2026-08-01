class_name MapEventOutcomeDefinition
extends Resource

@export var outcome_id: StringName = &""
@export_range(0.001, 1000.0, 0.001) var weight: float = 1.0
@export var operations: Array[MapEventOperationDefinition] = []

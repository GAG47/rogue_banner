class_name EffectExecutionPlan
extends RefCounted

var definition: EffectDefinition
var target_unit_ids: Array[int] = []
var amount: int = 0
var destination: GridCoordinate
var movement_path: Array[Vector2i] = []

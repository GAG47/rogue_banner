class_name MapNodePoolEntry
extends Resource

@export var node_definition: MapNodeDefinition
@export_range(0.001, 1000.0, 0.001) var weight: float = 1.0
@export_range(1, 999, 1) var minimum_layer: int = 1
@export_range(0, 999, 1) var maximum_layer: int = 0
@export_range(0, 99, 1) var minimum_copies: int = 0
@export_range(0, 99, 1) var maximum_copies: int = 0

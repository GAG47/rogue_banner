class_name MapDefinition
extends DefinitionResource

@export_range(1, 99, 1) var layer_count: int = 3
@export_range(1, 8, 1) var minimum_nodes_per_layer: int = 2
@export_range(1, 8, 1) var maximum_nodes_per_layer: int = 3
@export_range(0.0, 1.0, 0.01) var extra_connection_chance: float = 0.25
@export var start_node: MapNodeDefinition
@export var boss_node: EncounterMapNodeDefinition
@export var node_pool: Array[MapNodePoolEntry] = []

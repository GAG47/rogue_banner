class_name BattlefieldDefinition
extends DefinitionResource

@export_range(1, 64, 1) var width: int = 1
@export_range(1, 64, 1) var height: int = 1
@export var default_terrain: TerrainDefinition
@export var terrain_overrides: Array[BattlefieldTerrainPlacement] = []
@export var player_deployment_cells: Array[Vector2i] = []

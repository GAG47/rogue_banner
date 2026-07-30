class_name CellState
extends RefCounted

var _coordinate: Vector2i
var _terrain: TerrainDefinition

var coordinate: Vector2i:
	get:
		return _coordinate

var terrain: TerrainDefinition:
	get:
		return _terrain


func _init(
		cell_coordinate: Vector2i,
		terrain_definition: TerrainDefinition
) -> void:
	_coordinate = cell_coordinate
	_terrain = terrain_definition


func _replace_terrain(terrain_definition: TerrainDefinition) -> void:
	_terrain = terrain_definition

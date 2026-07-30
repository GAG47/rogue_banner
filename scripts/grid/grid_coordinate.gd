class_name GridCoordinate
extends RefCounted

var value: Vector2i


func _init(initial_value: Vector2i = Vector2i.ZERO) -> void:
	value = initial_value


func manhattan_distance_to(other: GridCoordinate) -> int:
	if other == null:
		return -1
	return absi(value.x - other.value.x) + absi(value.y - other.value.y)


func is_cardinally_adjacent_to(other: GridCoordinate) -> bool:
	return manhattan_distance_to(other) == 1

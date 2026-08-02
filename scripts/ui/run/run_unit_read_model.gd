class_name RunUnitReadModel
extends RefCounted

var instance_id: int = 0
var display_name: String = ""
var current_health: int = 0
var maximum_health: int = 0
var slot_count: int = 0
var installed_art_ids: Array[int] = []
var installed_art_names: Array[String] = []


func is_defeated() -> bool:
	return current_health <= 0

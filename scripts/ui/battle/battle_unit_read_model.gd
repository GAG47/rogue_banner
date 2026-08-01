class_name BattleUnitReadModel
extends RefCounted

var instance_id: int = 0
var content_id: StringName = &""
var display_name: String = ""
var side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var has_coordinate: bool = false
var coordinate: Vector2i = Vector2i.ZERO
var current_health: int = 0
var maximum_health: int = 0
var current_ap: int = 0
var maximum_ap: int = 0
var current_shield: int = 0
var arts: Array[BattleArtReadModel] = []
var buffs: Array[BattleBuffReadModel] = []


func get_art(slot_index: int) -> BattleArtReadModel:
	for art: BattleArtReadModel in arts:
		if art != null and art.slot_index == slot_index:
			return art
	return null


func is_defeated() -> bool:
	return current_health <= 0

class_name BattleArtReadModel
extends RefCounted

var slot_index: int = -1
var content_id: StringName = &""
var display_name: String = ""
var category: GameEnums.ArtCategory = GameEnums.ArtCategory.ATTACK
var ap_cost: int = 0
var base_cooldown: int = 0
var current_cooldown: int = 0
var target_kind: GameEnums.TargetKind = GameEnums.TargetKind.UNIT
var target_relation: GameEnums.TargetRelation = GameEnums.TargetRelation.ENEMY
var minimum_range: int = 0
var maximum_range: int = 0
var minimum_targets: int = 1
var maximum_targets: int = 1
var requires_line_of_sight: bool = false


func is_passive() -> bool:
	return category == GameEnums.ArtCategory.PASSIVE


func is_ready() -> bool:
	return not is_passive() and current_cooldown <= 0

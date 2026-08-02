class_name RunArtReadModel
extends RefCounted

var instance_id: int = 0
var display_name: String = ""
var category: GameEnums.ArtCategory = GameEnums.ArtCategory.ATTACK
var rarity: GameEnums.ArtRarity = GameEnums.ArtRarity.COMMON
var owner_unit_id: int = 0
var slot_index: int = -1
var has_upgrade: bool = false

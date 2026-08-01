class_name ShopMapNodeDefinition
extends MapNodeDefinition

@export var reward_pool: RewardPoolDefinition


func _init() -> void:
	kind = GameEnums.MapNodeKind.SHOP

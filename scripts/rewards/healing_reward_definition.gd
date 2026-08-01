class_name HealingRewardDefinition
extends RewardPayloadDefinition

@export_range(1, 999, 1) var amount: int = 1


func _init() -> void:
	kind = GameEnums.RewardKind.HEALING


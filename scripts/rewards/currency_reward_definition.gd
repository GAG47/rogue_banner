class_name CurrencyRewardDefinition
extends RewardPayloadDefinition

@export_range(1, 9999, 1) var amount: int = 1


func _init() -> void:
	kind = GameEnums.RewardKind.CURRENCY


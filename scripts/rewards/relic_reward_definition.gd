class_name RelicRewardDefinition
extends RewardPayloadDefinition

@export var relic_definition: RelicDefinition


func _init() -> void:
	kind = GameEnums.RewardKind.RELIC


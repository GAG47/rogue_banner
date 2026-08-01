class_name ScrollRewardDefinition
extends RewardPayloadDefinition

@export var scroll_definition: ScrollDefinition
@export_range(1, 99, 1) var quantity: int = 1


func _init() -> void:
	kind = GameEnums.RewardKind.SCROLL


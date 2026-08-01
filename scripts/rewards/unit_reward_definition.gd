class_name UnitRewardDefinition
extends RewardPayloadDefinition

@export var unit_definition: UnitDefinition


func _init() -> void:
	kind = GameEnums.RewardKind.UNIT


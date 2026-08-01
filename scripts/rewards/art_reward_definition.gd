class_name ArtRewardDefinition
extends RewardPayloadDefinition

@export var art_definition: ArtDefinition


func _init() -> void:
	kind = GameEnums.RewardKind.ART


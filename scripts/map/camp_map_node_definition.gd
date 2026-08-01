class_name CampMapNodeDefinition
extends MapNodeDefinition

@export var camp_definition: CampDefinition


func _init() -> void:
	kind = GameEnums.MapNodeKind.CAMP

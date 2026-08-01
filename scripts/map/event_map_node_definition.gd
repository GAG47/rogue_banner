class_name EventMapNodeDefinition
extends MapNodeDefinition

@export var event_definition: MapEventDefinition


func _init() -> void:
	kind = GameEnums.MapNodeKind.EVENT

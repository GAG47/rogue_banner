class_name BattleSetupUnit
extends RefCounted

var source_run_unit_id: int = 0
var definition: UnitDefinition
var current_health: int = 0
var installed_art_definitions: Array[ArtDefinition] = []
var coordinate: Vector2i


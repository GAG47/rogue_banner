class_name IntentPreview
extends RefCounted

var actor_unit_id: int = 0
var intent_name: String = ""
var icon: Texture2D
var kind: GameEnums.IntentKind = GameEnums.IntentKind.LOCKED
var art_definition: ArtDefinition
var art_slot_index: int = -1
var generation_round: int = 0
var phase_id: StringName = &""
var direction: GameEnums.CardinalDirection = GameEnums.CardinalDirection.RIGHT
var locked_targets: TargetSelection
var has_move_destination: bool = false
var move_destination: Vector2i = Vector2i.ZERO
var movement_path: Array[Vector2i] = []
var aim_cells: Array[Vector2i] = []
var affected_cells: Array[Vector2i] = []
var currently_valid: bool = false

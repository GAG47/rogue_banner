class_name BattleIntentReadModel
extends RefCounted

var actor_unit_id: int = 0
var actor_name: String = ""
var intent_name: String = ""
var art_name: String = ""
var kind: GameEnums.IntentKind = GameEnums.IntentKind.LOCKED
var generation_round: int = 0
var phase_id: StringName = &""
var direction: GameEnums.CardinalDirection = GameEnums.CardinalDirection.RIGHT
var locked_unit_ids: Array[int] = []
var locked_cells: Array[Vector2i] = []
var locked_scene_object_ids: Array[int] = []
var has_move_destination: bool = false
var move_destination: Vector2i = Vector2i.ZERO
var movement_path: Array[Vector2i] = []
var aim_cells: Array[Vector2i] = []
var affected_cells: Array[Vector2i] = []
var currently_valid: bool = false

class_name RunSummaryReadModel
extends RefCounted

var hero_name: String = ""
var phase: GameEnums.RunPhase = GameEnums.RunPhase.READY
var end_reason: GameEnums.RunEndReason = GameEnums.RunEndReason.NONE
var gold: int = 0
var available_unit_count: int = 0
var unit_count: int = 0
var team_capacity: int = 0
var relic_count: int = 0
var scroll_stack_count: int = 0
var scroll_capacity: int = 0
var state_version: int = 0

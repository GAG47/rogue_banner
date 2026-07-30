class_name EnemyState
extends RefCounted

var unit_instance_id: int = 0
var definition: EnemyDefinition
var current_phase_id: StringName = &""
var cycle_index: int = 0
var current_intent: IntentPlan


static func create(
		unit_id: int,
		enemy_definition: EnemyDefinition
) -> EnemyState:
	if unit_id <= 0 or enemy_definition == null:
		return null
	var state: EnemyState = EnemyState.new()
	state.unit_instance_id = unit_id
	state.definition = enemy_definition
	return state


func duplicate_state() -> EnemyState:
	var state: EnemyState = EnemyState.new()
	state._copy_from(self)
	return state


func _copy_from(source: EnemyState) -> void:
	if source == null:
		return
	unit_instance_id = source.unit_instance_id
	definition = source.definition
	current_phase_id = source.current_phase_id
	cycle_index = source.cycle_index
	current_intent = (
		source.current_intent.duplicate_plan()
		if source.current_intent != null
		else null
	)

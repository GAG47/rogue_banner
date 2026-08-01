class_name MapEventSessionState
extends RefCounted

var selected_choice_id: StringName = &""
var planned_outcome_id: StringName = &""
var stage: GameEnums.MapEventStage = GameEnums.MapEventStage.CHOOSING
var offer_id: int = 0
var executed_operation_count: int = 0


func duplicate_state() -> MapEventSessionState:
	var state: MapEventSessionState = MapEventSessionState.new()
	state.selected_choice_id = selected_choice_id
	state.planned_outcome_id = planned_outcome_id
	state.stage = stage
	state.offer_id = offer_id
	state.executed_operation_count = executed_operation_count
	return state

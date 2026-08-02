class_name EventReadModel
extends RefCounted

var title: String = ""
var node_kind: GameEnums.MapNodeKind = GameEnums.MapNodeKind.EVENT
var stage: GameEnums.MapSessionStage = GameEnums.MapSessionStage.EVENT_CHOICE
var selected_choice_id: StringName = &""
var selected_choice_name: String = ""
var planned_outcome_id: StringName = &""
var choices: Array[EventChoiceReadModel] = []

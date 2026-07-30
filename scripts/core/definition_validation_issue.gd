class_name DefinitionValidationIssue
extends RefCounted

var code: GameEnums.DefinitionValidationCode
var field_path: StringName
var message: String


func _init(
		issue_code: GameEnums.DefinitionValidationCode,
		issue_field_path: StringName,
		issue_message: String
) -> void:
	code = issue_code
	field_path = issue_field_path
	message = issue_message

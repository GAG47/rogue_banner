class_name DefinitionValidationResult
extends RefCounted

var issues: Array[DefinitionValidationIssue] = []


func add_issue(
		code: GameEnums.DefinitionValidationCode,
		field_path: StringName,
		message: String
) -> void:
	issues.append(DefinitionValidationIssue.new(code, field_path, message))


func is_valid() -> bool:
	return issues.is_empty()


func has_code(code: GameEnums.DefinitionValidationCode) -> bool:
	for issue: DefinitionValidationIssue in issues:
		if issue.code == code:
			return true
	return false

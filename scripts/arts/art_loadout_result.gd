class_name ArtLoadoutResult
extends RefCounted

var code: GameEnums.ArtLoadoutCode = GameEnums.ArtLoadoutCode.SUCCEEDED
var slot_index: int = -1
var art: ArtDefinition


static func success(
		target_slot_index: int,
		art_definition: ArtDefinition
) -> ArtLoadoutResult:
	var result: ArtLoadoutResult = ArtLoadoutResult.new()
	result.slot_index = target_slot_index
	result.art = art_definition
	return result


static func failure(code_value: GameEnums.ArtLoadoutCode) -> ArtLoadoutResult:
	var result: ArtLoadoutResult = ArtLoadoutResult.new()
	result.code = code_value
	return result


func succeeded() -> bool:
	return code == GameEnums.ArtLoadoutCode.SUCCEEDED

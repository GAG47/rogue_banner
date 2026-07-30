class_name ConditionResult
extends RefCounted

var status: GameEnums.ConditionStatus = GameEnums.ConditionStatus.PASSED


static func success() -> ConditionResult:
	return ConditionResult.new()


static func failure(
		failure_status: GameEnums.ConditionStatus = GameEnums.ConditionStatus.FAILED
) -> ConditionResult:
	var result: ConditionResult = ConditionResult.new()
	result.status = failure_status
	return result


func passed() -> bool:
	return status == GameEnums.ConditionStatus.PASSED

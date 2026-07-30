class_name EffectResult
extends RefCounted

var status: GameEnums.EffectStatus = GameEnums.EffectStatus.SUCCEEDED


static func success() -> EffectResult:
	return EffectResult.new()


static func failure(
		failure_status: GameEnums.EffectStatus = GameEnums.EffectStatus.FAILED
) -> EffectResult:
	var result: EffectResult = EffectResult.new()
	result.status = failure_status
	return result


func succeeded() -> bool:
	return status == GameEnums.EffectStatus.SUCCEEDED

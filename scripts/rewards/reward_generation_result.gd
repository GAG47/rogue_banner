class_name RewardGenerationResult
extends RefCounted

var failure_code: GameEnums.RunCommandCode = (
		GameEnums.RunCommandCode.REWARD_GENERATION_FAILED
)
var offer: RewardOffer


func succeeded() -> bool:
	return failure_code == GameEnums.RunCommandCode.SUCCEEDED


func has_offer() -> bool:
	return offer != null


static func success(value: RewardOffer) -> RewardGenerationResult:
	if value == null:
		return null
	var result: RewardGenerationResult = RewardGenerationResult.new()
	result.failure_code = GameEnums.RunCommandCode.SUCCEEDED
	result.offer = value
	return result


static func empty_success() -> RewardGenerationResult:
	var result: RewardGenerationResult = RewardGenerationResult.new()
	result.failure_code = GameEnums.RunCommandCode.SUCCEEDED
	return result


static func failure(
		code: GameEnums.RunCommandCode
) -> RewardGenerationResult:
	var result: RewardGenerationResult = RewardGenerationResult.new()
	result.failure_code = code
	return result

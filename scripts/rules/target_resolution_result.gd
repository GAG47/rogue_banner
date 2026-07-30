class_name TargetResolutionResult
extends RefCounted

var is_valid: bool = false
var failure_code: GameEnums.ActionFailureCode = (
	GameEnums.ActionFailureCode.INVALID_TARGET_SELECTION
)
var selection: TargetSelection
var resolved_targets: ResolvedTargetSet


static func accepted(
	targets: ResolvedTargetSet
) -> TargetResolutionResult:
	var result: TargetResolutionResult = TargetResolutionResult.new()
	result.is_valid = true
	result.failure_code = GameEnums.ActionFailureCode.NONE
	result.resolved_targets = targets
	if targets != null:
		result.selection = targets.selection
	return result


static func rejected(
		code: GameEnums.ActionFailureCode
) -> TargetResolutionResult:
	var result: TargetResolutionResult = TargetResolutionResult.new()
	result.failure_code = code
	return result

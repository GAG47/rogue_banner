@abstract
class_name TargetResolver
extends RefCounted


@abstract
func resolve(
		definition: TargetingDefinition,
		context: TargetingContext,
		selection: TargetSelection
) -> TargetResolutionResult

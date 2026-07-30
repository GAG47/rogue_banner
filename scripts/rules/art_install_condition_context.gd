class_name ArtInstallConditionContext
extends ConditionContext

var unit: RunUnitState
var art: ArtDefinition
var slot_index: int = -1


static func create(
		unit_state: RunUnitState,
		art_definition: ArtDefinition,
		target_slot_index: int
) -> ArtInstallConditionContext:
	var context: ArtInstallConditionContext = ArtInstallConditionContext.new()
	context.unit = unit_state
	context.art = art_definition
	context.slot_index = target_slot_index
	return context

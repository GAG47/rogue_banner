class_name BuffDefinition
extends DefinitionResource

@export var duration_turns: int = 1
@export var stacking_rule: GameEnums.BuffStackingRule = (
		GameEnums.BuffStackingRule.REFRESH_DURATION
)
@export var maximum_stacks: int = 1
@export var modifiers: Array[ModifierDefinition] = []
@export var passive_triggers: Array[TriggerDefinition] = []

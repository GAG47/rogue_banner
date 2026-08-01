class_name RewardPoolDefinition
extends DefinitionResource

@export var offer_rule: GameEnums.RewardOfferRule = (
		GameEnums.RewardOfferRule.PICK_ONE
)
@export_range(1, 20, 1) var option_count: int = 3
@export var entries: Array[RewardEntryDefinition] = []


class_name ArtDefinition
extends DefinitionResource

@export var rarity: GameEnums.ArtRarity = GameEnums.ArtRarity.COMMON
@export var category: GameEnums.ArtCategory = GameEnums.ArtCategory.ATTACK
@export var ap_cost: int = 1
@export var cooldown: int = 0
@export var targeting: TargetingDefinition
@export var required_tags: Array[TagDefinition] = []
@export var installation_conditions: Array[ConditionDefinition] = []
@export var use_conditions: Array[ConditionDefinition] = []
@export var effects: Array[EffectDefinition] = []
@export var passive_triggers: Array[TriggerDefinition] = []
@export var upgraded_variant: ArtDefinition

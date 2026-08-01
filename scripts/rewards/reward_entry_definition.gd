class_name RewardEntryDefinition
extends Resource

@export var payload: RewardPayloadDefinition
@export var rarity: GameEnums.RewardRarity = GameEnums.RewardRarity.COMMON
@export_range(0.001, 1000.0, 0.001) var weight: float = 1.0
@export_range(1, 999, 1) var minimum_floor: int = 1
@export_range(0, 999, 1) var maximum_floor: int = 0
@export var allow_duplicate: bool = false
@export_range(0, 99999, 1) var price: int = 0
@export var conditions: Array[ConditionDefinition] = []


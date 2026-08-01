class_name RewardOption
extends RefCounted

var option_id: int = 0
var payload: RewardPayloadDefinition
var rarity: GameEnums.RewardRarity = GameEnums.RewardRarity.COMMON
var price: int = 0
var status: GameEnums.RewardOptionStatus = (
		GameEnums.RewardOptionStatus.AVAILABLE
)


func duplicate_state() -> RewardOption:
	var copy: RewardOption = RewardOption.new()
	copy.option_id = option_id
	copy.payload = payload
	copy.rarity = rarity
	copy.price = price
	copy.status = status
	return copy


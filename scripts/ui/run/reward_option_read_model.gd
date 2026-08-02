class_name RewardOptionReadModel
extends RefCounted

var option_id: int = 0
var kind: GameEnums.RewardKind = GameEnums.RewardKind.CURRENCY
var title: String = ""
var detail: String = ""
var rarity: GameEnums.RewardRarity = GameEnums.RewardRarity.COMMON
var price: int = 0
var status: GameEnums.RewardOptionStatus = (
	GameEnums.RewardOptionStatus.AVAILABLE
)
var requires_unit_target: bool = false
var requires_art_target: bool = false
var supports_install_target: bool = false

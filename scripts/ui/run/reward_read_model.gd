class_name RewardReadModel
extends RefCounted

var offer_id: int = 0
var source: GameEnums.RewardSource = GameEnums.RewardSource.BATTLE
var rule: GameEnums.RewardOfferRule = GameEnums.RewardOfferRule.PICK_ONE
var status: GameEnums.RewardOfferStatus = GameEnums.RewardOfferStatus.OPEN
var options: Array[RewardOptionReadModel] = []


func get_option(option_id: int) -> RewardOptionReadModel:
	for option: RewardOptionReadModel in options:
		if option.option_id == option_id:
			return option
	return null

class_name RewardOffer
extends RefCounted

var offer_id: int = 0
var source: GameEnums.RewardSource = GameEnums.RewardSource.BATTLE
var rule: GameEnums.RewardOfferRule = GameEnums.RewardOfferRule.PICK_ONE
var status: GameEnums.RewardOfferStatus = GameEnums.RewardOfferStatus.OPEN
var generation_index: int = 0
var progression_session_id: int = 0
var options: Array[RewardOption] = []


func get_option(option_id: int) -> RewardOption:
	for option: RewardOption in options:
		if option != null and option.option_id == option_id:
			return option
	return null


func duplicate_state() -> RewardOffer:
	var copy: RewardOffer = RewardOffer.new()
	copy.offer_id = offer_id
	copy.source = source
	copy.rule = rule
	copy.status = status
	copy.generation_index = generation_index
	copy.progression_session_id = progression_session_id
	for option: RewardOption in options:
		copy.options.append(option.duplicate_state() if option != null else null)
	return copy

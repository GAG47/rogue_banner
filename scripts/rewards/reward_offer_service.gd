class_name RewardOfferService
extends RefCounted

var _grant_service: RewardGrantService


func _init(grant_service: RewardGrantService = null) -> void:
	_grant_service = grant_service
	if _grant_service == null:
		_grant_service = RewardGrantService.new()


func claim_option(
	run: RunState,
	offer_id: int,
	option_id: int,
	destination: RewardGrantDestination = null
) -> RunCommandResult:
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	var working: RunState = transaction.working_state
	if _is_progression_offer(working, offer_id):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_PHASE
		)
	var result: RunCommandResult = claim_option_in_transaction(
			working,
			offer_id,
			option_id,
			destination
	)
	if not result.succeeded():
		return result
	if working._get_active_offer_mutable() == null:
		working._set_phase(GameEnums.RunPhase.READY)
	if not transaction.commit():
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	return result


func claim_option_in_transaction(
	run: RunState,
	offer_id: int,
	option_id: int,
	destination: RewardGrantDestination = null
) -> RunCommandResult:
	if run == null:
		return RunCommandResult.failure(GameEnums.RunCommandCode.INVALID_RUN)
	var offer: RewardOffer = run._get_active_offer_mutable()
	var validation: RunCommandResult = _validate_open_offer(
			run,
			offer,
			offer_id
	)
	if not validation.succeeded():
		return validation
	if offer.rule == GameEnums.RewardOfferRule.TAKE_ALL:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.OPTION_UNAVAILABLE
		)
	var option: RewardOption = offer.get_option(option_id)
	if option == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.OPTION_NOT_FOUND
		)
	if option.status != GameEnums.RewardOptionStatus.AVAILABLE:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.OPTION_UNAVAILABLE
		)
	if option.price > 0:
		var payment: RunCommandResult = RunCommandService.new(
		).execute_in_transaction(
				run,
				ChangeGoldCommand.create(-option.price),
				true
		)
		if not payment.succeeded():
			return payment
	var grant: RunCommandResult = _grant_service.grant_in_transaction(
			run,
			option.payload,
			destination
	)
	if not grant.succeeded():
		return grant
	if offer.rule == GameEnums.RewardOfferRule.PICK_ONE:
		option.status = GameEnums.RewardOptionStatus.CLAIMED
		for other: RewardOption in offer.options:
			if other != option:
				other.status = GameEnums.RewardOptionStatus.CLOSED
		offer.status = GameEnums.RewardOfferStatus.COMPLETED
		run._set_active_offer(null)
	else:
		option.status = GameEnums.RewardOptionStatus.SOLD
	return grant


func take_all(run: RunState, offer_id: int) -> RunCommandResult:
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	var working: RunState = transaction.working_state
	if _is_progression_offer(working, offer_id):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_PHASE
		)
	var result: RunCommandResult = take_all_in_transaction(working, offer_id)
	if not result.succeeded():
		return result
	working._set_phase(GameEnums.RunPhase.READY)
	if not transaction.commit():
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	return result


func take_all_in_transaction(
	run: RunState,
	offer_id: int
) -> RunCommandResult:
	if run == null:
		return RunCommandResult.failure(GameEnums.RunCommandCode.INVALID_RUN)
	var offer: RewardOffer = run._get_active_offer_mutable()
	var validation: RunCommandResult = _validate_open_offer(
			run,
			offer,
			offer_id
	)
	if not validation.succeeded():
		return validation
	if offer.rule != GameEnums.RewardOfferRule.TAKE_ALL:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.OPTION_UNAVAILABLE
		)
	for option: RewardOption in offer.options:
		if (
			option == null
			or option.status != GameEnums.RewardOptionStatus.AVAILABLE
			or option.price > 0
		):
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.OPTION_UNAVAILABLE
			)
		var grant: RunCommandResult = _grant_service.grant_in_transaction(
				run,
				option.payload
		)
		if not grant.succeeded():
			return grant
		option.status = GameEnums.RewardOptionStatus.CLAIMED
	offer.status = GameEnums.RewardOfferStatus.COMPLETED
	run._set_active_offer(null)
	return RunCommandResult.success()


func close_offer(run: RunState, offer_id: int) -> RunCommandResult:
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	var working: RunState = transaction.working_state
	if _is_progression_offer(working, offer_id):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_PHASE
		)
	var result: RunCommandResult = close_offer_in_transaction(
			working,
			offer_id
	)
	if not result.succeeded():
		return result
	working._set_phase(GameEnums.RunPhase.READY)
	if not transaction.commit():
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	return result


func close_offer_in_transaction(
	run: RunState,
	offer_id: int
) -> RunCommandResult:
	if run == null:
		return RunCommandResult.failure(GameEnums.RunCommandCode.INVALID_RUN)
	var offer: RewardOffer = run._get_active_offer_mutable()
	var validation: RunCommandResult = _validate_open_offer(
			run,
			offer,
			offer_id
	)
	if not validation.succeeded():
		return validation
	if offer.rule != GameEnums.RewardOfferRule.PURCHASE_ANY:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.OPTION_UNAVAILABLE
		)
	offer.status = GameEnums.RewardOfferStatus.CLOSED
	for option: RewardOption in offer.options:
		if option.status == GameEnums.RewardOptionStatus.AVAILABLE:
			option.status = GameEnums.RewardOptionStatus.CLOSED
	run._set_active_offer(null)
	return RunCommandResult.success()


func _validate_open_offer(
		run: RunState,
		offer: RewardOffer,
		offer_id: int
) -> RunCommandResult:
	if run == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	if run.get_phase() not in [
		GameEnums.RunPhase.CHOOSING_REWARD,
		GameEnums.RunPhase.SHOPPING,
	]:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_PHASE
		)
	if offer == null or offer.offer_id != offer_id:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.OFFER_NOT_FOUND
		)
	if offer.status != GameEnums.RewardOfferStatus.OPEN:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.OFFER_CLOSED
		)
	return RunCommandResult.success()


func _is_progression_offer(run: RunState, offer_id: int) -> bool:
	if run == null or offer_id <= 0:
		return false
	var offer: RewardOffer = run.get_active_offer()
	return (
		offer != null
		and offer.offer_id == offer_id
		and offer.progression_session_id > 0
	)

class_name RewardGrantService
extends RefCounted

var _command_service: RunCommandService


func _init(command_service: RunCommandService = null) -> void:
	_command_service = command_service
	if _command_service == null:
		_command_service = RunCommandService.new()


func can_grant(
		run: RunState,
		payload: RewardPayloadDefinition
) -> bool:
	if run == null or payload == null:
		return false
	if payload is CurrencyRewardDefinition:
		return (payload as CurrencyRewardDefinition).amount > 0
	if payload is ArtRewardDefinition:
		return (payload as ArtRewardDefinition).art_definition != null
	if payload is RelicRewardDefinition:
		var relic_definition: RelicDefinition = (
			payload as RelicRewardDefinition
		).relic_definition
		return (
				relic_definition != null
				and run.count_relic_definition(relic_definition)
				< relic_definition.maximum_copies
		)
	if payload is ScrollRewardDefinition:
		return _can_add_scroll(run, payload as ScrollRewardDefinition)
	if payload is UnitRewardDefinition:
		return (
				(payload as UnitRewardDefinition).unit_definition != null
				and run.get_units().size() < run.get_team_capacity()
		)
	if payload is HealingRewardDefinition:
		for unit: RunUnitState in run.get_units():
			if (
				unit != null
				and unit.definition != null
				and unit.current_health < unit.definition.max_health
			):
				return true
		return false
	if payload is ArtUpgradeRewardDefinition:
		for art: RunArtState in run.get_arts():
			if art.definition != null and art.definition.upgraded_variant != null:
				return true
	return false


func grant_in_transaction(
		run: RunState,
		payload: RewardPayloadDefinition,
		destination: RewardGrantDestination = null
) -> RunCommandResult:
	if run == null or payload == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_TARGET
		)
	var target: RewardGrantDestination = destination
	if target == null:
		target = RewardGrantDestination.none()

	if payload is CurrencyRewardDefinition:
		return _execute(
				run,
				ChangeGoldCommand.create(
						(payload as CurrencyRewardDefinition).amount
				)
		)
	if payload is ArtRewardDefinition:
		var grant_result: RunCommandResult = _execute(
				run,
				GrantArtCommand.create(
						(payload as ArtRewardDefinition).art_definition
				)
		)
		if not grant_result.succeeded():
			return grant_result
		if (
			target.install_unit_instance_id > 0
			or target.install_slot_index >= 0
		):
			if (
				target.install_unit_instance_id <= 0
				or target.install_slot_index < 0
			):
				return RunCommandResult.failure(
						GameEnums.RunCommandCode.INVALID_TARGET
				)
			var install_result: RunCommandResult = _execute(
					run,
					InstallArtCommand.create(
							target.install_unit_instance_id,
							grant_result.art_instance_id,
							target.install_slot_index
					)
			)
			if not install_result.succeeded():
				return install_result
		return grant_result
	if payload is RelicRewardDefinition:
		return _execute(
				run,
				GrantRelicCommand.create(
						(payload as RelicRewardDefinition).relic_definition
				)
		)
	if payload is ScrollRewardDefinition:
		var scroll: ScrollRewardDefinition = payload as ScrollRewardDefinition
		return _execute(
				run,
				GrantScrollCommand.create(
						scroll.scroll_definition,
						scroll.quantity
				)
		)
	if payload is UnitRewardDefinition:
		return _execute(
				run,
				RecruitUnitCommand.create(
						(payload as UnitRewardDefinition).unit_definition
				)
		)
	if payload is HealingRewardDefinition:
		if target.unit_instance_id <= 0:
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
		return _execute(
				run,
				HealRunUnitCommand.create(
						target.unit_instance_id,
						(payload as HealingRewardDefinition).amount
				)
		)
	if payload is ArtUpgradeRewardDefinition:
		if target.art_instance_id <= 0:
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
		return _execute(
				run,
				UpgradeArtCommand.create(target.art_instance_id)
		)
	return RunCommandResult.failure(
			GameEnums.RunCommandCode.INVALID_TARGET
	)


func _execute(
		run: RunState,
		command: RunCommand
) -> RunCommandResult:
	return _command_service.execute_in_transaction(run, command, true)


func _can_add_scroll(
		run: RunState,
		payload: ScrollRewardDefinition
) -> bool:
	if (
		payload.scroll_definition == null
		or payload.quantity <= 0
		or payload.scroll_definition.max_stack_size <= 0
	):
		return false
	var available: int = 0
	for stack: ScrollStackState in run.get_scrolls():
		if stack.definition == payload.scroll_definition:
			available += payload.scroll_definition.max_stack_size - stack.quantity
	available += (
		run.get_scroll_slot_capacity() - run.get_scrolls().size()
	) * payload.scroll_definition.max_stack_size
	return available >= payload.quantity

class_name RunCommandService
extends RefCounted

var _loadout_service: ArtLoadoutService
var _validator: DefinitionValidator


func _init(
		loadout_service: ArtLoadoutService = null,
		validator: DefinitionValidator = null
) -> void:
	_loadout_service = loadout_service
	if _loadout_service == null:
		_loadout_service = ArtLoadoutService.new()
	_validator = validator
	if _validator == null:
		_validator = DefinitionValidator.new()


func execute(
		run: RunState,
		command: RunCommand
) -> RunCommandResult:
	if run == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	var transaction: RunTransaction = RunTransaction.begin(run)
	if transaction == null or transaction.working_state == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	var result: RunCommandResult = execute_in_transaction(
			transaction.working_state,
			command
	)
	if not result.succeeded():
		return result
	if not transaction.commit():
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	return result


func execute_in_transaction(
		run: RunState,
		command: RunCommand,
		allow_offer_phase: bool = false
) -> RunCommandResult:
	if run == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	if (
		run.get_phase() != GameEnums.RunPhase.READY
		and not (
			allow_offer_phase
			and run.get_phase() in [
				GameEnums.RunPhase.CHOOSING_REWARD,
				GameEnums.RunPhase.SHOPPING,
			]
		)
	):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_PHASE
		)
	if command == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_COMMAND
		)
	if command is ChangeGoldCommand:
		return _change_gold(run, command as ChangeGoldCommand)
	if command is RecruitUnitCommand:
		return _recruit_unit(run, command as RecruitUnitCommand)
	if command is RemoveRunUnitCommand:
		return _remove_unit(run, command as RemoveRunUnitCommand)
	if command is GrantArtCommand:
		return _grant_art(run, command as GrantArtCommand)
	if command is InstallArtCommand:
		return _install_art(run, command as InstallArtCommand)
	if command is UninstallArtCommand:
		return _uninstall_art(run, command as UninstallArtCommand)
	if command is ForgetArtCommand:
		return _forget_art(run, command as ForgetArtCommand)
	if command is UpgradeArtCommand:
		return _upgrade_art(run, command as UpgradeArtCommand)
	if command is GrantRelicCommand:
		return _grant_relic(run, command as GrantRelicCommand)
	if command is RemoveRelicCommand:
		return _remove_relic(run, command as RemoveRelicCommand)
	if command is GrantScrollCommand:
		return _grant_scroll(run, command as GrantScrollCommand)
	if command is ConsumeScrollCommand:
		return _consume_scroll(run, command as ConsumeScrollCommand)
	if command is HealRunUnitCommand:
		return _heal_unit(run, command as HealRunUnitCommand)
	return RunCommandResult.failure(
			GameEnums.RunCommandCode.INVALID_COMMAND
	)


func _change_gold(
		run: RunState,
		command: ChangeGoldCommand
) -> RunCommandResult:
	if command.amount == 0:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_AMOUNT
		)
	if not run._change_gold(command.amount):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INSUFFICIENT_GOLD
		)
	var result: RunCommandResult = RunCommandResult.success()
	result.changed_quantity = command.amount
	return result


func _recruit_unit(
		run: RunState,
		command: RecruitUnitCommand
) -> RunCommandResult:
	if (
		command.definition == null
		or not _validator.validate(command.definition).is_valid()
	):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_TARGET
		)
	if run._get_units_mutable().size() >= run.get_team_capacity():
		return RunCommandResult.failure(GameEnums.RunCommandCode.TEAM_FULL)
	var previous_ids: Array[int] = []
	for unit: RunUnitState in run._get_units_mutable():
		previous_ids.append(unit.instance_id)
	if not run._create_unit_with_defaults(command.definition):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	var result: RunCommandResult = RunCommandResult.success()
	for unit: RunUnitState in run._get_units_mutable():
		if not previous_ids.has(unit.instance_id):
			result.unit_instance_id = unit.instance_id
			break
	return result


func _remove_unit(
		run: RunState,
		command: RemoveRunUnitCommand
) -> RunCommandResult:
	var unit: RunUnitState = run._get_unit_mutable(command.unit_instance_id)
	if unit == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.UNIT_NOT_FOUND
		)
	if not unit.is_defeated() and run.count_available_units() <= 1:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.LAST_AVAILABLE_UNIT
		)
	for slot_index: int in range(
		unit.installed_art_instance_ids.size()
	):
		unit.installed_art_instance_ids[slot_index] = 0
	run._remove_unit(unit.instance_id)
	var result: RunCommandResult = RunCommandResult.success()
	result.unit_instance_id = unit.instance_id
	return result


func _grant_art(
		run: RunState,
		command: GrantArtCommand
) -> RunCommandResult:
	if (
		command.definition == null
		or not _validator.validate(command.definition).is_valid()
	):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.ART_RULE_REJECTED
		)
	var art: RunArtState = RunArtState.create(
			run._allocate_art_id(),
			command.definition
	)
	if art == null or not run._add_art(art):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	var result: RunCommandResult = RunCommandResult.success()
	result.art_instance_id = art.instance_id
	return result


func _install_art(
		run: RunState,
		command: InstallArtCommand
) -> RunCommandResult:
	var unit: RunUnitState = run._get_unit_mutable(command.unit_instance_id)
	var art: RunArtState = run._get_art_mutable(command.art_instance_id)
	if unit == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.UNIT_NOT_FOUND
		)
	if art == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.ART_NOT_FOUND
		)
	if run.is_art_installed(art.instance_id):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.ART_ALREADY_INSTALLED
		)
	var installation: ArtLoadoutResult = _loadout_service.install(
			unit,
			art,
			command.slot_index
	)
	if not installation.succeeded():
		return RunCommandResult.failure(
				_map_loadout_code(installation.code)
		)
	var result: RunCommandResult = RunCommandResult.success()
	result.unit_instance_id = unit.instance_id
	result.art_instance_id = art.instance_id
	return result


func _uninstall_art(
		run: RunState,
		command: UninstallArtCommand
) -> RunCommandResult:
	var unit: RunUnitState = run._get_unit_mutable(command.unit_instance_id)
	if unit == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.UNIT_NOT_FOUND
		)
	var removal: ArtLoadoutResult = _loadout_service.remove(
			unit,
			command.slot_index
	)
	if not removal.succeeded():
		return RunCommandResult.failure(
				_map_loadout_code(removal.code)
		)
	var result: RunCommandResult = RunCommandResult.success()
	result.unit_instance_id = unit.instance_id
	result.art_instance_id = removal.art_instance_id
	return result


func _forget_art(
		run: RunState,
		command: ForgetArtCommand
) -> RunCommandResult:
	var art: RunArtState = run._get_art_mutable(command.art_instance_id)
	if art == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.ART_NOT_FOUND
		)
	if run.is_art_installed(art.instance_id):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.ART_ALREADY_INSTALLED
		)
	run._remove_art(art.instance_id)
	var result: RunCommandResult = RunCommandResult.success()
	result.art_instance_id = art.instance_id
	return result


func _upgrade_art(
		run: RunState,
		command: UpgradeArtCommand
) -> RunCommandResult:
	var art: RunArtState = run._get_art_mutable(command.art_instance_id)
	if art == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.ART_NOT_FOUND
		)
	if art.definition == null or art.definition.upgraded_variant == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.ART_RULE_REJECTED
		)
	var owner: RunUnitState = run._find_art_owner_mutable(art.instance_id)
	if owner != null:
		var slot_index: int = owner.installed_art_instance_ids.find(
				art.instance_id
		)
		var upgrade: ArtLoadoutResult = _loadout_service.upgrade(
				owner,
				art,
				slot_index
		)
		if not upgrade.succeeded():
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.ART_RULE_REJECTED
			)
	else:
		if not _validator.validate(
			art.definition.upgraded_variant
		).is_valid():
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.ART_RULE_REJECTED
			)
		art.definition = art.definition.upgraded_variant
	var result: RunCommandResult = RunCommandResult.success()
	result.art_instance_id = art.instance_id
	return result


func _grant_relic(
		run: RunState,
		command: GrantRelicCommand
) -> RunCommandResult:
	if (
		command.definition == null
		or not _validator.validate(command.definition).is_valid()
	):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_TARGET
		)
	if (
		run.count_relic_definition(command.definition)
		>= command.definition.maximum_copies
	):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.RELIC_LIMIT_REACHED
		)
	var relic: RunRelicState = RunRelicState.create(
			run._allocate_relic_id(),
			command.definition
	)
	if relic == null or not run._add_relic(relic):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	var result: RunCommandResult = RunCommandResult.success()
	result.relic_instance_id = relic.instance_id
	return result


func _remove_relic(
		run: RunState,
		command: RemoveRelicCommand
) -> RunCommandResult:
	var relic: RunRelicState = run._remove_relic(
			command.relic_instance_id
	)
	if relic == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.RELIC_NOT_FOUND
		)
	var result: RunCommandResult = RunCommandResult.success()
	result.relic_instance_id = relic.instance_id
	return result


func _grant_scroll(
		run: RunState,
		command: GrantScrollCommand
) -> RunCommandResult:
	if (
		command.definition == null
		or command.quantity <= 0
		or not _validator.validate(command.definition).is_valid()
	):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_AMOUNT
		)
	var available_capacity: int = 0
	for stack: ScrollStackState in run._get_scrolls_mutable():
		if stack.definition == command.definition:
			available_capacity += (
					command.definition.max_stack_size - stack.quantity
			)
	available_capacity += (
			run.get_scroll_slot_capacity()
			- run._get_scrolls_mutable().size()
	) * command.definition.max_stack_size
	if available_capacity < command.quantity:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.SCROLL_CAPACITY_EXCEEDED
		)
	var remaining: int = command.quantity
	for stack: ScrollStackState in run._get_scrolls_mutable():
		if stack.definition != command.definition:
			continue
		var added: int = mini(
				remaining,
				command.definition.max_stack_size - stack.quantity
		)
		stack.quantity += added
		remaining -= added
		if remaining == 0:
			break
	while remaining > 0:
		var stack_quantity: int = mini(
				remaining,
				command.definition.max_stack_size
		)
		var new_stack: ScrollStackState = ScrollStackState.create(
				run._allocate_scroll_stack_id(),
				command.definition,
				stack_quantity
		)
		if new_stack == null or not run._add_scroll_stack(new_stack):
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.INTERNAL_FAILURE
			)
		remaining -= stack_quantity
	var result: RunCommandResult = RunCommandResult.success()
	result.changed_quantity = command.quantity
	return result


func _heal_unit(
		run: RunState,
		command: HealRunUnitCommand
) -> RunCommandResult:
	var unit: RunUnitState = run._get_unit_mutable(command.unit_instance_id)
	if unit == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.UNIT_NOT_FOUND
		)
	if command.amount <= 0:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_AMOUNT
		)
	var previous_health: int = unit.current_health
	unit.current_health = mini(
			unit.definition.max_health,
			unit.current_health + command.amount
	)
	var result: RunCommandResult = RunCommandResult.success()
	result.unit_instance_id = unit.instance_id
	result.changed_quantity = unit.current_health - previous_health
	return result


func _consume_scroll(
		run: RunState,
		command: ConsumeScrollCommand
) -> RunCommandResult:
	var stack: ScrollStackState = run._get_scroll_mutable(
			command.stack_instance_id
	)
	if stack == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.SCROLL_NOT_FOUND
		)
	if command.quantity <= 0 or command.quantity > stack.quantity:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_AMOUNT
		)
	stack.quantity -= command.quantity
	if stack.quantity == 0:
		run._remove_scroll_stack(stack.instance_id)
	var result: RunCommandResult = RunCommandResult.success()
	result.changed_quantity = -command.quantity
	return result


func _map_loadout_code(
		code: GameEnums.ArtLoadoutCode
) -> GameEnums.RunCommandCode:
	match code:
		GameEnums.ArtLoadoutCode.INVALID_SLOT:
			return GameEnums.RunCommandCode.INVALID_ART_SLOT
		GameEnums.ArtLoadoutCode.SLOT_OCCUPIED:
			return GameEnums.RunCommandCode.ART_ALREADY_INSTALLED
		GameEnums.ArtLoadoutCode.SLOT_EMPTY:
			return GameEnums.RunCommandCode.ART_NOT_INSTALLED
		GameEnums.ArtLoadoutCode.INVALID_UNIT:
			return GameEnums.RunCommandCode.UNIT_NOT_FOUND
		GameEnums.ArtLoadoutCode.INVALID_ART:
			return GameEnums.RunCommandCode.ART_NOT_FOUND
		_:
			return GameEnums.RunCommandCode.ART_RULE_REJECTED

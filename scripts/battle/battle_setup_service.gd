class_name BattleSetupService
extends RefCounted

var _validator: DefinitionValidator


func _init(validator: DefinitionValidator = null) -> void:
	_validator = validator
	if _validator == null:
		_validator = DefinitionValidator.new()


func build(
	run: RunState,
	request: RunBattleStartRequest,
	session_id: int,
	required_phase: GameEnums.RunPhase = GameEnums.RunPhase.READY
) -> BattleSetupResult:
	if run == null:
		return BattleSetupResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	if run.get_phase() != required_phase:
		return BattleSetupResult.failure(
				GameEnums.RunCommandCode.INVALID_PHASE
		)
	if (
		request == null
		or request.grid == null
		or not request.grid.is_valid()
		or request.player_deployments.is_empty()
		or request.enemy_deployments.is_empty()
		or request.floor_number <= 0
		or session_id <= 0
	):
		return BattleSetupResult.failure(
				GameEnums.RunCommandCode.INVALID_TARGET
		)

	var setup: BattleSetup = BattleSetup.new()
	setup.battle_session_id = session_id
	setup.source_run_version = run.get_state_version()
	setup.battle_seed = _battle_seed(run.get_run_seed(), session_id)
	setup.grid = request.grid.duplicate_state()
	if setup.grid == null:
		return BattleSetupResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)

	var used_run_ids: Array[int] = []
	var used_coordinates: Array[Vector2i] = []
	for deployment: RunUnitDeployment in request.player_deployments:
		if (
			deployment == null
			or deployment.run_unit_id <= 0
			or used_run_ids.has(deployment.run_unit_id)
			or used_coordinates.has(deployment.coordinate)
		):
			return BattleSetupResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
		var unit: RunUnitState = run.get_unit(deployment.run_unit_id)
		if unit == null:
			return BattleSetupResult.failure(
					GameEnums.RunCommandCode.UNIT_NOT_FOUND
			)
		if unit.is_defeated():
			return BattleSetupResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
		var definitions: Array[ArtDefinition] = (
			run.get_installed_art_definitions(unit)
		)
		if not ArtLoadoutService.new().validate_definition_loadout(
			unit,
			definitions
		).succeeded():
			return BattleSetupResult.failure(
					GameEnums.RunCommandCode.ART_RULE_REJECTED
			)
		var snapshot: BattleSetupUnit = BattleSetupUnit.new()
		snapshot.source_run_unit_id = unit.instance_id
		snapshot.definition = unit.definition
		snapshot.current_health = unit.current_health
		snapshot.installed_art_definitions.assign(definitions)
		snapshot.coordinate = deployment.coordinate
		setup.player_units.append(snapshot)
		used_run_ids.append(unit.instance_id)
		used_coordinates.append(deployment.coordinate)

	for deployment: EnemyDeployment in request.enemy_deployments:
		if (
			deployment == null
			or deployment.definition == null
			or used_coordinates.has(deployment.coordinate)
			or not _validator.validate(deployment.definition).is_valid()
		):
			return BattleSetupResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
		setup.enemy_deployments.append(
				EnemyDeployment.create(
						deployment.definition,
						deployment.coordinate
				)
		)
		used_coordinates.append(deployment.coordinate)

	for relic: RunRelicState in run.get_relics():
		if (
			relic == null
			or relic.definition == null
			or not _validator.validate(relic.definition).is_valid()
		):
			return BattleSetupResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
		setup.relics.append(
				BattleRelicState.create(
						relic.instance_id,
						relic.instance_id,
						relic.definition,
						GameEnums.BattleSide.PLAYER
				)
		)
	for stack: ScrollStackState in run.get_scrolls():
		if (
			stack == null
			or stack.definition == null
			or stack.quantity <= 0
		):
			return BattleSetupResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
		setup.scrolls.append(
				BattleScrollStackState.create(
						stack.instance_id,
						stack.instance_id,
						stack.definition,
						stack.quantity
				)
		)
	return BattleSetupResult.success(setup)


func _battle_seed(run_seed: int, session_id: int) -> int:
	return run_seed * 1103515245 + session_id * 12345

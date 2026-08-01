class_name EncounterBuildService
extends RefCounted


func build(
	run: RunState,
	definition: EncounterDefinition,
	start_request: EncounterStartRequest,
	floor_number: int
) -> EncounterBuildResult:
	if (
		run == null
		or definition == null
		or start_request == null
		or floor_number <= 0
		or not DefinitionValidator.new().validate(definition).is_valid()
	):
		return EncounterBuildResult.failure(
				GameEnums.MapFlowCode.INVALID_DEFINITION
		)
	var battlefield: BattlefieldDefinition = definition.battlefield
	var grid: GridState = GridState.create(
			battlefield.width,
			battlefield.height,
			battlefield.default_terrain
	)
	for placement: BattlefieldTerrainPlacement in battlefield.terrain_overrides:
		if placement == null or not grid.set_terrain(
				placement.coordinate,
				placement.terrain
		).succeeded():
			return EncounterBuildResult.failure(
					GameEnums.MapFlowCode.INVALID_DEFINITION
			)

	if start_request.player_deployments.is_empty():
		return EncounterBuildResult.failure(
				GameEnums.MapFlowCode.INVALID_DEPLOYMENT
		)
	var used_units: Array[int] = []
	var used_cells: Array[Vector2i] = []
	for deployment: RunUnitDeployment in start_request.player_deployments:
		if (
			deployment == null
			or deployment.run_unit_id <= 0
			or used_units.has(deployment.run_unit_id)
			or used_cells.has(deployment.coordinate)
			or not battlefield.player_deployment_cells.has(
					deployment.coordinate
			)
		):
			return EncounterBuildResult.failure(
					GameEnums.MapFlowCode.INVALID_DEPLOYMENT
			)
		used_units.append(deployment.run_unit_id)
		used_cells.append(deployment.coordinate)

	var request: RunBattleStartRequest = RunBattleStartRequest.new()
	request.grid = grid
	request.player_deployments.assign(start_request.player_deployments)
	request.floor_number = floor_number
	request.battle_rank = definition.battle_rank
	request.reward_pool = definition.reward_pool
	for spawn: EnemySpawnDefinition in definition.enemy_spawns:
		if spawn == null or used_cells.has(spawn.coordinate):
			return EncounterBuildResult.failure(
					GameEnums.MapFlowCode.INVALID_DEPLOYMENT
			)
		request.enemy_deployments.append(
				EnemyDeployment.create(
						spawn.enemy_definition,
						spawn.coordinate
				)
		)
		used_cells.append(spawn.coordinate)
	return EncounterBuildResult.success(request)

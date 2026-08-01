class_name BattleSetupFactory
extends RefCounted

var _placement_service: BattlePlacementService
var _flow_service: BattleFlowService


func _init(
		placement_service: BattlePlacementService = null,
		flow_service: BattleFlowService = null
) -> void:
	_placement_service = placement_service
	if _placement_service == null:
		_placement_service = BattlePlacementService.new()
	_flow_service = flow_service
	if _flow_service == null:
		_flow_service = BattleFlowService.new()


func create_started_battle(setup: BattleSetup) -> BattleStartResult:
	if (
		setup == null
		or setup.grid == null
		or not setup.grid.is_valid()
		or setup.battle_session_id <= 0
	):
		return BattleStartResult.failure(
				GameEnums.RunCommandCode.INVALID_TARGET
		)
	var battle: BattleState = BattleState.create(
			setup.grid.duplicate_state(),
			setup.battle_seed
	)
	if battle == null or battle.grid == null:
		return BattleStartResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	battle.battle_session_id = setup.battle_session_id
	for relic: BattleRelicState in setup.relics:
		if relic == null or not battle._register_relic(
			relic.duplicate_state()
		):
			return BattleStartResult.failure(
					GameEnums.RunCommandCode.INTERNAL_FAILURE
			)
	for stack: BattleScrollStackState in setup.scrolls:
		if stack == null or not battle._register_scroll(
			stack.duplicate_state()
		):
			return BattleStartResult.failure(
					GameEnums.RunCommandCode.INTERNAL_FAILURE
			)
	for unit: BattleSetupUnit in setup.player_units:
		var placement: BattlePlacementResult = (
			_placement_service.place_run_snapshot(
					battle,
					unit,
					unit.coordinate
			)
		)
		if not placement.succeeded():
			return BattleStartResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
	for enemy: EnemyDeployment in setup.enemy_deployments:
		var placement: BattlePlacementResult = (
			_placement_service.place_enemy_definition(
					battle,
					enemy.definition,
					enemy.coordinate
			)
		)
		if not placement.succeeded():
			return BattleStartResult.failure(
					GameEnums.RunCommandCode.INVALID_TARGET
			)
	var flow: BattleFlowResult = _flow_service.start_battle(battle)
	if not flow.succeeded:
		return BattleStartResult.failure(
				GameEnums.RunCommandCode.INTERNAL_FAILURE
		)
	return BattleStartResult.success(battle, flow)


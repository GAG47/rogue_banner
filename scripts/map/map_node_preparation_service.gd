class_name MapNodePreparationService
extends RefCounted

var _run_flow_service: RunFlowService
var _reward_generation_service: RewardGenerationService


func _init(
	run_flow_service: RunFlowService = null,
	reward_generation_service: RewardGenerationService = null
) -> void:
	_reward_generation_service = reward_generation_service
	if _reward_generation_service == null:
		_reward_generation_service = RewardGenerationService.new()
	_run_flow_service = run_flow_service
	if _run_flow_service == null:
		_run_flow_service = RunFlowService.new(
				null,
				null,
				null,
				null,
				_reward_generation_service
		)


func prepare_in_transaction(
	run: RunState,
	node: MapNodeState,
	session: MapNodeSessionState
) -> MapNodePreparationResult:
	if run == null or node == null or session == null:
		return MapNodePreparationResult.failure(
				GameEnums.MapFlowCode.INVALID_RUN
		)
	match node.definition.kind:
		GameEnums.MapNodeKind.BATTLE, \
		GameEnums.MapNodeKind.ELITE, \
		GameEnums.MapNodeKind.BOSS:
			if not node.definition is EncounterMapNodeDefinition:
				return _invalid_definition()
			session.stage = GameEnums.MapSessionStage.PREPARING_BATTLE
			run._set_phase(GameEnums.RunPhase.PREPARING_BATTLE)
			return MapNodePreparationResult.success()
		GameEnums.MapNodeKind.SHOP:
			return _prepare_shop(run, node, session)
		GameEnums.MapNodeKind.CHEST:
			return _prepare_chest(run, node, session)
		GameEnums.MapNodeKind.EVENT, GameEnums.MapNodeKind.CAMP:
			if _event_definition(node) == null:
				return _invalid_definition()
			session.event_session = MapEventSessionState.new()
			session.stage = GameEnums.MapSessionStage.EVENT_CHOICE
			run._set_phase(GameEnums.RunPhase.RESOLVING_MAP_NODE)
			return MapNodePreparationResult.success()
		_:
			return MapNodePreparationResult.failure(
					GameEnums.MapFlowCode.INVALID_NODE_KIND
			)


func _prepare_shop(
	run: RunState,
	node: MapNodeState,
	session: MapNodeSessionState
) -> MapNodePreparationResult:
	if not node.definition is ShopMapNodeDefinition:
		return _invalid_definition()
	var generated: RunFlowResult = _run_flow_service.open_shop_in_transaction(
			run,
			(node.definition as ShopMapNodeDefinition).reward_pool,
			maxi(1, node.layer_index),
			session.session_id,
			GameEnums.RewardGenerationMode.PROGRESSION_SAFE
	)
	if not generated.succeeded():
		return MapNodePreparationResult.failure(
				_map_run_failure(generated.code)
		)
	if generated.offer == null:
		return MapNodePreparationResult.success(null, true)
	run._set_active_offer(generated.offer)
	run._set_phase(GameEnums.RunPhase.SHOPPING)
	session.offer_id = generated.offer.offer_id
	session.stage = GameEnums.MapSessionStage.SHOPPING
	return MapNodePreparationResult.success(generated.offer)


func _prepare_chest(
	run: RunState,
	node: MapNodeState,
	session: MapNodeSessionState
) -> MapNodePreparationResult:
	if not node.definition is ChestMapNodeDefinition:
		return _invalid_definition()
	var generated: RewardGenerationResult = (
		_reward_generation_service.generate_in_transaction(
				run,
				(node.definition as ChestMapNodeDefinition).reward_pool,
				GameEnums.RewardSource.CHEST,
				maxi(1, node.layer_index),
				GameEnums.EnemyRank.STANDARD,
				GameEnums.RewardGenerationMode.PROGRESSION_SAFE,
				session.session_id
			)
	)
	if not generated.succeeded():
		return MapNodePreparationResult.failure(
				GameEnums.MapFlowCode.REWARD_FAILED
		)
	if generated.offer == null:
		return MapNodePreparationResult.success(null, true)
	run._set_active_offer(generated.offer)
	run._set_phase(GameEnums.RunPhase.CHOOSING_REWARD)
	session.offer_id = generated.offer.offer_id
	session.stage = GameEnums.MapSessionStage.AWAITING_REWARD
	return MapNodePreparationResult.success(generated.offer)


func _event_definition(node: MapNodeState) -> MapEventDefinition:
	if node == null or node.definition == null:
		return null
	if node.definition is EventMapNodeDefinition:
		return (node.definition as EventMapNodeDefinition).event_definition
	if node.definition is CampMapNodeDefinition:
		return (node.definition as CampMapNodeDefinition).camp_definition
	return null


func _invalid_definition() -> MapNodePreparationResult:
	return MapNodePreparationResult.failure(
			GameEnums.MapFlowCode.INVALID_DEFINITION
	)


func _map_run_failure(
	code: GameEnums.RunCommandCode
) -> GameEnums.MapFlowCode:
	match code:
		GameEnums.RunCommandCode.INVALID_RUN:
			return GameEnums.MapFlowCode.INVALID_RUN
		GameEnums.RunCommandCode.INVALID_PHASE:
			return GameEnums.MapFlowCode.INVALID_PHASE
		_:
			return GameEnums.MapFlowCode.REWARD_FAILED

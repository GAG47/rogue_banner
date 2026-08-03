class_name RunReadModelService
extends RefCounted

var _condition_evaluator: ConditionEvaluator = ConditionEvaluator.new()
var _battle_read_model_service: BattleReadModelService = (
	BattleReadModelService.new()
)


func build(
	run: RunState,
	battle: BattleState,
	route: RunSessionRoute.Value
) -> RunSessionSnapshot:
	if run == null:
		return null
	var run_view: RunState = run.duplicate_state()
	if run_view == null:
		return null
	var snapshot: RunSessionSnapshot = RunSessionSnapshot.new()
	snapshot.route = route
	snapshot.summary = _build_summary(run_view)
	snapshot.inventory = _build_inventory(run_view)
	var map_state: MapState = run_view.get_map_state()
	snapshot.map = MapReadModel.create(map_state)
	snapshot.reward = _build_reward(run_view.get_active_offer())
	snapshot.deployment = _build_deployment(run_view, map_state)
	snapshot.event = _build_event(run_view, map_state)
	snapshot.battle = _battle_read_model_service.build(battle)
	return snapshot


func _build_summary(run: RunState) -> RunSummaryReadModel:
	var model: RunSummaryReadModel = RunSummaryReadModel.new()
	var hero: HeroDefinition = run.get_hero_definition()
	model.hero_name = hero.display_name if hero != null else ""
	model.hero_portrait = hero.portrait if hero != null else null
	model.phase = run.get_phase()
	model.end_reason = run.get_end_reason()
	model.gold = run.get_gold()
	model.available_unit_count = run.count_available_units()
	model.unit_count = run.get_units().size()
	model.team_capacity = run.get_team_capacity()
	model.relic_count = run.get_relics().size()
	model.scroll_stack_count = run.get_scrolls().size()
	model.scroll_capacity = run.get_scroll_slot_capacity()
	model.state_version = run.get_state_version()
	return model


func _build_inventory(run: RunState) -> InventoryReadModel:
	var model: InventoryReadModel = InventoryReadModel.new()
	model.team_capacity = run.get_team_capacity()
	model.scroll_capacity = run.get_scroll_slot_capacity()
	var art_owners: Dictionary[int, Vector2i] = {}
	for source_unit: RunUnitState in run.get_units():
		var unit: RunUnitReadModel = RunUnitReadModel.new()
		unit.instance_id = source_unit.instance_id
		unit.display_name = source_unit.definition.display_name
		unit.current_health = source_unit.current_health
		unit.maximum_health = source_unit.definition.max_health
		unit.slot_count = source_unit.definition.slot_count
		for slot_index: int in range(
			source_unit.installed_art_instance_ids.size()
		):
			var art_id: int = source_unit.installed_art_instance_ids[
				slot_index
			]
			unit.installed_art_ids.append(art_id)
			var art_name: String = "空插槽"
			if art_id > 0:
				var source_art: RunArtState = run.get_art(art_id)
				if source_art != null and source_art.definition != null:
					art_name = source_art.definition.display_name
				art_owners[art_id] = Vector2i(
					source_unit.instance_id,
					slot_index
				)
			unit.installed_art_names.append(art_name)
		model.units.append(unit)
	for source_art: RunArtState in run.get_arts():
		if source_art == null or source_art.definition == null:
			continue
		var art: RunArtReadModel = RunArtReadModel.new()
		art.instance_id = source_art.instance_id
		art.display_name = source_art.definition.display_name
		art.category = source_art.definition.category
		art.rarity = source_art.definition.rarity
		art.has_upgrade = source_art.definition.upgraded_variant != null
		if art_owners.has(art.instance_id):
			var owner: Vector2i = art_owners[art.instance_id]
			art.owner_unit_id = owner.x
			art.slot_index = owner.y
		model.arts.append(art)
	for source_relic: RunRelicState in run.get_relics():
		if source_relic == null or source_relic.definition == null:
			continue
		var relic: RunRelicReadModel = RunRelicReadModel.new()
		relic.instance_id = source_relic.instance_id
		relic.display_name = source_relic.definition.display_name
		model.relics.append(relic)
	for source_scroll: ScrollStackState in run.get_scrolls():
		if source_scroll == null or source_scroll.definition == null:
			continue
		var scroll: RunScrollReadModel = RunScrollReadModel.new()
		scroll.stack_instance_id = source_scroll.instance_id
		scroll.display_name = source_scroll.definition.display_name
		scroll.quantity = source_scroll.quantity
		scroll.maximum_stack_size = source_scroll.definition.max_stack_size
		scroll.effect_summary = ScrollUiTextFormatter.effect_summary(
			source_scroll.definition
		)
		if source_scroll.definition.targeting != null:
			scroll.minimum_range = source_scroll.definition.targeting.minimum_range
			scroll.maximum_range = source_scroll.definition.targeting.maximum_range
		model.scrolls.append(scroll)
	return model


func _build_reward(offer: RewardOffer) -> RewardReadModel:
	if offer == null:
		return null
	var model: RewardReadModel = RewardReadModel.new()
	model.offer_id = offer.offer_id
	model.source = offer.source
	model.rule = offer.rule
	model.status = offer.status
	for source: RewardOption in offer.options:
		if source == null or source.payload == null:
			continue
		var option: RewardOptionReadModel = RewardOptionReadModel.new()
		option.option_id = source.option_id
		option.kind = source.payload.kind
		option.title = _reward_title(source.payload)
		option.detail = _reward_detail(source.payload)
		option.rarity = source.rarity
		option.price = source.price
		option.status = source.status
		option.requires_unit_target = (
			source.payload is HealingRewardDefinition
		)
		option.requires_art_target = (
			source.payload is ArtUpgradeRewardDefinition
		)
		option.supports_install_target = (
			source.payload is ArtRewardDefinition
		)
		model.options.append(option)
	return model


func _reward_title(payload: RewardPayloadDefinition) -> String:
	if payload is CurrencyRewardDefinition:
		return "金币"
	if payload is ArtRewardDefinition:
		return (payload as ArtRewardDefinition).art_definition.display_name
	if payload is RelicRewardDefinition:
		return (payload as RelicRewardDefinition).relic_definition.display_name
	if payload is ScrollRewardDefinition:
		return (payload as ScrollRewardDefinition).scroll_definition.display_name
	if payload is UnitRewardDefinition:
		return (payload as UnitRewardDefinition).unit_definition.display_name
	if payload is HealingRewardDefinition:
		return "治疗"
	if payload is ArtUpgradeRewardDefinition:
		return "技艺升级"
	return "未知奖励"


func _reward_detail(payload: RewardPayloadDefinition) -> String:
	if payload is CurrencyRewardDefinition:
		return "获得%d金币" % (payload as CurrencyRewardDefinition).amount
	if payload is ScrollRewardDefinition:
		return "获得%d张卷轴" % (payload as ScrollRewardDefinition).quantity
	if payload is HealingRewardDefinition:
		return "为一名单位恢复%d点生命" % (
			payload as HealingRewardDefinition
		).amount
	if payload is ArtUpgradeRewardDefinition:
		return "选择一项可以升级的技艺"
	if payload is ArtRewardDefinition:
		return "获得技艺，可选择立即安装"
	if payload is UnitRewardDefinition:
		return "招募一名单位"
	if payload is RelicRewardDefinition:
		return "获得一件遗物"
	return ""


func _build_deployment(
	run: RunState,
	map_state: MapState
) -> DeploymentReadModel:
	if map_state == null:
		return null
	var node: MapNodeState = map_state.get_current_node()
	if node == null or not node.definition is EncounterMapNodeDefinition:
		return null
	var encounter: EncounterDefinition = (
		(node.definition as EncounterMapNodeDefinition).encounter
	)
	if encounter == null or encounter.battlefield == null:
		return null
	var battlefield: BattlefieldDefinition = encounter.battlefield
	var model: DeploymentReadModel = DeploymentReadModel.new()
	model.encounter_instance_id = node.instance_id
	model.encounter_name = encounter.display_name
	model.node_kind = node.definition.kind
	model.width = battlefield.width
	model.height = battlefield.height
	for y: int in range(battlefield.height):
		for x: int in range(battlefield.width):
			var coordinate: Vector2i = Vector2i(x, y)
			var terrain: TerrainDefinition = _terrain_at(
				battlefield,
				coordinate
			)
			var cell: DeploymentCellReadModel = (
				DeploymentCellReadModel.new()
			)
			cell.coordinate = coordinate
			if terrain != null:
				cell.terrain_name = terrain.display_name
				cell.movement_cost = terrain.movement_cost
				cell.blocks_movement = terrain.blocks_movement
			cell.allows_player_deployment = (
				battlefield.player_deployment_cells.has(coordinate)
			)
			for spawn: EnemySpawnDefinition in encounter.enemy_spawns:
				if spawn != null and spawn.coordinate == coordinate:
					cell.enemy_name = spawn.enemy_definition.display_name
					break
			model.cells.append(cell)
	for unit: RunUnitReadModel in _build_inventory(run).units:
		if not unit.is_defeated():
			model.available_units.append(unit)
	return model


func _terrain_at(
	battlefield: BattlefieldDefinition,
	coordinate: Vector2i
) -> TerrainDefinition:
	for placement: BattlefieldTerrainPlacement in battlefield.terrain_overrides:
		if placement != null and placement.coordinate == coordinate:
			return placement.terrain
	return battlefield.default_terrain


func _build_event(run: RunState, map_state: MapState) -> EventReadModel:
	if map_state == null:
		return null
	var node: MapNodeState = map_state.get_current_node()
	var session: MapNodeSessionState = map_state.get_active_session()
	var definition: MapEventDefinition = MapEventService.new(
	).get_event_definition(node)
	if node == null or session == null or definition == null:
		return null
	var model: EventReadModel = EventReadModel.new()
	model.title = definition.display_name
	model.node_kind = node.definition.kind
	model.stage = session.stage
	if session.event_session != null:
		model.selected_choice_id = session.event_session.selected_choice_id
		model.planned_outcome_id = session.event_session.planned_outcome_id
	var context: MapEventConditionContext = MapEventConditionContext.create(
		run,
		node,
		session.event_session,
		maxi(1, node.layer_index)
	)
	for source: MapEventChoiceDefinition in definition.choices:
		if source == null:
			continue
		var choice: EventChoiceReadModel = EventChoiceReadModel.new()
		choice.choice_id = source.choice_id
		choice.display_name = source.display_name
		choice.available = _condition_evaluator.evaluate_all(
			source.conditions,
			context
		).passed()
		if not choice.available:
			choice.unavailable_reason = "当前条件不满足"
		model.choices.append(choice)
		if choice.choice_id == model.selected_choice_id:
			model.selected_choice_name = choice.display_name
	return model

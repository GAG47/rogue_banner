class_name MapTestFactory
extends RefCounted

const HERO_PATH: String = "res://content/heroes/debug_run_hero.tres"
const TERRAIN_PATH: String = "res://content/terrains/debug_ground.tres"
const ENEMY_PATH: String = "res://content/enemies/debug_archer.tres"
const BATTLE_POOL_PATH: String = (
	"res://content/rewards/debug_battle_reward_pool.tres"
)
const SHOP_POOL_PATH: String = (
	"res://content/rewards/debug_shop_reward_pool.tres"
)


static func create_run(seed: int = 20260801) -> RunState:
	return RunState.create_from_setup(
			RunSetup.create(
					load(HERO_PATH) as HeroDefinition,
					seed,
					4,
					3,
					60
			)
	)


static func create_map(
	middle_node: MapNodeDefinition,
	layer_count: int = 1,
	minimum_nodes: int = 1,
	maximum_nodes: int = 1
) -> MapDefinition:
	var start: MapNodeDefinition = MapNodeDefinition.new()
	start.content_id = &"test_start_node"
	start.kind = GameEnums.MapNodeKind.START

	var entry: MapNodePoolEntry = MapNodePoolEntry.new()
	entry.node_definition = middle_node
	entry.minimum_layer = 1
	entry.maximum_layer = layer_count
	entry.minimum_copies = 1
	entry.maximum_copies = 0

	var definition: MapDefinition = MapDefinition.new()
	definition.content_id = &"test_map"
	definition.layer_count = layer_count
	definition.minimum_nodes_per_layer = minimum_nodes
	definition.maximum_nodes_per_layer = maximum_nodes
	definition.extra_connection_chance = 0.5
	definition.start_node = start
	definition.boss_node = create_encounter_node(
			GameEnums.MapNodeKind.BOSS,
			GameEnums.EnemyRank.BOSS,
			&"test_boss_node"
	)
	definition.node_pool.append(entry)
	return definition


static func create_encounter_node(
	kind: GameEnums.MapNodeKind,
	rank: GameEnums.EnemyRank,
	content_id: StringName
) -> EncounterMapNodeDefinition:
	var node: EncounterMapNodeDefinition = EncounterMapNodeDefinition.new()
	node.content_id = content_id
	node.kind = kind
	node.encounter = create_encounter(rank, content_id)
	return node


static func create_encounter(
	rank: GameEnums.EnemyRank,
	content_id: StringName = &"test_encounter"
) -> EncounterDefinition:
	var battlefield: BattlefieldDefinition = BattlefieldDefinition.new()
	battlefield.content_id = StringName("%s_battlefield" % content_id)
	battlefield.width = 5
	battlefield.height = 2
	battlefield.default_terrain = load(TERRAIN_PATH) as TerrainDefinition
	battlefield.player_deployment_cells.assign(
			[Vector2i(0, 0), Vector2i(0, 1)]
	)

	var spawn: EnemySpawnDefinition = EnemySpawnDefinition.new()
	spawn.enemy_definition = load(ENEMY_PATH) as EnemyDefinition
	spawn.coordinate = Vector2i(4, 0)

	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.content_id = StringName("%s_encounter" % content_id)
	encounter.battlefield = battlefield
	encounter.enemy_spawns.append(spawn)
	encounter.battle_rank = rank
	encounter.reward_pool = load(BATTLE_POOL_PATH) as RewardPoolDefinition
	return encounter


static func create_event_node(
	include_reward: bool = true
) -> EventMapNodeDefinition:
	var gold: ChangeGoldMapOperationDefinition = (
		ChangeGoldMapOperationDefinition.new()
	)
	gold.amount = 5
	var heal: HealUnitMapOperationDefinition = (
		HealUnitMapOperationDefinition.new()
	)
	heal.amount = 1
	var outcome: MapEventOutcomeDefinition = MapEventOutcomeDefinition.new()
	outcome.outcome_id = &"aid_result"
	outcome.operations.assign([gold, heal])
	if include_reward:
		var open_reward: OpenRewardPoolMapOperationDefinition = (
			OpenRewardPoolMapOperationDefinition.new()
		)
		open_reward.reward_pool = create_currency_pool(
				GameEnums.RewardOfferRule.TAKE_ALL,
				7,
				&"test_event_reward_pool"
		)
		outcome.operations.append(open_reward)
	var choice: MapEventChoiceDefinition = MapEventChoiceDefinition.new()
	choice.choice_id = &"aid"
	choice.display_name = "Aid the traveler"
	choice.outcomes.append(outcome)
	var event: MapEventDefinition = MapEventDefinition.new()
	event.content_id = &"test_event"
	event.choices.append(choice)
	var node: EventMapNodeDefinition = EventMapNodeDefinition.new()
	node.content_id = &"test_event_node"
	node.event_definition = event
	return node


static func create_shop_node() -> ShopMapNodeDefinition:
	var node: ShopMapNodeDefinition = ShopMapNodeDefinition.new()
	node.content_id = &"test_shop_node"
	node.reward_pool = load(SHOP_POOL_PATH) as RewardPoolDefinition
	return node


static func create_chest_node() -> ChestMapNodeDefinition:
	var node: ChestMapNodeDefinition = ChestMapNodeDefinition.new()
	node.content_id = &"test_chest_node"
	node.reward_pool = create_currency_pool(
			GameEnums.RewardOfferRule.TAKE_ALL,
			11,
			&"test_chest_reward_pool"
	)
	return node


static func create_currency_pool(
	rule: GameEnums.RewardOfferRule,
	amount: int,
	content_id: StringName
) -> RewardPoolDefinition:
	var payload: CurrencyRewardDefinition = CurrencyRewardDefinition.new()
	payload.amount = amount
	var entry: RewardEntryDefinition = RewardEntryDefinition.new()
	entry.payload = payload
	entry.allow_duplicate = true
	var pool: RewardPoolDefinition = RewardPoolDefinition.new()
	pool.content_id = content_id
	pool.offer_rule = rule
	pool.option_count = 1
	pool.entries.append(entry)
	return pool

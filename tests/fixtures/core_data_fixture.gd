class_name CoreDataFixture
extends RefCounted

var tag: TagDefinition
var condition: TestConditionDefinition
var effect: TestEffectDefinition
var trigger_effect: TestEffectDefinition
var trigger: TestTriggerDefinition
var targeting: TargetingDefinition
var active_art: ArtDefinition
var passive_art: ArtDefinition
var unit: UnitDefinition
var relic: RelicDefinition
var scroll: ScrollDefinition
var enemy: EnemyDefinition
var terrain: TerrainDefinition
var hero: HeroDefinition


static func create() -> CoreDataFixture:
	var fixture: CoreDataFixture = CoreDataFixture.new()

	fixture.tag = TagDefinition.new()
	fixture.tag.content_id = &"martial"
	fixture.tag.display_name = "Martial"

	fixture.condition = TestConditionDefinition.new()
	fixture.effect = TestEffectDefinition.new()
	fixture.trigger_effect = TestEffectDefinition.new()
	fixture.trigger_effect.target_source = GameEnums.EffectTargetSource.ACTOR

	fixture.trigger = TestTriggerDefinition.new()
	fixture.trigger.conditions.append(fixture.condition)
	fixture.trigger.effects.append(fixture.trigger_effect)

	fixture.targeting = TargetingDefinition.new()
	fixture.targeting.target_kind = GameEnums.TargetKind.UNIT
	fixture.targeting.target_relation = GameEnums.TargetRelation.ENEMY
	fixture.targeting.minimum_range = 1
	fixture.targeting.maximum_range = 2

	fixture.active_art = ArtDefinition.new()
	fixture.active_art.content_id = &"basic_strike"
	fixture.active_art.display_name = "Basic Strike"
	fixture.active_art.category = GameEnums.ArtCategory.ATTACK
	fixture.active_art.targeting = fixture.targeting
	fixture.active_art.required_tags.append(fixture.tag)
	fixture.active_art.installation_conditions.append(fixture.condition)
	fixture.active_art.use_conditions.append(fixture.condition)
	fixture.active_art.effects.append(fixture.effect)

	fixture.passive_art = ArtDefinition.new()
	fixture.passive_art.content_id = &"battle_focus"
	fixture.passive_art.display_name = "Battle Focus"
	fixture.passive_art.category = GameEnums.ArtCategory.PASSIVE
	fixture.passive_art.passive_triggers.append(fixture.trigger)

	fixture.unit = UnitDefinition.new()
	fixture.unit.content_id = &"vanguard"
	fixture.unit.display_name = "Vanguard"
	fixture.unit.max_health = 12
	fixture.unit.base_attack = 3
	fixture.unit.max_ap = 4
	fixture.unit.slot_count = 1
	fixture.unit.tags.append(fixture.tag)
	fixture.unit.default_arts.append(fixture.active_art)

	fixture.relic = RelicDefinition.new()
	fixture.relic.content_id = &"training_standard"
	fixture.relic.display_name = "Training Standard"
	fixture.relic.passive_triggers.append(fixture.trigger)

	fixture.scroll = ScrollDefinition.new()
	fixture.scroll.content_id = &"training_scroll"
	fixture.scroll.display_name = "Training Scroll"
	fixture.scroll.max_stack_size = 2
	fixture.scroll.targeting = fixture.targeting
	fixture.scroll.use_conditions.append(fixture.condition)
	fixture.scroll.effects.append(fixture.effect)

	fixture.enemy = EnemyDefinition.new()
	fixture.enemy.content_id = &"training_enemy"
	fixture.enemy.display_name = "Training Enemy"
	fixture.enemy.unit_definition = fixture.unit
	var enemy_intent: IntentDefinition = IntentDefinition.new()
	enemy_intent.content_id = &"training_enemy_strike"
	enemy_intent.display_name = "Training Strike"
	enemy_intent.art = fixture.active_art
	var enemy_cycle: FixedCycleDecisionDefinition = (
		FixedCycleDecisionDefinition.new()
	)
	enemy_cycle.sequence.append(enemy_intent)
	fixture.enemy.available_intents.append(enemy_intent)
	fixture.enemy.default_decision = enemy_cycle

	fixture.terrain = TerrainDefinition.new()
	fixture.terrain.content_id = &"stone_floor"
	fixture.terrain.display_name = "Stone Floor"
	fixture.terrain.tags.append(fixture.tag)

	fixture.hero = HeroDefinition.new()
	fixture.hero.content_id = &"commander"
	fixture.hero.display_name = "Commander"
	fixture.hero.starting_units.append(fixture.unit)
	fixture.hero.starting_relics.append(fixture.relic)
	fixture.hero.exclusive_relics.append(fixture.relic)
	fixture.hero.art_pool.append(fixture.active_art)
	fixture.hero.art_pool.append(fixture.passive_art)

	var tag_weight: TagWeight = TagWeight.new()
	tag_weight.tag = fixture.tag
	tag_weight.weight = 2.0
	fixture.hero.preferred_tags.append(tag_weight)

	return fixture

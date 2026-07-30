class_name ArtEffectFixture
extends RefCounted

var terrain: TerrainDefinition
var damage_effect: DamageEffectDefinition
var shield_effect: ShieldEffectDefinition
var attack_buff: BuffDefinition
var strike: ArtDefinition
var upgraded_strike: ArtDefinition
var guard: ArtDefinition
var focus: ArtDefinition
var reactive_guard: ArtDefinition
var player_definition: UnitDefinition
var enemy_definition: UnitDefinition
var battle: BattleState
var placement_service: BattlePlacementService
var turn_service: BattleTurnService
var action_service: BattleActionService
var player_unit_id: int = 0
var enemy_unit_id: int = 0
var second_enemy_unit_id: int = 0


static func create(with_passive_enemy: bool = false) -> ArtEffectFixture:
	var fixture: ArtEffectFixture = ArtEffectFixture.new()
	fixture._create_definitions()

	if with_passive_enemy:
		fixture.enemy_definition.slot_count = 1
		fixture.enemy_definition.default_arts.append(fixture.reactive_guard)

	fixture.battle = BattleState.create(
			GridState.create(5, 3, fixture.terrain)
	)
	fixture.placement_service = BattlePlacementService.new()
	fixture.turn_service = BattleTurnService.new()
	fixture.action_service = BattleActionService.new(
			GridPathfinder.new(),
			fixture.turn_service
	)

	var player: BattlePlacementResult = (
		fixture.placement_service.place_unit_definition(
				fixture.battle,
				fixture.player_definition,
				GameEnums.BattleSide.PLAYER,
				Vector2i(1, 1)
		)
	)
	var enemy: BattlePlacementResult = (
		fixture.placement_service.place_unit_definition(
				fixture.battle,
				fixture.enemy_definition,
				GameEnums.BattleSide.ENEMY,
				Vector2i(2, 1)
		)
	)
	fixture.player_unit_id = player.unit_id
	fixture.enemy_unit_id = enemy.unit_id
	if with_passive_enemy:
		var second_enemy: BattlePlacementResult = (
			fixture.placement_service.place_unit_definition(
					fixture.battle,
					fixture.enemy_definition,
					GameEnums.BattleSide.ENEMY,
					Vector2i(3, 1)
			)
		)
		fixture.second_enemy_unit_id = second_enemy.unit_id
	fixture.action_service.start_battle(fixture.battle)
	return fixture


func _create_definitions() -> void:
	terrain = TerrainDefinition.new()
	terrain.content_id = &"v3_test_ground"

	damage_effect = DamageEffectDefinition.new()
	damage_effect.flat_amount = 0
	damage_effect.attribute_multiplier = 1.0
	damage_effect.source_attribute = GameEnums.AttributeType.BASE_ATTACK

	shield_effect = ShieldEffectDefinition.new()
	shield_effect.flat_amount = 3

	upgraded_strike = _create_active_art(
			&"v3_upgraded_strike",
			2,
			1,
			_create_enemy_targeting(1),
			[damage_effect]
	)

	strike = _create_active_art(
			&"v3_strike",
			2,
			1,
			_create_enemy_targeting(1),
			[damage_effect]
	)
	strike.upgraded_variant = upgraded_strike

	var self_targeting: TargetingDefinition = TargetingDefinition.new()
	self_targeting.target_kind = GameEnums.TargetKind.UNIT
	self_targeting.target_relation = GameEnums.TargetRelation.SELF
	self_targeting.minimum_range = 0
	self_targeting.maximum_range = 0
	self_targeting.requires_line_of_sight = false

	guard = _create_active_art(
			&"v3_guard",
			1,
			2,
			self_targeting,
			[shield_effect]
	)

	var attack_modifier: ModifierDefinition = ModifierDefinition.new()
	attack_modifier.attribute = GameEnums.AttributeType.BASE_ATTACK
	attack_modifier.operation = GameEnums.ModifierOperation.FLAT
	attack_modifier.value = 2.0
	attack_buff = BuffDefinition.new()
	attack_buff.content_id = &"v3_attack_focus"
	attack_buff.duration_turns = 2
	attack_buff.stacking_rule = GameEnums.BuffStackingRule.ADD_STACKS
	attack_buff.maximum_stacks = 2
	attack_buff.modifiers.append(attack_modifier)

	var apply_buff_effect: ApplyBuffEffectDefinition = (
		ApplyBuffEffectDefinition.new()
	)
	apply_buff_effect.buff = attack_buff
	focus = _create_active_art(
			&"v3_focus",
			1,
			0,
			self_targeting,
			[apply_buff_effect]
	)

	var reactive_shield: ShieldEffectDefinition = ShieldEffectDefinition.new()
	reactive_shield.flat_amount = 2
	reactive_shield.target_source = (
		GameEnums.EffectTargetSource.EVENT_TARGET_UNIT
	)
	var trigger: TriggerDefinition = TriggerDefinition.new()
	trigger.event_kind = GameEnums.BattleEventKind.DAMAGE_APPLIED
	trigger.maximum_triggers_per_action = 1
	var owner_was_targeted: EventUnitRelationConditionDefinition = (
		EventUnitRelationConditionDefinition.new()
	)
	owner_was_targeted.event_unit_role = GameEnums.EventUnitRole.TARGET
	owner_was_targeted.relation = GameEnums.TargetRelation.SELF
	trigger.conditions.append(owner_was_targeted)
	trigger.effects.append(reactive_shield)
	reactive_guard = ArtDefinition.new()
	reactive_guard.content_id = &"v3_reactive_guard"
	reactive_guard.category = GameEnums.ArtCategory.PASSIVE
	reactive_guard.passive_triggers.append(trigger)

	player_definition = UnitDefinition.new()
	player_definition.content_id = &"v3_player"
	player_definition.max_health = 10
	player_definition.base_attack = 3
	player_definition.max_ap = 5
	player_definition.slot_count = 3
	player_definition.default_arts.assign([strike, guard, focus])

	enemy_definition = UnitDefinition.new()
	enemy_definition.content_id = &"v3_enemy"
	enemy_definition.max_health = 7
	enemy_definition.base_attack = 2
	enemy_definition.max_ap = 4


func _create_enemy_targeting(maximum_range: int) -> TargetingDefinition:
	var targeting: TargetingDefinition = TargetingDefinition.new()
	targeting.target_kind = GameEnums.TargetKind.CELL
	targeting.target_relation = GameEnums.TargetRelation.ENEMY
	targeting.minimum_range = 1
	targeting.maximum_range = maximum_range
	targeting.requires_line_of_sight = true
	return targeting


func _create_active_art(
		content_id: StringName,
		ap_cost: int,
		cooldown: int,
		targeting: TargetingDefinition,
		effects: Array[EffectDefinition]
) -> ArtDefinition:
	var art: ArtDefinition = ArtDefinition.new()
	art.content_id = content_id
	art.category = GameEnums.ArtCategory.ATTACK
	art.ap_cost = ap_cost
	art.cooldown = cooldown
	art.targeting = targeting
	art.effects.assign(effects)
	return art


func create_unit_selection(unit_id: int) -> TargetSelection:
	var selection: TargetSelection = TargetSelection.new()
	selection.unit_instance_ids.append(unit_id)
	return selection


func create_cell_selection(coordinate: Vector2i) -> TargetSelection:
	var selection: TargetSelection = TargetSelection.new()
	selection.cells.append(coordinate)
	return selection

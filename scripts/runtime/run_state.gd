class_name RunState
extends RefCounted

var hero_definition: HeroDefinition
var run_seed: int = 0
var gold: int = 0
var team: Array[RunUnitState] = []
var relics: Array[RelicDefinition] = []
var scrolls: Array[ScrollStackState] = []


static func create(hero: HeroDefinition, seed: int) -> RunState:
	var state: RunState = RunState.new()
	state.hero_definition = hero
	state.run_seed = seed

	if hero == null or not DefinitionValidator.new().validate(hero).is_valid():
		return null

	var next_unit_instance_id: int = 1
	for unit_definition: UnitDefinition in hero.starting_units:
		if unit_definition == null:
			continue
		var run_unit: RunUnitState = RunUnitState.create(
				next_unit_instance_id,
				unit_definition
		)
		if run_unit == null:
			return null
		state.team.append(run_unit)
		next_unit_instance_id += 1

	for relic_definition: RelicDefinition in hero.starting_relics:
		if relic_definition != null:
			state.relics.append(relic_definition)

	return state

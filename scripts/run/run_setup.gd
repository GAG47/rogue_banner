class_name RunSetup
extends RefCounted

var hero_definition: HeroDefinition
var seed: int = 0
var team_capacity: int = 4
var scroll_slot_capacity: int = 3
var starting_gold: int = 0


static func create(
		hero: HeroDefinition,
		run_seed: int,
		maximum_team_size: int = 4,
		maximum_scroll_slots: int = 3,
		initial_gold: int = 0
) -> RunSetup:
	var setup: RunSetup = RunSetup.new()
	setup.hero_definition = hero
	setup.seed = run_seed
	setup.team_capacity = maximum_team_size
	setup.scroll_slot_capacity = maximum_scroll_slots
	setup.starting_gold = initial_gold
	return setup


func is_valid() -> bool:
	return (
		hero_definition != null
		and team_capacity > 0
		and scroll_slot_capacity >= 0
		and starting_gold >= 0
		and hero_definition.starting_units.size() <= team_capacity
	)


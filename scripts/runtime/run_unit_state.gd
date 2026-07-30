class_name RunUnitState
extends RefCounted

var instance_id: int = 0
var definition: UnitDefinition
var current_health: int = 0
var installed_arts: Array[ArtDefinition] = []


static func create(
		unit_instance_id: int,
		unit_definition: UnitDefinition
) -> RunUnitState:
	if unit_definition == null:
		return null
	var validator: DefinitionValidator = DefinitionValidator.new()
	if not validator.validate(unit_definition).is_valid():
		return null

	var state: RunUnitState = create_empty(
			unit_instance_id,
			unit_definition
	)
	var loadout_service: ArtLoadoutService = ArtLoadoutService.new(
			null,
			validator
	)
	for slot_index: int in range(unit_definition.default_arts.size()):
		var installation: ArtLoadoutResult = loadout_service.install(
				state,
				unit_definition.default_arts[slot_index],
				slot_index
		)
		if not installation.succeeded():
			return null
	return state


static func create_empty(
		unit_instance_id: int,
		unit_definition: UnitDefinition
) -> RunUnitState:
	var state: RunUnitState = RunUnitState.new()
	state.instance_id = unit_instance_id
	state.definition = unit_definition
	if unit_definition == null:
		return state
	state.current_health = unit_definition.max_health
	for slot_index: int in range(unit_definition.slot_count):
		state.installed_arts.append(null)
	return state


func is_defeated() -> bool:
	return current_health <= 0

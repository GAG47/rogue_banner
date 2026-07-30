class_name BattleKernelFixture
extends RefCounted

var core: CoreDataFixture
var difficult_terrain: TerrainDefinition
var blocked_terrain: TerrainDefinition
var grid: GridState
var battle: BattleState
var placement_service: BattlePlacementService
var turn_service: BattleTurnService
var action_service: BattleActionService
var run_unit: RunUnitState


static func create(
		width: int = 5,
		height: int = 3
) -> BattleKernelFixture:
	var fixture: BattleKernelFixture = BattleKernelFixture.new()
	fixture.core = CoreDataFixture.create()

	fixture.difficult_terrain = TerrainDefinition.new()
	fixture.difficult_terrain.content_id = &"difficult_ground"
	fixture.difficult_terrain.movement_cost = 2

	fixture.blocked_terrain = TerrainDefinition.new()
	fixture.blocked_terrain.content_id = &"wall"
	fixture.blocked_terrain.blocks_movement = true

	fixture.grid = GridState.create(width, height, fixture.core.terrain)
	fixture.battle = BattleState.create(fixture.grid)
	fixture.placement_service = BattlePlacementService.new()
	fixture.turn_service = BattleTurnService.new()
	fixture.action_service = BattleActionService.new(
			GridPathfinder.new(),
			fixture.turn_service
	)
	fixture.run_unit = RunUnitState.create(41, fixture.core.unit)
	return fixture

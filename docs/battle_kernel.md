# Battle Kernel

## Scope

Battle kernel v2 provides Grid topology, Terrain traversal, authoritative
occupancy, weighted pathfinding, Battle Unit placement, Battle-local identity,
turn transitions, AP and cooldown refresh, typed action requests, validation,
execution plans, and atomic Move execution.

It does not provide UI, scenes, concrete Art effects, enemy decisions, Intents,
damage, victory resolution, route maps, rewards, shops, or content instances.

## Dependency Direction

```text
TerrainDefinition
→ CellState
→ GridState
→ GridPathfinder

RunUnitState
→ UnitState
→ BattleState
→ BattlePlacementService

BattleActionRequest
→ BattleActionService
├── GridPathfinder
├── GridState
└── BattleTurnService
```

Grid depends only on Terrain Definitions, coordinates, occupant handles, and
typed Grid results. It does not depend on Unit State, Art, Battle actions, UI,
or scene nodes.

## Grid Topology

`GridState.create` establishes immutable width and height and creates one
`CellState` for every coordinate.

`CellState` owns:

- Its coordinate
- Its current Terrain Definition reference

It does not own occupancy.

Grid queries provide:

- Bounds validation
- Cell lookup
- Four-direction cardinal neighbors
- Manhattan distance
- Terrain movement cost
- Cell passability

An invalid Grid has non-positive dimensions or an incomplete Cell collection.
Battle setup and actions reject invalid Grid state.

## Terrain

Terrain passability and movement cost come only from `TerrainDefinition`.

- Null Terrain is invalid for placement and movement.
- `blocks_movement` prevents placement and path traversal.
- `movement_cost` is paid when a Unit enters a Cell.
- The starting Cell does not contribute to Move AP cost.

The Definition validator remains responsible for rejecting movement costs below
one.

## Authoritative Occupancy

The private occupancy table inside `GridState` is the only authoritative source
for Unit and scene object positions.

`GridOccupant` is a typed runtime handle containing:

- `GridOccupantKind`
- Positive runtime ID

Supported kinds are Unit and scene object. Occupants never contain Node
references.

Occupancy invariants:

- One coordinate contains at most one occupant.
- One typed occupant can appear at most once.
- Blocking Terrain cannot receive an occupant.
- Movement verifies the expected source occupant.
- Failed placement, movement, or removal does not change occupancy.
- Unit State does not store a second position.

Position queries return `GridCoordinate` values derived from the occupancy
table. `CellState` and `BattleState` do not cache another writable position.

## Pathfinding

`GridPathfinder` uses deterministic Dijkstra traversal over cardinal neighbors.
It minimizes total Terrain movement cost rather than Cell count.

A successful `GridPathResult` contains:

- Ordered coordinates including start and destination
- Total movement cost

Typed path failures distinguish invalid Grid state, invalid bounds, blocked
destinations, and unreachable destinations. Occupied Cells and blocking Terrain
are not traversable.

Pathfinding is a pure query and never reserves Cells, spends AP, or mutates
Battle state.

## Battle Unit Identity

`BattleState` owns a monotonic Battle-local Unit ID allocator.

- The first ID is one.
- Every successful placement receives a unique ID.
- Removed IDs are never reused.
- Invalid placements do not consume IDs.

Player Battle Units retain `source_run_unit_id` separately. This identity is
reserved for returning future Battle outcomes to Run state and never serves as
the Battle-local ID.

## Run to Battle Copy

`UnitState.create_from_run_unit` creates independent Battle state:

- Copies the typed Unit Definition reference
- Copies current health within Definition bounds
- Copies installed Art Definition references into new Art State objects
- Initializes AP from the Unit Definition
- Initializes cooldowns independently
- Stores the source Run Unit ID

It does not share mutable arrays, Art State, AP, cooldown, side, or position with
`RunUnitState`.

## BattleState

Battle State owns:

- Grid State
- Battle phase
- Active side
- Round number
- Battle Unit State indexed by Battle-local ID
- The next Battle-local Unit ID

Battle State provides typed queries and internal registration operations. It
does not perform pathfinding, action validation, Art execution, or enemy
decisions.

## Placement

`BattlePlacementService` is the only Battle-level composition service for Unit
registration and Grid occupancy.

It supports:

- Creating and placing a Unit from Run Unit State
- Creating and placing a Unit from Unit Definition
- Querying Unit position through Grid
- Removing a Unit and its occupancy
- Removing defeated Units and reporting their IDs

Initial placement is limited to the setup phase. Runtime summoning is deferred
until its requirements are known.

Placement commits Grid occupancy before Unit registration and compensates by
removing occupancy if registration unexpectedly fails. A Unit cannot exist as a
successful placement with only one half committed.

## Turn Lifecycle

`BattleTurnService.start_battle` transitions setup to round one of the player
turn.

Turn order is:

```text
Player turn
→ Enemy turn
→ Increment round
→ Player turn
```

At the start of a side's turn, every living Unit on that side:

- Restores AP to its Unit Definition maximum
- Decrements each positive Art cooldown by one

The inactive side is not refreshed. Defeated Unit removal is an explicit
placement-service operation and is not hidden inside turn transitions.

## Action Contracts

Implemented requests:

- `MoveActionRequest`
- `UseArtActionRequest`
- `EndTurnActionRequest`

Every request declares its requesting side. Unit actions also contain the
Battle-local actor ID.

`BattleActionService` provides separate validation and execution entry points.
Execution always performs validation first.

Expected failures use `ActionFailureCode`. They do not print errors, mutate
state, or depend on UI.

## Move Action

Move validation checks:

- Active Battle phase
- Requesting side and turn ownership
- Actor existence, side, living state, and placement
- Destination bounds, Terrain, and occupancy
- Reachable weighted path
- Sufficient AP

Successful validation produces an `ActionExecutionPlan` containing the
authoritative path and AP cost.

Move execution rechecks the state needed for commit, moves the Grid occupant,
and then spends AP. If the Grid commit fails, AP is not spent.

## End Turn Action

End Turn validates the requesting side through the same action service. A
successful request delegates to `BattleTurnService`, refreshes the new active
side, and returns the resulting phase, side, and round in
`ActionExecutionResult`.

## Use Art Boundary

Use Art v2 validates:

- Active side and actor
- Installed Art slot
- Active Art category
- Cooldown
- AP
- Basic target count

Concrete target resolution, Conditions, Effects, cooldown commitment, and AP
commit belong to the Art and Effect phase. A structurally valid v2 request
returns `ART_EXECUTION_UNAVAILABLE`.

This explicit rejection guarantees that an Art cannot spend AP or start
cooldown without executing its effects.

## Atomicity

Predictable validation occurs before mutation.

- Failed placement does not add a Unit or occupant.
- Failed movement does not change occupancy or AP.
- Failed End Turn does not change phase, side, round, AP, or cooldown.
- Unavailable Art execution does not change AP or cooldown.
- Unit removal clears occupancy before unregistering Unit State.

UI and enemy decision systems must submit requests to the action service. They
must not mutate Battle State, Grid State, Unit State, AP, or cooldown directly.

## Test Boundary

Headless tests cover:

- Grid dimensions, bounds, Cells, distance, and neighbors
- Terrain blocking and movement cost
- Unit and scene object occupancy
- Duplicate occupancy and source validation
- Weighted and unreachable paths
- Out-of-bounds, blocked, and occupied placement
- Run-to-Battle state isolation
- Unique and non-reused Battle IDs
- Move path cost and AP spending
- Atomic failure behavior
- Side ownership
- Turn transitions, AP refresh, and cooldown progress
- Non-committing Use Art entry
- Defeated Unit cleanup

## Debug Visualization

Battle kernel v2.1 adds `battle_debug.tscn` as a presentation-only executable
probe. It composes authored debug Terrain and Unit Resources with the v2
services and renders:

- Terrain traversal cost and blocking
- Unit and scene-object occupancy
- Player Unit selection
- Reachable Move destinations obtained from action validation
- Move AP cost and committed Unit position
- Player and enemy turn transitions

The debug controller never writes Grid occupancy, Unit AP, or turn state
directly. It submits `MoveActionRequest` and `EndTurnActionRequest` instances to
`BattleActionService`, then redraws from the resulting authoritative state.
Enemy decisions, attacks, damage, and Art execution remain outside v2.1.

The scene is intentionally not configured as the project main scene. It can be
opened and run directly as a debug probe without changing project startup
configuration.

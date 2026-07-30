# v2 Battle Kernel Development Log

## Date

2026-07-30

## Goal

Establish a complete headless Battle kernel for Grid topology, Terrain,
occupancy, Unit placement, Run-to-Battle state copying, movement, AP, turns,
cooldowns, and typed action boundaries.

## Delivered

### Grid

- Added fixed Grid dimensions and Cell creation.
- Added bounds, Cell, cardinal neighbor, and Manhattan distance queries.
- Added Terrain replacement, passability, and movement-cost queries.
- Added typed Grid operation and path results.

### Occupancy

- Added typed Unit and scene object occupant handles.
- Added placement, movement, removal, and position queries.
- Made the private Grid occupancy table the only position source.
- Removed duplicate position state from `UnitState`.
- Prevented duplicate occupants and duplicate Cell occupancy.

### Pathfinding

- Added deterministic Dijkstra pathfinding.
- Added weighted Terrain movement costs.
- Added blocked, occupied, out-of-bounds, and unreachable path handling.
- Kept pathfinding read-only.

### Battle Unit State

- Added separate Battle-local and source Run Unit identities.
- Added independent Run-to-Battle Unit State creation.
- Copied installed Art Definitions into new Art State objects.
- Added AP refresh and cooldown progress for living Units.

### Battle State and Placement

- Added Grid ownership to Battle State.
- Added Unit lookup indexed by Battle-local ID.
- Added monotonic Unit ID allocation with no ID reuse.
- Added Run Unit and Unit Definition placement.
- Added Unit removal and defeated Unit cleanup.
- Kept initial placement restricted to setup.

### Actions

- Added `BattleActionRequest`.
- Added `MoveActionRequest`.
- Added `UseArtActionRequest`.
- Added `EndTurnActionRequest`.
- Added typed validation results, execution plans, and execution results.
- Added one authoritative Battle action service.

Move actions validate turn ownership, actor state, destination, weighted path,
and AP before committing Grid movement and AP cost.

Use Art validates its stable v2 boundary but returns
`ART_EXECUTION_UNAVAILABLE`. It cannot spend AP or start cooldown before the
future Effect executor is connected.

### Turns

- Added setup-to-player-turn transition.
- Added player and enemy turn transitions.
- Added round increment after the enemy turn.
- Added active-side AP refresh.
- Added active-side cooldown progress.
- Rejected End Turn requests from the inactive side.

## Architectural Corrections

### Position Authority

v1 stored an optional position on `UnitState`. v2 removed that field because it
would duplicate Grid occupancy.

The authoritative position model is now:

```text
GridState occupancy
→ position query
→ Unit, scene object, action, and future UI consumers
```

`CellState`, `UnitState`, and `BattleState` do not cache a second position.

### Identity Boundary

Battle Unit IDs and Run Unit IDs now have distinct meanings:

- Battle State allocates Battle-local IDs.
- Player Unit State retains the source Run Unit ID.
- Enemy and future summoned Units do not require a Run identity.
- Removed Battle IDs are never reused.

## Tests

The dependency-free headless runner now executes v1 and v2 suites together.

Coverage includes:

- Grid dimensions, bounds, Cells, distance, and adjacency
- Blocking and difficult Terrain
- Unit and scene object occupancy
- Duplicate occupancy and movement source checks
- Weighted and unreachable paths
- Invalid and successful Unit placement
- Independent Run and Battle Unit State
- Battle Unit ID allocation and non-reuse
- Move validation, path cost, and AP spending
- Atomic rejection behavior
- Actor and turn ownership
- Player and enemy turn transitions
- AP refresh and cooldown progress
- Non-committing Use Art entry
- Defeated Unit cleanup and occupancy release

## Verification

Commands:

```bash
env XDG_DATA_HOME=/tmp/rogue_banner_godot_data \
    XDG_CONFIG_HOME=/tmp/rogue_banner_godot_config \
    XDG_CACHE_HOME=/tmp/rogue_banner_godot_cache \
    godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --editor --quit
git diff --check
```

Results:

- Godot Engine 4.7.1 parsed and registered all v1 and v2 scripts.
- All 125 project assertions passed.
- The required headless editor command exited with code 0.
- `git diff --check` passed.

The restricted execution environment still denies the editor's optional TCP
listener and default settings write. Temporary XDG directories prevent the
settings-write issue. The TCP warning does not prevent scanning, parsing,
testing, editor loading, or a successful process exit.

## Files Intentionally Unchanged

- No `.tscn` file was created or modified.
- `project.godot` was not modified.
- No UI, concrete Art effect, enemy AI, Intent, route map, reward, shop, or
  content instance was added.

## Next Phase

The next dependency-ready phase is Art and Effect execution:

- Battle-aware Condition contexts
- Target resolution
- AP and cooldown commitment for Arts
- Ordered Effect execution
- Typed Battle events
- Passive trigger subscriptions

That phase must enter through `UseArtActionRequest` and the existing Battle
action service rather than modifying Unit or Grid state directly.

# v1 Core Data Layer Development Log

## Date

2026-07-30

## Goal

Establish the first executable core data layer for Rogue Banner. The milestone
provides typed Godot Resource Definitions, isolated runtime State, generic rule
contracts, validation, and headless tests without implementing gameplay
behavior.

## Delivered

### Core Types

- Added public enums for Art rarity and category, Battle phase and side,
  targeting, enemy rank, rule results, and Definition validation.
- Added typed Definition validation issue and result values.
- Added a typed Grid coordinate value.

### Static Definitions

- Added `DefinitionResource`.
- Added `TagDefinition` and `TagWeight`.
- Added `HeroDefinition`.
- Added `UnitDefinition`.
- Added `ArtDefinition`.
- Added `RelicDefinition`.
- Added `ScrollDefinition`.
- Added `EnemyDefinition`.
- Added `TerrainDefinition`.

Every top-level Definition is a registered Godot Resource with a required stable
content ID. No Definition contains current health, AP, cooldown, quantity,
position, currency, or other mutable Run or Battle values.

### Rule Contracts

- Added Condition Definition, context, and result contracts.
- Added Effect Definition, context, result, and executor contracts.
- Added Targeting Definition, context, selection, and resolver contracts.
- Added Trigger Definition composition for passive Arts and Relics.

No concrete gameplay Condition, Effect, Trigger, targeting algorithm, enemy
decision, or Art behavior was added.

### Runtime State

- Added `ArtState`.
- Added Battle-owned `UnitState`.
- Added Run-owned `RunUnitState`.
- Added `ScrollStackState`.
- Added data-only `BattleState`.
- Added data-only `RunState`.

Run and Battle Unit state are separate by design. Mutable Battle AP, cooldown,
side, and position cannot leak into Run team state.

### Validation

Added a stateless `DefinitionValidator` that checks:

- Empty content IDs
- Invalid numeric values
- Null and duplicate references
- Tag validity
- Default Art slot and tag installation compatibility
- Condition, Effect, Targeting, and Trigger configuration
- Required active effects and passive triggers
- Art upgrade cycles and duplicate variant IDs

### Tests

Added a dependency-free headless GDScript test runner and typed fixtures. Tests
cover every v1 Definition, invalid configuration, rule contract values,
Definition and State isolation, Run and Battle state separation, and Godot
Resource serialization.

## Architectural Decisions

- Definitions use `Resource`; runtime State uses `RefCounted`.
- `RunState` stores `RunUnitState`, never Battle `UnitState`.
- Active Arts use ordered Effects; passive Arts and Relics use typed Trigger
  definitions.
- Art upgrades reference a typed upgraded `ArtDefinition` variant.
- Enemy AI and Intent data remain absent until the Enemy and Intent phase.
- `BattleState` remains a data container until the Battle kernel phase.
- Cross-file content ID uniqueness remains the responsibility of the future
  `ContentCatalog`; v1 validation checks one Definition graph at a time.

## Files Intentionally Unchanged

- No `.tscn` file was created or modified.
- `project.godot` was not modified.
- No UI, map, shop, reward, or content Resource instance was added.

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

- Godot Engine 4.7.1 registered and parsed all global script classes.
- All 48 core data layer assertions passed.
- Resource save and load round-trip tests passed.
- The required headless editor command exited with code 0.
- `git diff --check` passed.

The restricted execution environment denied the editor's optional TCP listener
and default editor-settings write. Running with temporary XDG data, config, and
cache directories removed the settings-write issue; the TCP warning remained,
but class registration, filesystem scanning, editor loading, and process exit
completed successfully.

## Next Phase

The next major phase is the Grid and Battle kernel:

- Grid bounds and coordinates
- Terrain and occupancy
- Battle Unit placement
- Pathfinding and movement validation
- AP and cooldown lifecycle
- Turn state and action contracts
- Battle resolution

That phase must consume the v1 data layer through its typed Definitions and
runtime State without adding content-specific branches.

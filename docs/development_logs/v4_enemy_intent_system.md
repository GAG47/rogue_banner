# v4 Enemy Intent and Automatic Turn Development Log

## Date

2026-07-31

## Goal

Create a complete telegraphed enemy-action loop in which preview and execution
consume one stored plan and every committed enemy action uses the existing
Battle action pipeline.

## Delivered

- Added locked, pattern, and enhance Intent Definitions.
- Added fixed-cycle and conditional priority decision policies.
- Added deterministic weighted selection from Battle seed and state.
- Added reusable Enemy decision Conditions for health ratio and nearby Units.
- Added typed Enemy phase Definitions and generation-boundary phase changes.
- Added battle-owned Enemy State and persistent Intent Plan.
- Added locked Unit, Cell, and scene-object targeting.
- Added pattern direction with generic cardinal footprint rotation.
- Added fixed movement destinations and ordered movement/Art sequences.
- Added read-only live Intent Preview derived from stored plans.
- Added explicit executed, fizzled, skipped, and internal-failure step outcomes.
- Added ordered automatic enemy execution through Move and Use Art requests.
- Added outer Battle transactions for start, enemy execution, turn transition,
  and next-batch generation.
- Added generic forced movement and typed movement events.
- Added archer, heavy Unit, priest, and player shove debug content.
- Added Chinese Intent summaries, danger Cells, movement paths, and enemy badges
  to the existing debug scene.

## Architecture Decisions

- Art Definitions remain the only source for costs, cooldowns, targeting,
  geometry, and effects.
- Intent Plans store commitments, not v3 execution plans or resolved hits.
- Movement locks a destination while pathfinding remains an execution-time
  query.
- Pattern direction is fixed in the plan while its origin follows the enemy's
  current or projected position.
- Normal battlefield disruption fizzles and continues.
- Internal rule failures abort and roll back the complete automatic flow.
- Boss phases never replace an Intent already shown to the player.
- Enemy State does not duplicate Unit or Grid runtime values.

## Authored Debug Content

- Archer: locks one player Unit and uses a ranged Art.
- Heavy Unit: publishes a fixed move destination and a directional three-Cell
  pattern.
- Priest: locks the lowest-health allied Unit for shielding.
- Player shove: uses generic forced movement to change the heavy Unit's live
  danger Cells.

## Verification

- All 328 project assertions passed.
- The v4 debug scene loaded and ran headlessly.
- The Godot headless editor check completed with exit code zero.
- `git diff --check` passed.
- `project.godot` remained unchanged.

Run the debug scene directly:

```text
res://scenes/debug/battle_debug.tscn
```

The project still has no configured main scene.

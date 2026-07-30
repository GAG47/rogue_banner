# v2.1 Battle Debug View Development Log

## Date

2026-07-30

## Goal

Make the v2 Battle kernel directly observable and interactive without adding
gameplay rules to the presentation layer.

## Delivered

- Added a standalone Battle debug scene.
- Added separate Grid, highlight, and Unit drawing nodes.
- Added authored debug Terrain and Unit Resources.
- Added player Unit selection and hover feedback.
- Derived reachable Cells by validating typed Move requests.
- Submitted Move and End Turn requests through `BattleActionService`.
- Displayed Terrain cost, blocking, occupancy, Unit health, AP, round, phase,
  active side, selection, action costs, and rejection feedback.
- Added Simplified Chinese player-facing interface copy.
- Added a reset action that rebuilds only the debug composition.

## Boundaries

- Grid State remains the only position and occupancy authority.
- Unit State remains the health and AP authority.
- Battle State and the turn service remain the phase and round authority.
- The debug scene stores only presentation selection and hover state.
- The debug scene contains no enemy decisions, Art execution, damage, rewards,
  route map, or persistence behavior.
- `project.godot` remains unchanged and no main scene is configured.

## Verification

The automated scene probe loads the packed scene, instantiates the typed
controller, builds the debug Battle, and verifies Unit count, total occupancy,
round, starting phase, and validation of every authored debug Definition.

Results:

- All 140 project assertions passed.
- The standalone debug scene loaded and ran headlessly without script errors.
- The Godot headless editor check completed successfully.
- `git diff --check` passed.

Run the scene directly from the Godot editor:

```text
res://scenes/debug/battle_debug.tscn
```

Use the editor command for running the current scene. Project-wide run remains
unset because the project has no main scene.

# v5 Run, Reward, and Battle Outcome Development Log

## Date

2026-07-31

## Goal

Create a persistent Run construction loop across Battles while keeping Run,
Battle, Reward, and UI authority separate and transactional.

## Delivered

- Added runtime Art, Relic, and Scroll-stack identities.
- Converted Unit Art slots to owned Art instance IDs.
- Added private Run inventories, capacities, phases, sessions, offers, counters,
  and version-checked transactions.
- Added typed Run commands for Gold, Units, Arts, Relics, Scrolls, and healing.
- Added Battle setup snapshots and persistent Run participant mappings.
- Added typed terminal Battle outcomes and one-time atomic Run writeback.
- Added typed Unit, Relic, Scroll, and system Battle sources.
- Registered owned Relics in the existing Battle trigger processor.
- Added ownerless Relic configuration validation.
- Added Scroll Battle actions through the existing targeting, effect, event,
  cleanup, and terminal-resolution pipeline.
- Added Reward payload, entry, and pool Definitions with validation.
- Added deterministic filter-then-weighted-selection Reward generation.
- Added saved Reward offers with pick-one, take-all, and purchase-any rules.
- Added atomic Reward claims, purchases, immediate Art installation, healing,
  upgrades, recruitment, and shop closure.
- Added `RunFlowService` for Battle entry, outcome resolution, Reward creation,
  and shop entry.
- Added static v5 debug content and a Chinese two-Battle Run debug scene.

## Architecture Decisions

- `RunState` is the sole authority for persistent inventory and active offers.
- Battle always operates on copies and never writes Run directly.
- Default Arts are ordinary owned instances and may later be uninstalled or
  forgotten.
- Reward generation and Reward grant are separate; the stored offer bridges
  display and execution.
- Battle failure writes health and Scroll consumption, ends the Run, and does
  not create a Reward.
- Scrolls identify a using Unit but cost no AP.
- Relics belong to a side rather than a Unit and cannot use actor-dependent
  configuration.
- Content unlock filtering remains deferred until the unlock system owns that
  data in v9.

## Verification Coverage

The v5 suites cover:

- Runtime Art identity, installation, and upgrade isolation
- Scroll stacking and atomic overflow rejection
- Stale Run transaction rejection
- Deterministic Reward output
- Unaffordable purchase rollback
- Battle copy isolation
- Health and Scroll outcome writeback
- Duplicate outcome rejection
- Art Reward installation
- Relic purchase and Battle trigger registration
- Unit recruitment and second-Battle participation
- Relic trigger-chain rollback after internal failure
- Failure outcome without Reward
- Complete Chinese debug-scene progression

## Verification Result

- All 403 project assertions passed.
- The v5 debug scene instantiated and ran headlessly without runtime errors.
- The Godot 4.7.1 headless editor check completed with exit code zero.
- `git diff --check` passed.
- `project.godot` remained unchanged.

Run:

```text
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --editor --quit
```

Open:

```text
res://scenes/debug/run_debug.tscn
```

`project.godot` remains unchanged, so the project still has no configured main
scene.

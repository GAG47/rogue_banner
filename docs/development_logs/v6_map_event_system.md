# v6 Map, Encounter, and Event Development Log

## Date

2026-08-01

## Goal

Create deterministic route progression across Run activities while preserving
Battle, Reward, Event, and Map authority as separate transactional systems.

## Delivered

- Added typed Map, node, Battlefield, Encounter, Event, camp, and Event-operation
  Definitions.
- Extended authored-content validation for every v6 Definition boundary.
- Added deterministic layered directed Map generation with stable node IDs and
  guaranteed forward connectivity.
- Added Run-owned `MapState`, detached Map snapshots, computed reachability and
  visibility, and `MapReadModel`.
- Added persistent node and Event sessions with monotonic progression IDs.
- Added `EncounterBuildService` to combine authored Battlefield content with
  runtime player deployments.
- Added transaction-internal Battle and Reward orchestration interfaces.
- Added Battle-session and Reward-offer provenance linking downstream work to
  the active Map node.
- Closed standalone v5 entry points for Map-owned Battles and offers so node
  progression cannot be bypassed.
- Added battle, elite, Boss, shop, chest, Event, and camp node lifecycles.
- Added Event choice Conditions, deterministic saved outcomes, generic Run
  operations, optional target requests, and optional Reward offers.
- Added atomic Event rollback with retry against the originally saved outcome.
- Added explicit victory, defeat, and abandonment Run end reasons.
- Added progression-safe Reward generation for dynamically filtered Map
  activities without weakening strict standalone generation.
- Added Map unit and integration suites covering route, Event, Reward, shop,
  chest, Encounter, Boss, and transaction boundaries.
- Added final-Terrain passability validation and runtime placement checks for
  player deployments and Enemy spawns.
- Rejected negative Map node minimum and maximum copy counts even when data is
  created outside normal Inspector ranges.

## Architecture Decisions

- `MapState` stores facts only. Reachability, visibility, and current layer are
  derived read-model values.
- Map node completion is controlled by `MapFlowService`, not by Battle,
  Reward, Event content, or UI.
- Lower-level systems may participate in a Map-owned Run transaction, but they
  do not import Map state types or decide final Run progression.
- Generated node content, Event outcome, Battle session, and Reward offer are
  persistent commitments and are never regenerated for display or execution.
- Event effects use existing Run commands and Reward grants rather than a
  second inventory mutation system.
- Player deployment remains runtime state; an Encounter Definition only lists
  legal deployment Cells and authored Enemy spawns.
- Boss victory is committed only after the Boss Reward has completed or was
  proven empty.
- Save serialization remains Phase 9 work; v6 defines the authoritative state
  that persistence must later encode.

## Verification Coverage

The v6 suites cover:

- Definition validation for complete Map and Event graphs
- Reproducible node selection and connection generation
- Forward-only layer connections and initial reachability
- Detached Map read views
- Rejection of unknown and unreachable nodes
- Legal and illegal player deployment
- Blocked player deployment and Enemy spawn Terrain
- Negative Map node copy-count configuration
- Persistent Event outcome selection
- Full Event rollback after a later operation failure
- Retry against the same planned outcome
- Event Reward completion before node completion
- Shop closure and chest collection
- Encounter construction through v5 Battle setup
- Battle and Map session provenance
- Boss Reward completion before Run victory
- Duplicate Battle outcome rejection
- Explicit abandonment reason
- Complete v1 through v5 regression coverage

## Verification Result

- All 569 project assertions passed.
- The Godot 4.7.1 headless editor check completed with exit code zero.
- `git diff --check` passed.
- No `.tscn` file was created or modified.
- `project.godot` remained unchanged.

Run:

```text
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --editor --quit
```

Version 6 is headless domain infrastructure. A production Map scene and UI are
intentionally deferred; no additional editor nodes are required for this
version.

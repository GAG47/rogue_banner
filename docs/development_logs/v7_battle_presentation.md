# v7 Battle Presentation Development Log

## Date

2026-08-02

## Goal

Create a formal, readable, and playable single-Battle interface without
expanding into Map or meta-progression presentation.

## Delivered

- Added a detached Battle presentation model for Cells, Units, Arts, Buffs,
  Intents, phase, side, and round.
- Added a snapshot builder that never gives child views an authoritative
  `BattleState` or `UnitState` reference.
- Added the formal `battle_screen.tscn` scene with Chinese UI copy and English
  Node identifiers.
- Added a pre-Battle deployment flow backed by `BattlePlacementService`.
- Added selected-Unit health, shield, AP, position, Buff, passive, Art,
  cooldown, cost, target, and range presentation.
- Added validated movement highlights and weighted AP costs.
- Added Art range, legal aim, empty-Cell aim, and hovered affected-footprint
  presentation.
- Added Locked, Pattern, and Enhance Intent details, current danger Cells, and
  committed movement paths.
- Added automatic Enemy turn execution through `BattleFlowService`.
- Added typed failure-code feedback and terminal victory/failure presentation.
- Added restart from terminal or active Battle back to deployment.
- Added authored v7 Battlefield and Encounter Resources rather than branching
  shared Battle code for the display fixture.

## Ownership Decisions

- `BattleState` remains authoritative and is private to the formal controller.
- `GridState` remains the only position and occupancy authority.
- UI views consume detached `BattleReadModel` data only.
- Deployment, Move, Use Art, and End Turn operations use existing services.
- Intent display and execution continue to share the saved `IntentPlan` through
  the existing preview and flow services.
- The UI owns only selection, hover, pending target mode, and presentation
  feedback.

## Scope Decisions

Version 7 is intentionally one encounter rather than a complete Run interface.
Map, Reward, shop, Event, Run construction, hero selection, and meta-progression
UI remain deferred. This keeps usability work focused on the already completed
Battle, Art, effect, Buff, and Intent systems.

The authored v7 Arts require one selected target. General multi-selection is
not implemented speculatively; unsupported configuration is reported without
submitting a partial action.

## Validation

Automated coverage verifies:

- Battle read-model detachment and refresh behavior;
- Grid, Unit, Art, Buff, and terminal-state presentation;
- Encounter Definition validation;
- legal and duplicate deployment behavior;
- first-turn Intent visibility;
- selected-Unit movement range;
- empty-Cell Art execution and AP spending;
- self-targeted shielding;
- automatic Enemy turn execution and next-round Intent generation;
- complete restart to deployment.

The full project suite passes 619 assertions. The formal Battle scene loads and
runs headlessly. The Godot editor check exits successfully; restricted sandbox
TCP-listen warnings are environmental and do not indicate project parse errors.

## Manual Entry Point

Open and run:

```text
res://scenes/battle/battle_screen.tscn
```

`project.godot` remains unchanged, so the formal scene is not forced as the
project-wide main scene.

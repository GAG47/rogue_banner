# v3 Art and Effect System Development Log

## Date

2026-07-30

## Goal

Complete the shared Art and Effect rule layer on top of the v2 Battle kernel
without moving rule ownership into Units, UI, or content-specific scripts.

## Delivered

- Added typed attribute and modifier enums and deterministic calculation.
- Added `ModifierDefinition`, `BuffDefinition`, and battle-owned `BuffState`.
- Added Buff application, stacking, replacement, removal, duration, and expiry.
- Added Battle and installation Condition contexts plus all, any, and not
  composition.
- Added reusable event Unit relation Conditions for passive ownership filters.
- Added authoritative Battle target resolution with relation, count, range,
  duplicate, and line-of-sight checks.
- Separated submitted aim, affected Cells, and occupancy-derived hits through
  `ResolvedTargetSet`.
- Allowed spatial Arts to execute against valid empty Cells and added an
  explicit reusable minimum-hit Condition for Arts that require contact.
- Added data-driven affected Cell offsets for fixed area footprints.
- Added effect planning and execution for damage, healing, shield, movement,
  Apply Buff, and Remove Buff.
- Completed `UseArtActionRequest` validation and execution with AP, cooldown,
  Conditions, targets, effects, events, and terminal resolution.
- Added typed Battle events, deterministic event sequence IDs, passive trigger
  processing, trigger limits, and event-chain protection.
- Added Art installation, removal, and data-driven upgrade variants.
- Added defeated Unit cleanup, victory, failure, and `BattleEndedEvent`.
- Added authored debug Arts and Buff content.
- Extended the debug Battle scene with Simplified Chinese Art controls,
  separate range and legal-aim highlights, state display, and event feedback.
- Split debug composition, status presentation, target adaptation, and text
  formatting into focused scripts.

## Architecture Decisions

- Definition Resources remain immutable configuration.
- `UnitState` owns health, AP, shield, Art cooldowns, and Buff instances.
- `GridState` remains the only position and occupancy authority.
- Target preview and execution both call `BattleActionService` validation.
- Spatial target relations filter resolved occupants instead of requiring an
  occupant at the submitted aim Cell.
- Effects consume resolved hits, while use Conditions can explicitly require a
  minimum hit count.
- Predictable validation and effect planning finish before AP and cooldown
  commit.
- Passive events use typed objects and a deterministic first-in, first-out
  processor.
- Modifier duration and stacks belong to Buff state, not modifier Definitions.
- Effects after a lethal effect skip the defeated target and continue action
  resolution.
- Art loadout mutation belongs to a dedicated Run Unit service.
- Debug UI stores only presentation selection, hover, and pending target state.

## Authored Debug Content

- `debug_strike.tres`: adjacent Cell-centered enemy damage scaled by base attack
- `debug_guard.tres`: self shield with cooldown
- `debug_focus.tres`: stacking temporary base-attack Buff
- `debug_reactive_guard.tres`: passive shield response to damage
- `debug_battle_focus.tres`: reusable stacking modifier Buff

These Resources compose generic system types. No shared service contains a
branch for any debug content ID.

## Deferred

- Enemy AI and Intents
- Locked, pattern, and enhance Intent preview
- Relic runtime subscriptions
- Scroll execution
- Forced movement
- Directional or rotated area footprints
- Multi-target selection in the debug UI
- Rewards, map progression, shops, and meta progression
- Formal Battle UI and production content

## Verification

- All 239 project assertions passed.
- The standalone v3 debug Battle scene loaded and ran headlessly.
- The Godot headless editor check completed with exit code zero.
- `git diff --check` passed.
- `project.godot` remained unchanged.

Run the debug scene directly:

```text
res://scenes/debug/battle_debug.tscn
```

The project still has no configured main scene.

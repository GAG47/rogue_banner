# Enemy Intent and Automatic Turn System

## Scope

Version 4 adds persistent enemy action commitments, player-turn preview,
deterministic decision policies, automatic enemy execution, and minimal reusable
enemy phases.

The system proves this loop:

```text
Player turn starts
→ Enemy Intents are generated and stored
→ Preview is derived from the stored plans
→ Player actions alter the Battle
→ Enemy turn executes the same stored plans
→ Normal disruption fizzles without replanning
→ The next player turn receives a new Intent batch
```

Rewards, maps, shops, relic runtime subscriptions, Scroll execution, formal
Battle UI, behavior trees, and a general Boss scripting language remain outside
v4.

## Dependency Direction

```text
EnemyDefinition
├── UnitDefinition
├── IntentDefinition
├── EnemyDecisionPolicyDefinition
└── EnemyPhaseDefinition

BattleFlowService
├── BattleActionService
├── IntentGenerationService
├── EnemyTurnService
│   └── IntentExecutor
└── BattleTransaction

IntentPreviewService
├── stored IntentPlan
├── BattleTargetResolver
└── read-only Battle State
```

Intent services read Battle, Grid, Unit, Art, and Buff state. They never apply
damage, movement costs, cooldowns, or effects directly.

## Static Definitions

`IntentDefinition` configures:

- Display identity and optional icon
- Locked, pattern, or enhance presentation kind
- Referenced active Art
- Reusable target-selection rule
- Optional movement rule
- Fixed or target-derived cardinal direction
- Art-only, move-then-Art, or Art-then-move sequence

It does not contain damage, shielding, Buffs, hit geometry, range, line of
sight, AP cost, or cooldown. Those remain authoritative in the referenced
`ArtDefinition`.

Implemented target rules are:

- Self
- Nearest opposing Unit
- Cell occupied by the nearest opposing Unit at generation time
- Lowest-health allied Unit
- Nearest scene object

Implemented decision policies are:

- `FixedCycleDecisionDefinition`
- `PriorityDecisionDefinition`

Priority candidates contain reusable Conditions, fixed priority, and positive
weight. Only candidates at the highest passing priority participate in weighted
selection.

`EnemyPhaseDefinition` contains a stable phase ID, priority, entry Conditions,
and one decision policy. Phase entry Conditions use
`EnemyDecisionContext`.

## Runtime Ownership

`BattleState` owns `EnemyState` by Battle-local Unit ID. `EnemyState` contains:

- The immutable `EnemyDefinition` reference
- Current phase ID
- Fixed-cycle position
- Current `IntentPlan`

It does not duplicate health, AP, cooldown, Buffs, Arts, side, or position.
Those values remain in `UnitState` and `GridState`.

Removing a Unit also removes its Enemy State and current Intent in the same
Battle transaction.

## Intent Plan

`IntentPlan` is generated once and persists through the player turn. It stores:

- Acting enemy Unit ID
- Intent Definition
- Installed Art slot
- Generation round and phase ID
- Locked typed target selection when applicable
- Cardinal pattern direction
- Optional fixed movement destination

The plan does not retain v3 `ActionExecutionPlan`, resolved hits, effect plans,
or cached absolute pattern Cells. Those values would become stale during the
player turn.

Movement locks its destination, not a route. Execution may find a current valid
path to that same destination, but it never selects a replacement destination.

## Generation

Generation occurs only after player-turn start events, Buff progress, passive
chains, defeat cleanup, and terminal resolution have succeeded.

The complete enemy batch is generated in an isolated `BattleTransaction`.
Invalid configuration or an internal generation failure leaves the previous
authoritative Battle unchanged.

Enemies are processed in Battle-local Unit ID order. A generated plan:

1. Selects the highest-priority matching phase.
2. Selects an Intent through the phase or default policy.
3. Resolves the referenced installed Art slot.
4. Resolves and locks the target identity or Cell when required.
5. Resolves a fixed movement destination.
6. Stores pattern direction without storing absolute danger Cells.

Planning accounts for the next enemy turn's AP refresh and cooldown decrement.
Player actions can still make the published plan illegal before execution.

## Deterministic Selection

`BattleState` owns `battle_seed`. Weighted priority selection derives a local
seed from:

- Battle seed
- Round number
- Enemy Unit ID
- Current cycle position
- Current phase ID

Preview never consumes randomness. Equal seed and equal Battle state therefore
produce the same selected Intent.

## Locked, Pattern, and Enhance Semantics

Locked Unit plans retain Unit identity. Movement changes its execution-time
position, while defeat or removal makes the Art fizzle.

Locked Cell plans retain coordinates. The Art still executes against a valid
empty Cell and can produce non-Unit effects.

Locked object plans retain scene-object identity. Removal makes the Art fizzle
without selecting another object.

Pattern plans retain direction. `TargetSelection` carries optional cardinal
orientation, and `BattleTargetResolver` rotates the Art's authored offsets from
the canonical right-facing footprint. The pattern anchor is rebuilt from the
enemy's execution position.

Enhance plans lock the selected allied Unit or self through the same typed target
selection used by active Arts.

## Preview

`IntentPreviewService` derives a read-only `IntentPreview` from the current
Battle and stored plan.

It may project the published move destination when that destination is
currently reachable, then resolves Art targeting through
`BattleTargetResolver`. If movement becomes invalid, preview falls back to the
enemy's current Cell. Rebuilding preview after player movement or forced
movement updates pattern danger Cells without changing the plan.

Preview contains presentation facts only. UI cannot modify the plan.

## Execution and Failure Semantics

`IntentExecutor` adapts each stored step to:

- `MoveActionRequest`
- `UseArtActionRequest`

The existing Battle action pipeline remains responsible for AP, cooldown,
targeting, Conditions, effects, passive events, cleanup, and terminal phases.

Expected battlefield disruption produces a `FIZZLED` step:

- Missing or defeated locked target
- Occupied or unreachable move destination
- Insufficient AP
- Art cooldown
- Invalid relation
- Range or line-of-sight failure
- Failed use Condition

A fizzled move does not cancel a later Art step. A fizzled enemy does not stop
later enemies.

Invalid Battle state, effect execution failure, trigger overflow, state-copy
failure, or invalid Condition context is an internal failure. It aborts the
automatic flow instead of being hidden as a normal miss.

## Automatic Enemy Turn

`BattleFlowService.end_player_turn` executes one outer transaction:

1. Submit player End Turn.
2. Process enemy-turn start refresh and passive events.
3. Snapshot enemy IDs in ascending order.
4. Execute each stored Intent.
5. Stop immediately on victory or failure.
6. Submit enemy End Turn.
7. Process player-turn start refresh and passive events.
8. Generate the next Intent batch.
9. Commit the complete flow.

Normal fizzles commit. An internal failure discards the complete automatic flow,
including earlier enemy actions and the player End Turn transition.

## Boss Phases

Phases are evaluated only when a new Intent batch is generated. Crossing a
threshold during the player turn never replaces the plan already shown to the
player. The Boss executes that plan, then the next player-turn generation may
select a new phase.

Changing phase resets the fixed-cycle position. There is no content-specific
Boss branch in Battle or Intent services.

## Direction and Forced Movement

`GridDirection` supplies typed cardinal vectors and canonical footprint
rotation.

`ForcedMovementEffectDefinition` is a generic v4 Effect supporting:

- Movement away from the actor
- Movement toward the actor
- Fixed cardinal movement
- Configured distance
- Early stop at blocking Terrain, bounds, or occupancy

It publishes the same typed `UnitMovedEvent` used by other movement. This allows
player Arts to alter pattern preview without adding Intent-specific movement
rules.

## Debug Visualization

The existing `battle_debug.tscn` node structure is reused. Version 4 adds:

- Red live danger Cells
- Orange planned movement paths
- Locked, pattern, and enhance badges on enemies
- Chinese Intent summaries in the status panel
- Automatic enemy execution from the existing End Turn button

The authored debug encounter contains an archer, heavy Unit, and priest. It also
adds a player shove Art for changing the heavy Unit's pattern origin.

## Verification Boundary

Automated tests cover:

- Enemy and Intent Definition validation
- First-player-turn Intent generation
- Locked Unit, Cell, and scene-object commitments
- No retargeting after movement, removal, or defeat
- Empty locked-Cell execution
- Pattern rotation and live preview after forced movement
- Fixed movement destination disruption
- Art execution after a fizzled move
- Normal fizzle continuation
- Immediate stop on terminal Battle resolution
- Deterministic weighted priority selection
- Boss phase changes at the next generation boundary
- Enemy State cleanup with Unit removal
- Automatic return to the next player turn
- Chinese debug preview and three-enemy authored content

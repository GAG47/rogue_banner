# Art and Effect System

## Scope

Version 3 implements the shared rule layer required for active Arts, passive
Arts, Buffs, typed Battle events, and terminal Battle resolution. It extends the
v2 Battle action pipeline rather than creating a second execution path.

Implemented capabilities:

- Art installation, removal, and upgrade variants
- Battle target validation for Units, Cells, terrain objects, and Battle
- Aim, affected Cell, and hit resolution as separate typed data
- Target relation, range, duplicate, line-of-sight, and affected-offset validation
- Composed use and trigger Conditions
- Optional minimum-hit Conditions for content that requires a successful hit
- Damage, healing, shield, movement, Apply Buff, and Remove Buff effects
- Deterministic attribute modifiers and Buff stacking
- AP spending and cooldown commitment
- Typed event processing and passive triggers
- Defeated Unit cleanup, victory, and failure

Enemy decisions, Intents, relic runtime subscriptions, Scroll execution,
forced movement, rotated or directional area footprints, multi-target debug
input, rewards, and map progression remain outside this version.

## Dependency Direction

```text
ArtDefinition and BuffDefinition
├── TargetingDefinition
├── ConditionDefinition
├── EffectDefinition
├── TriggerDefinition
└── ModifierDefinition

UseArtActionRequest
→ BattleActionService
  ├── BattleTargetResolver
  ├── ConditionEvaluator
  ├── BattleEffectPlanner
  ├── BattleEffectExecutor
  ├── BattleEventProcessor
  └── BattleResolutionService
```

Definitions contain immutable configuration. `UnitState`, `ArtState`, and
`BuffState` contain mutable Battle values. Services own rule execution and do
not depend on UI or scene nodes.

## Targeting

`TargetSelection` stores the submitted aim as typed Unit IDs, Cell coordinates,
terrain object IDs, or a Battle target. `BattleTargetResolver` validates that
input against the Art's `TargetingDefinition` and produces a
`ResolvedTargetSet`.

`ResolvedTargetSet` separates:

- The original typed selection
- Aim Cells used for range and line-of-sight checks
- Affected Cells expanded from configured relative offsets
- Matching Unit and scene-object hits discovered from Grid occupancy

For Cell targeting, relation filters resolved occupants rather than the selected
Cell. A valid in-range empty Cell is therefore a legal aim and produces zero
hits. AP, cooldown, actor effects, and `ArtUsedEvent` still commit normally.
Content that must hit something adds `HitRequirementConditionDefinition`
instead of changing the generic targeting rule.

Validation includes:

- Minimum and maximum target count
- One target kind per selection
- Duplicate rejection
- Existing and living Unit targets
- Self, ally, enemy, neutral, or any relation
- Manhattan range from the actor's authoritative Grid position
- Terrain line of sight when required
- Non-empty, duplicate-free affected Cell offsets

The Grid remains the only source for actor and target positions. The debug UI
shows geometric range through the resolver and derives legal aim highlights by
submitting candidate `UseArtActionRequest` instances to the same action
validator used by execution.

Definition validation rejects effect contexts that cannot execute: active Arts
cannot require event targets, Move Arts require exactly one Cell and one Move
effect, and trigger effects cannot depend on a spatial hit result or selected
Cell.

## Conditions

`ConditionEvaluator` evaluates typed Conditions without mutation.

Implemented composition:

- `AllConditionDefinition`
- `AnyConditionDefinition`
- `NotConditionDefinition`
- `EventUnitRelationConditionDefinition`
- `HitRequirementConditionDefinition`

Battle use Conditions receive `BattleConditionContext`. Installation Conditions
receive `ArtInstallConditionContext`. Trigger Conditions receive the triggering
`BattleEvent` through the Battle context.

Event Unit relation Conditions compare a passive owner with the typed event
source or target through the same self, ally, enemy, or any evaluator used by
Battle targeting.

Hit requirements inspect the already resolved hit set and can require a minimum
number of Units, scene objects, or either. They do not repeat occupancy or
relation logic.

Concrete factual Conditions are added only when reusable content requirements
need them. Content-specific checks do not belong in the evaluator.

## Attributes and Modifiers

`AttributeCalculator` calculates maximum health, base attack, and maximum AP
from the Unit Definition plus active Buff modifiers.

Modifier order is deterministic:

1. Start from the Definition base value.
2. Add all flat values.
3. Sum additive percentages and apply the combined percentage once.
4. Apply multiplicative modifiers in priority and source order.
5. Apply override and clamp operations in priority and source order.
6. Round to an integer and clamp the result to zero or greater.

Modifiers are ordered first by `priority`, then by stable Buff and modifier
source order. A modifier does not own duration or stacks; its containing
`BuffState` supplies both.

## Buffs

`BuffDefinition` configures:

- Stable content identity
- Duration in owning-side turn starts
- Stacking rule
- Maximum stacks
- Attribute modifiers
- Passive triggers

`BuffState` owns:

- Battle-local Buff instance ID
- Definition reference
- Source Unit ID
- Current stacks
- Remaining duration

Supported stacking rules are refresh duration, add stacks, and replace.
`BuffService` is the only service that adds, removes, stacks, refreshes, or
expires Buff state.

At the start of a side's turn, its Units advance Buff duration before AP and
cooldown refresh. Expiry publishes `BuffRemovedEvent`, and AP refresh uses the
resulting calculated maximum AP.

## Effects

Effect Resources configure generic operations. `BattleEffectPlanner` resolves
targets and amounts before the action commits. `BattleEffectExecutor` applies
the resulting plans in authored order.

Implemented effects:

| Effect | Result |
| --- | --- |
| `DamageEffectDefinition` | Shield absorbs first, then health is reduced |
| `HealingEffectDefinition` | Health is restored up to calculated maximum health |
| `ShieldEffectDefinition` | Current shield is increased |
| `MoveEffectDefinition` | Actor follows a validated Grid path without duplicating position state |
| `ApplyBuffEffectDefinition` | Buff stacking is delegated to `BuffService` |
| `RemoveBuffEffectDefinition` | Matching Buff state is removed |

Damage, healing, and shield amounts combine a flat amount with an optional
scaled actor attribute. `EffectTargetSource` selects the actor, hit Units, the
event source Unit, or the event target Unit. A hit-Unit effect with zero hits is
a valid empty effect plan, allowing the rest of the Art to resolve.

If an earlier ordered effect defeats a target, later effects targeting that
defeated Unit are skipped. Defeat cleanup occurs after event processing so
typed defeat events remain observable during the action.

## Art Action Pipeline

Active Art execution follows this order:

1. Validate Battle phase, active side, actor, and placement.
2. Resolve the installed Art slot.
3. Reject passive Arts, cooldown, or insufficient AP.
4. Validate the submitted aim and resolve affected Cells and hits.
5. Evaluate use Conditions.
6. Build all effect plans.
7. Commit AP and cooldown.
8. Execute ordered effects.
9. Publish `ArtUsedEvent` after effect events.
10. Process passive triggers.
11. Remove defeated Units and resolve victory or failure.
12. Return typed events and removed Unit IDs.

All predictable content and targeting failures occur before AP or cooldown
mutation. Execution plans are short-lived commit data and never become another
runtime state authority.

## Passive Events

`BattleEvent` is the typed event base. `BattleState` assigns monotonic sequence
IDs as events are processed.

Implemented events:

- `UnitMovedEvent`
- `DamageAppliedEvent`
- `HealingAppliedEvent`
- `ShieldChangedEvent`
- `BuffAppliedEvent`
- `BuffRemovedEvent`
- `UnitDefeatedEvent`
- `ArtUsedEvent`
- `TurnStartedEvent`
- `TurnEndedEvent`
- `BattleEndedEvent`

`BattleEventProcessor` uses a first-in, first-out queue. For each event it scans
living Units in Battle ID order, then installed passive Arts by slot order, then
Buffs by runtime order. Each trigger has a per-action activation limit, and an
event chain is capped at 128 events.

Passive trigger effects publish new events back into the same queue. There is
no string event bus and no UI callback inside rule execution.

`BattleEndedEvent` is a terminal output after passive processing and cleanup. It
is not fed back into Battle passive effects.

## Art Loadouts and Upgrades

`ArtLoadoutService` operates on `RunUnitState`, where between-Battle loadout
choices belong.

It supports:

- Slot range and occupancy validation
- Required typed tags
- Installation Conditions
- Installation and removal
- Replacement with `upgraded_variant`

Upgrade state is represented by the installed variant Definition. No mutable
upgrade flag is stored in a shared Resource.

## Battle Resolution

After each committed action, `BattleResolutionService`:

- Counts living player and enemy Units
- Removes defeated Units through `BattlePlacementService`
- Clears their authoritative Grid occupancy
- Selects failure when no player Units remain
- Otherwise selects victory when no enemy Units remain
- Publishes `BattleEndedEvent` for a terminal phase

Battle resolution does not grant rewards or mutate Run state.

## Debug Visualization

`battle_debug.tscn` remains a presentation-only executable probe. Version 3
adds Simplified Chinese controls for:

- Installed Art selection
- AP cost, cooldown, and passive status
- Separate geometric range and legal aim highlighting
- Art action submission
- Health, shield, Buff count, and cooldown updates
- Typed effect and terminal result feedback

The debug scene supports one selected target at a time. This is a debug input
limitation, not a targeting-system limitation.

## Verification Boundary

Automated tests cover:

- Definition, modifier, and affected-offset validation
- Target relations, duplicate selection, range, line of sight, and hit expansion
- Successful empty-Cell attacks and explicit minimum-hit rejection
- Condition composition and atomic condition failure
- Buff stacking, duration, removal, and attribute calculation
- Typed Buff expiry events during turn transitions
- Art installation, removal, tag checks, and upgrades
- AP spending, cooldown start, and cooldown progress
- Damage, shield absorption, healing, movement, Apply Buff, and Remove Buff
- Typed passive events and deterministic sequence IDs
- Ordered effects after lethal damage
- Defeated Unit cleanup and terminal Battle phases
- Debug scene range preview, empty-Cell aiming, and execution through Battle actions

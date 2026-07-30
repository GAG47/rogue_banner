# Core Data Model

## Scope

Core data layer v1 defines editor-authored static configuration, mutable Battle
and Run state, rule contracts, and configuration validation. It contains no UI,
scene, map, reward, shop, enemy decision, movement, damage, or concrete content
behavior.

Battle kernel v2 extends this model with authoritative Grid occupancy,
Battle-local Unit identity, placement, pathfinding, actions, and turn state. The
final v2 contracts are detailed in `docs/battle_kernel.md`.

Art and Effect system v3 extends it with modifiers, Buff state, Battle target
resolution, concrete generic effects, typed Battle events, passive triggers,
Art loadouts, and terminal Battle resolution. The final v3 contracts are
detailed in `docs/art_effect_system.md`.

All Definition types are Godot `Resource` classes registered with `class_name`.
All runtime State types are `RefCounted` classes created uniquely for a Run or
Battle.

## Dependency Direction

```text
GameEnums and validation value types
→ DefinitionResource and TagDefinition
→ Condition, Effect, Targeting, and Trigger contracts
→ Art, Unit, Relic, Scroll, Terrain, Enemy, and Hero definitions
→ ArtState, UnitState, RunUnitState, ScrollStackState
→ BattleState and RunState
→ DefinitionValidator
```

Definitions never depend on runtime State. Runtime State may hold read-only
references to Definitions. Rule definitions never depend on scenes, UI, map, or
reward systems.

## Identity

Every top-level Definition inherits:

| Field | Type | Rule |
| --- | --- | --- |
| `content_id` | `StringName` | Required stable catalog and persistence identity |
| `display_name` | `String` | Presentation text and never an identity |

Raw content IDs are restricted to authoring validation, future catalog lookup,
and persistence boundaries. Domain references use typed Definition Resources.

Inline configuration Resources such as `TagWeight`, `TargetingDefinition`,
conditions, effects, and triggers do not require top-level content IDs.

## Static Definitions

### TagDefinition

`TagDefinition` provides typed tag identity. It contains no mutable gameplay
state and no direct behavior.

### HeroDefinition

| Field | Type | Responsibility |
| --- | --- | --- |
| `starting_units` | `Array[UnitDefinition]` | Unit configurations used to initialize Run team state |
| `starting_relics` | `Array[RelicDefinition]` | Relics copied into initial Run ownership |
| `exclusive_relics` | `Array[RelicDefinition]` | Hero-specific Relic pool entries |
| `preferred_tags` | `Array[TagWeight]` | Typed Unit tag weighting configuration |
| `art_pool` | `Array[ArtDefinition]` | Hero-specific Art pool entries |

`TagWeight` contains a typed `TagDefinition` reference and a positive floating
point weight.

### UnitDefinition

| Field | Type | Rule |
| --- | --- | --- |
| `max_health` | `int` | Greater than zero |
| `base_attack` | `int` | Zero or greater |
| `max_ap` | `int` | Greater than zero |
| `slot_count` | `int` | Zero or greater |
| `tags` | `Array[TagDefinition]` | Non-null and unique typed tags |
| `default_arts` | `Array[ArtDefinition]` | Non-null initial Arts that fit available slots and tag requirements |

Current health, AP, position, cooldowns, and defeat state never belong to this
Resource.

### ArtDefinition

| Field | Type | Rule |
| --- | --- | --- |
| `rarity` | `GameEnums.ArtRarity` | Common, uncommon, or rare |
| `category` | `GameEnums.ArtCategory` | Attack, skill, or passive |
| `ap_cost` | `int` | Zero or greater |
| `cooldown` | `int` | Zero or greater |
| `targeting` | `TargetingDefinition` | Required for active Arts |
| `required_tags` | `Array[TagDefinition]` | Typed installation tag requirements |
| `installation_conditions` | `Array[ConditionDefinition]` | Additional typed installation constraints |
| `use_conditions` | `Array[ConditionDefinition]` | Typed use-time constraints |
| `effects` | `Array[EffectDefinition]` | Ordered effects required by active Arts |
| `passive_triggers` | `Array[TriggerDefinition]` | Trigger configuration required by passive Arts |
| `upgraded_variant` | `ArtDefinition` | Optional typed upgraded variant |

Upgrade variants are separate Art Definitions. Upgrade chains must use distinct
content IDs and cannot contain cycles. Upgrade state is therefore expressed by
the selected variant rather than scattered flags.

### RelicDefinition

`passive_triggers` contains typed trigger configurations. A Relic Definition
requires at least one trigger, but the current layer does not implement event
binding or trigger execution.

### ScrollDefinition

| Field | Type | Rule |
| --- | --- | --- |
| `max_stack_size` | `int` | Greater than zero |
| `targeting` | `TargetingDefinition` | Required |
| `use_conditions` | `Array[ConditionDefinition]` | Optional typed use constraints |
| `effects` | `Array[EffectDefinition]` | At least one ordered effect |

Quantity belongs to `ScrollStackState`, never to the shared Scroll Definition.

### EnemyDefinition

| Field | Type | Responsibility |
| --- | --- | --- |
| `unit_definition` | `UnitDefinition` | Required static combat attributes and Arts |
| `rank` | `GameEnums.EnemyRank` | Standard, elite, or Boss classification |

Decision policies, Intent plans, and phase behavior are deliberately absent from
v1 and belong to the Enemy and Intent phase.

### TerrainDefinition

| Field | Type | Rule |
| --- | --- | --- |
| `blocks_movement` | `bool` | Static traversal rule |
| `blocks_line_of_sight` | `bool` | Static visibility rule |
| `movement_cost` | `int` | At least one |
| `tags` | `Array[TagDefinition]` | Non-null and unique typed tags |

Occupancy and runtime interaction state do not belong to this Resource.

### ModifierDefinition

| Field | Type | Rule |
| --- | --- | --- |
| `attribute` | `GameEnums.AttributeType` | Maximum health, base attack, or maximum AP |
| `operation` | `GameEnums.ModifierOperation` | Flat, additive percentage, multiplicative, override, or clamp |
| `value` | `float` | Finite operation value |
| `priority` | `int` | Deterministic ordering key |

Duration, source, and stack count do not belong to the modifier Definition.

### BuffDefinition

| Field | Type | Rule |
| --- | --- | --- |
| `duration_turns` | `int` | Greater than zero |
| `stacking_rule` | `GameEnums.BuffStackingRule` | Refresh duration, add stacks, or replace |
| `maximum_stacks` | `int` | At least one |
| `modifiers` | `Array[ModifierDefinition]` | Non-null validated modifiers |
| `passive_triggers` | `Array[TriggerDefinition]` | Optional typed Battle triggers |

Current duration, stacks, source Unit, and Battle identity belong to
`BuffState`.

## Runtime State

### ArtState

`ArtState` owns an immutable `ArtDefinition` reference and mutable
`current_cooldown`. Creating Art state never changes the Art Definition.

### UnitState

`UnitState` is Battle-owned and contains:

- Runtime `instance_id`
- Optional source Run Unit ID
- `UnitDefinition` reference
- `GameEnums.BattleSide`
- Current health, AP, and shield
- Unique `ArtState` instances
- Unique `BuffState` instances

`UnitState.create` initializes current health and AP from a fully validated Unit
Definition and creates fresh Art State through the same default-loadout rules
used by Run Units. Construction fails when a default Art is invalid or cannot
be installed. It never mutates the source Definition.

Unit position is not stored in Unit State. It is queried from the authoritative
Grid occupancy table.

### BuffState

`BuffState` is Battle-owned and contains a Battle-local instance ID, immutable
`BuffDefinition` reference, source Unit ID, current stacks, and remaining
duration. Stacks and duration never belong to the shared Buff Definition.

### RunUnitState

`RunUnitState` is Run-owned and intentionally separate from `UnitState`. It
contains:

- Runtime `instance_id`
- `UnitDefinition` reference
- Between-Battle current health
- A copied array of installed `ArtDefinition` references

It does not contain Battle AP, cooldowns, side, or grid position.
`UnitState.create_from_run_unit` creates independent Battle state and retains
the source Run Unit ID for a future explicit Battle outcome. Both creation paths
reject an invalid loadout rather than silently importing it into Battle.

### ScrollStackState

`ScrollStackState` owns a `ScrollDefinition` reference and mutable quantity.
Quantity limits are enforced by the future Run command layer, not by direct
Definition mutation.

### BattleState

Battle State v2 contains:

- Grid State
- Battle phase
- Active side
- Round number
- Battle-owned Unit State indexed by Battle-local ID
- A monotonic Battle-local Unit ID allocator
- A monotonic Battle event sequence allocator

Grid State owns all positions and occupancy. Battle State owns Unit identity and
combat values. Action and turn services mutate these owners only through their
explicit APIs.

`BattleTransaction` creates a short-lived deep working copy of Grid, Unit, Art,
Buff, turn, and allocator state. Battle start and actions execute completely on
that copy. A successful result is copied back into the existing authoritative
objects; any internal failure discards it. The working copy is never exposed as
a second long-lived state source.

### RunState

Run State v1 contains:

- `HeroDefinition` reference
- Run seed
- Gold
- Run-owned Unit State
- Owned Relic Definition references
- Scroll Stack State

`RunState.create` validates the Hero and every starting Unit loadout, then copies
the starting configuration into new mutable arrays and new `RunUnitState`
objects. It fails instead of returning a partially initialized Run. Mutating
Run inventory or Unit state cannot change the Hero, Unit, Art, or Relic
Definitions.

## Rule Contracts

### Conditions

`ConditionDefinition` is an abstract Resource with:

- Configuration validation
- A side-effect-free `evaluate` contract
- Typed `ConditionContext`
- Typed `ConditionResult` and `ConditionStatus`

Version 3 adds `BattleConditionContext`, `ArtInstallConditionContext`, a
stateless `ConditionEvaluator`, reusable all, any, and not composition, and an
event Unit relation Condition for passive ownership filters.
`EventSideRelationConditionDefinition` expresses same-side and opposing-side
turn events relative to the passive owner.
`HitRequirementConditionDefinition` can explicitly require a minimum number of
resolved Unit, scene-object, or combined hits. Additional factual Conditions
are added only when required by reusable content rules.

Conditions validate their supported context kind. Trigger Conditions also
validate required event payload capabilities through `BattleEventSchema`, so
configuration cannot assume Unit data on a turn-only event.

### Effects

`EffectDefinition` is an abstract static configuration Resource.
`EffectExecutor` is an abstract execution service that receives a typed
`EffectContext` and returns a typed `EffectResult`.

This separation prevents authored Effect Resources from owning mutable Battle
state or searching the scene tree. Version 3 adds planning and execution for
damage, healing, shield, movement, Apply Buff, and Remove Buff effects.

Effects resolve the actor, hit Units, or event Units through
`EffectTargetSource` and publish typed Battle events. Scaled effects combine a
flat amount with an optional calculated actor attribute.

### Targeting

`TargetingDefinition` contains:

- Target kind and relation
- Minimum and maximum range
- Minimum and maximum selected targets
- Line-of-sight requirement
- Relative affected Cell offsets

`BattleTargetResolver` receives a Battle context and submitted typed selection.
It validates target count and kind, duplicates, direct-target relation,
Manhattan range, and line of sight against authoritative Grid positions.
`TargetSelection` stores Unit instance IDs, Cell coordinates, terrain object
instance IDs, or a Battle target without untyped dictionaries.

The resolver then creates a `ResolvedTargetSet` containing the submitted
selection, aim Cells, expanded affected Cells, matching Unit hits, and matching
scene-object hits. For spatial Cell targeting, relation filters occupants in
affected Cells rather than rejecting empty aim Cells. Zero hits are valid unless
the Art declares a hit requirement Condition.

### Triggers

`TriggerDefinition` binds a typed `BattleEventKind` to Conditions, ordered
Effects, and a per-action activation limit. `BattleEventProcessor` executes
passive Art and Buff triggers through a deterministic first-in, first-out event
queue. Each event snapshots its candidate sources. Trigger counters use owner
Unit ID, stable Art slot or Buff instance ID, and trigger index, so Buff
mutation cannot change trigger identity. Relic runtime binding remains
deferred.

## Validation

`DefinitionValidator` is a stateless service and the single owner of top-level
Definition schema validation. It checks:

- Required content IDs
- Numeric bounds
- Null typed references
- Duplicate tags and pool references where duplicates are invalid
- Targeting bounds
- Required active effects and passive triggers
- Unit default Art slot capacity
- Complete default Art Definition, tag, and installation-condition validity
- Nested Condition, Effect, Targeting, and Trigger configuration
- Condition-context and event-payload compatibility
- Modifier and Buff configuration
- Complete Art upgrade variants, cycles, and repeated upgrade content IDs

Expected validation failures are returned as
`DefinitionValidationResult` containing typed `DefinitionValidationIssue`
objects and `DefinitionValidationCode` enum values. Validation does not print,
mutate content, or depend on UI.

Cross-file content ID uniqueness is deferred to the future `ContentCatalog`.
This validator checks one Definition graph at a time.

## Test Boundary

Tests use fixture Conditions only under `tests/fixtures`. Authored debug Arts
and Buffs use the same generic production definitions and services.

The headless test runner verifies:

- Valid instances of every v1 top-level Definition
- Invalid IDs, values, references, tags, targeting, and upgrades
- Definition and State mutation isolation
- Run and Battle Unit state separation
- Typed rule result and target value objects
- Godot Resource save and load round trips
- Grid topology, Terrain, occupancy, and pathfinding
- Run-to-Battle Unit creation and Battle-local ID allocation
- Movement actions, AP costs, atomic failures, and turn transitions
- Rollback after internal action, passive, turn, and Battle-start failures
- Targeting, line of sight, Conditions, modifiers, and Buff lifecycle
- Default Art loadouts, fully validated upgrades, AP, cooldowns, and ordered effects
- Damage, healing, shield, movement, Apply Buff, and Remove Buff
- Typed passive events, event capabilities, stable trigger identity, initial
  turn-start triggers, defeat cleanup, victory, and failure

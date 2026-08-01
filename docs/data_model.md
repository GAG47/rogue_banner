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

Enemy Intent system v4 extends it with Enemy decision configuration,
Battle-owned Enemy state, persistent Intent plans, deterministic generation,
read-only preview, and automatic enemy turns. The final v4 contracts are
detailed in `docs/enemy_intent_system.md`.

Run and Reward system v5 extends it with runtime Art and Relic identity,
transactional Run commands, Battle setup and outcome transfer, Scroll actions,
Relic Battle triggers, deterministic Reward offers, shops, recruitment, and Run
flow phases. The final v5 contracts are detailed in
`docs/run_reward_system.md`.

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

`maximum_copies` sets the Run ownership limit. `passive_triggers` contains typed
trigger configurations. Battle copies every owned runtime Relic instance and
registers each as a stable player-side event source. Relic triggers cannot use
conditions, scaling, movement, or effect targets that require a Unit owner.

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
| `available_intents` | `Array[IntentDefinition]` | Complete authored Intent set available to this enemy |
| `default_decision` | `EnemyDecisionPolicyDefinition` | Required policy outside a matched phase |
| `phases` | `Array[EnemyPhaseDefinition]` | Optional prioritized Boss phase configuration |

An Intent Definition references an installed active Art and configures target
commitment, direction, movement, and step order. It never duplicates Art costs,
target geometry, or Effects. Current phase, cycle progress, and generated plans
belong to `EnemyState`, not this shared Resource.

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
`BuffDefinition` reference, typed `BattleSource`, current stacks, and remaining
duration. Its optional source Unit ID is derived from that source. Stacks and
duration never belong to the shared Buff Definition.

### RunUnitState

`RunUnitState` is Run-owned and intentionally separate from `UnitState`. It
contains:

- Runtime `instance_id`
- `UnitDefinition` reference
- Between-Battle current health
- An array of installed `RunArtState.instance_id` values aligned to Unit slots

It does not contain Battle AP, cooldowns, side, or grid position.
`BattleSetupService` resolves the instance IDs to Definition references,
validates the complete loadout, and creates independent Battle state. The
Battle participant map retains the source Run Unit ID even if its Battle Unit is
later removed.

### RunArtState and RunRelicState

`RunArtState` owns a unique runtime Art instance ID and its current immutable
Art Definition variant. Two equal Art Definitions therefore remain distinct
inventory items, and upgrading one instance does not upgrade another.

`RunRelicState` owns a unique runtime Relic instance ID and its shared immutable
Relic Definition. Duplicate limits are enforced by `RunCommandService`.

### ScrollStackState

`ScrollStackState` owns a unique stack ID, a `ScrollDefinition` reference, and
mutable quantity. `RunCommandService` validates the complete quantity against
existing stack room and total slot capacity before changing any stack.

### BattleState

Battle State v2 contains:

- Grid State
- Battle seed
- Battle phase
- Active side
- Round number
- Battle-owned Unit State indexed by Battle-local ID
- Battle-owned Enemy State indexed by its Unit Battle ID
- A monotonic Battle-local Unit ID allocator
- A monotonic Battle event sequence allocator

Grid State owns all positions and occupancy. Battle State owns Unit identity and
combat values. Action and turn services mutate these owners only through their
explicit APIs.

`BattleTransaction` creates a short-lived deep working copy of Grid, Unit,
Enemy, Intent, Art, Buff, turn, seed, and allocator state. Battle start,
actions, and complete automatic enemy-turn flows execute on that copy. A
successful result is copied back into the existing authoritative objects; any
internal failure discards it. The working copy is never exposed as a second
long-lived state source.

### EnemyState and IntentPlan

`EnemyState` is Battle-owned and shares identity with its associated enemy
`UnitState`. It stores only:

- Current phase ID
- Fixed-cycle progress
- Current published `IntentPlan`

`IntentPlan` stores the commitments previewed to the player: actor, generation
round, Intent and Art references, installed slot, locked target selection,
fixed movement destination, cardinal direction, and action order. It does not
store Unit health, occupancy, resolved hits, or a v3 `ActionExecutionPlan`.

Locked plans retain Unit, Cell, or scene-object identity and never retarget.
Pattern plans retain direction and resolve geometry from the actor's current
position. Preview is derived from the stored plan and current authoritative
Battle state; it cannot mutate the plan.

### RunState

Run State v5 contains:

- `HeroDefinition` reference
- Run seed
- Team and Scroll capacities
- Private Gold and Run phase
- Run-owned Unit, Art, Relic, and Scroll State indexed by runtime ID
- Monotonic runtime, Battle session, and Reward offer ID allocators
- Reward generation count
- Current Battle session mapping
- Current saved Reward offer
- Optimistic state version

`RunState.create_from_setup` builds default Arts as ordinary owned
`RunArtState` instances and installs their IDs. `RunTransaction` deep-copies all
mutable Run state, records the source version, and rejects a stale commit.
External systems submit `RunCommand` objects or use `RunFlowService`; they do
not update inventories or Gold directly. Public inventory queries return
detached Unit, Art, Relic, and Scroll snapshots. Only Run-domain transaction
code receives mutable inventory objects, so a consumer cannot alter authority
or bypass `state_version` by modifying a query result. Snapshot consumers must
query again after the Run version changes rather than treating object identity
as stable.

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

Version 4 adds generic forced movement. Direction may be fixed or relative to
the actor and target, and movement is committed one valid Cell at a time
through the same Grid movement service used by other Battle movement.

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
- Complete Enemy Unit, Intent, decision policy, and phase graphs
- Intent target-kind, sequence, movement, Art-installation, and direction compatibility
- Enemy-decision Condition context compatibility

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
- Locked Unit, Cell, and scene-object Intent commitments
- Pattern preview changes after forced movement
- Fixed movement destination disruption and continued Art execution
- Fixed-cycle, conditional priority, deterministic seed, and Boss phase generation
- Stable enemy execution order, normal fizzles, terminal stop, and automatic-flow rollback

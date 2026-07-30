# Core Data Model

## Scope

Core data layer v1 defines editor-authored static configuration, mutable Battle
and Run state, rule contracts, and configuration validation. It contains no UI,
scene, map, reward, shop, enemy decision, movement, damage, or concrete content
behavior.

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

## Runtime State

### ArtState

`ArtState` owns an immutable `ArtDefinition` reference and mutable
`current_cooldown`. Creating Art state never changes the Art Definition.

### UnitState

`UnitState` is Battle-owned and contains:

- Runtime `instance_id`
- `UnitDefinition` reference
- `GameEnums.BattleSide`
- Current health and AP
- Optional `GridCoordinate`
- Unique `ArtState` instances

`UnitState.create` initializes current health and AP from the Unit Definition and
creates fresh Art State for each valid default Art. It never mutates the source
Definition.

### RunUnitState

`RunUnitState` is Run-owned and intentionally separate from `UnitState`. It
contains:

- Runtime `instance_id`
- `UnitDefinition` reference
- Between-Battle current health
- A copied array of installed `ArtDefinition` references

It does not contain Battle AP, cooldowns, side, or grid position. A future Battle
setup boundary will create Battle-owned Unit State from Run-owned Unit State and
will return an explicit Battle outcome.

### ScrollStackState

`ScrollStackState` owns a `ScrollDefinition` reference and mutable quantity.
Quantity limits are enforced by the future Run command layer, not by direct
Definition mutation.

### BattleState

Battle State v1 contains:

- Battle phase
- Active side
- Round number
- Battle-owned Unit State references

It is currently a data container only. Turn transitions, Grid ownership,
actions, effects, defeat resolution, and outcomes belong to the Battle kernel
phase.

### RunState

Run State v1 contains:

- `HeroDefinition` reference
- Run seed
- Gold
- Run-owned Unit State
- Owned Relic Definition references
- Scroll Stack State

`RunState.create` copies the Hero's starting configuration into new mutable
arrays and new `RunUnitState` objects. Mutating Run inventory or Unit state
cannot change the Hero, Unit, Art, or Relic Definitions.

## Rule Contracts

### Conditions

`ConditionDefinition` is an abstract Resource with:

- Configuration validation
- A side-effect-free `evaluate` contract
- Typed `ConditionContext`
- Typed `ConditionResult` and `ConditionStatus`

No concrete gameplay condition is included in v1.

### Effects

`EffectDefinition` is an abstract static configuration Resource.
`EffectExecutor` is an abstract execution service that receives a typed
`EffectContext` and returns a typed `EffectResult`.

This separation prevents authored Effect Resources from owning mutable Battle
state or searching the scene tree. No concrete Effect is included in v1.

### Targeting

`TargetingDefinition` contains:

- Target kind and relation
- Minimum and maximum range
- Minimum and maximum selected targets
- Line-of-sight requirement

`TargetResolver` is an abstract service that receives `TargetingContext` and
returns a typed `TargetSelection`. Target Selection stores Unit instance IDs,
cell coordinates, terrain object instance IDs, or a Battle target without
untyped dictionaries.

Geometry, candidate discovery, and line-of-sight execution belong to the Grid
and Battle phases.

### Triggers

`TriggerDefinition` is an abstract Resource that composes Conditions and ordered
Effects. Concrete typed event bindings and trigger execution are deferred.
Relics and passive Arts can therefore declare the correct structural dependency
without introducing string event names or concrete behavior.

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
- Unit tag compatibility for default Art installation
- Nested Condition, Effect, Targeting, and Trigger configuration
- Art upgrade cycles and repeated upgrade content IDs

Expected validation failures are returned as
`DefinitionValidationResult` containing typed `DefinitionValidationIssue`
objects and `DefinitionValidationCode` enum values. Validation does not print,
mutate content, or depend on UI.

Cross-file content ID uniqueness is deferred to the future `ContentCatalog`.
This validator checks one Definition graph at a time.

## Test Boundary

Tests use concrete Condition, Effect, and Trigger classes only under
`tests/fixtures`. They are contract fixtures and are not game content.

The headless test runner verifies:

- Valid instances of every v1 top-level Definition
- Invalid IDs, values, references, tags, targeting, and upgrades
- Definition and State mutation isolation
- Run and Battle Unit state separation
- Typed rule result and target value objects
- Godot Resource save and load round trips


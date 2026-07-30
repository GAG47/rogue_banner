# Core Type Inventory

## Purpose

This inventory defines intended responsibilities and ownership before concrete
implementation. A listed type is a contract candidate, not permission to create
all types immediately. Types are implemented when their owning phase begins and
must preserve these boundaries.

All gameplay APIs use statically typed objects, enums, and typed collections.
Untyped dictionaries are limited to serialization adapters and must be converted
to validated types before entering domain code.

## Shared Conventions

- Definition types are immutable `Resource` schemas.
- Authored instances live under `content`.
- Mutable runtime types are unique to a run or battle.
- Read models are immutable snapshots exposed to UI.
- Requests express desired actions.
- Results express success, failure, and generated events.
- Stable IDs are required for catalogs and saves.
- Raw ID values do not replace typed domain references inside gameplay code.

## Core Data Layer v1

Implemented v1 contracts are recorded in `docs/data_model.md`. The implemented
set contains:

- `GameEnums`
- `DefinitionResource` and `DefinitionValidator`
- `TagDefinition`, `HeroDefinition`, `UnitDefinition`, `ArtDefinition`,
  `RelicDefinition`, `ScrollDefinition`, `EnemyDefinition`, and
  `TerrainDefinition`
- Condition, Effect, Targeting, and Trigger base contracts
- `ArtState`, `UnitState`, `RunUnitState`, `ScrollStackState`, `BattleState`,
  and `RunState`

Other types in this inventory remain planned contracts and must not be treated
as implemented APIs.

## Battle Kernel v2

Implemented v2 contracts are recorded in `docs/battle_kernel.md`. The
implemented set adds:

- `CellState`, `GridOccupant`, `GridState`, and typed Grid operation results
- `GridPathfinder` and `GridPathResult`
- Battle-local Unit identity and Run source identity
- `BattlePlacementService` and `BattleTurnService`
- Move, Use Art, and End Turn action requests
- Action validation, execution plans, execution results, and
  `BattleActionService`

## Art and Effect System v3

Implemented v3 contracts are recorded in `docs/art_effect_system.md`. The
implemented set adds:

- `ModifierDefinition`, `BuffDefinition`, `BuffState`, `AttributeCalculator`,
  and `BuffService`
- Battle and installation Condition contexts plus all, any, and not composition
- `BattleTargetResolver` and line-of-sight validation
- Effect planning and execution for damage, healing, shield, movement,
  Apply Buff, and Remove Buff
- Typed Battle events and deterministic passive trigger processing
- Completed Use Art action execution
- `ArtLoadoutService` for installation, removal, and upgrade variants
- Defeat cleanup and terminal Battle resolution

Types outside the v1, v2, and v3 implemented sets remain planned contracts.

## Enums

| Type | Responsibility |
| --- | --- |
| `ArtRarity` | `COMMON`, `UNCOMMON`, and `RARE` |
| `ArtCategory` | `ATTACK`, `SKILL`, and `PASSIVE` |
| `BattleSide` | Player and enemy ownership |
| `BattlePhase` | Setup, player turn, enemy turn, victory, and failure |
| `IntentKind` | Locked, pattern, and enhance intent semantics |
| `TargetRelation` | Self, ally, enemy, neutral, or any |
| `TargetKind` | Cell, unit, terrain object, or battle |
| `ModifierOperation` | Flat, additive, multiplicative, override, and clamp |
| `BuffStackingRule` | Refresh duration, add stacks, or replace |
| `EffectTargetSource` | Actor, spatially hit Units, event source, or event target |
| `HitTargetKind` | Unit, scene object, or either hit category |
| `BattleEventKind` | Stable typed Battle event categories |
| `EventUnitRole` | Source or target Unit in a typed Battle event |
| `RewardKind` | Unit, Art, Relic, Scroll, currency, or service |
| `MapNodeKind` | Battle, elite, boss, shop, camp, chest, or event |
| `ActionFailureCode` | Stable machine-readable action rejection categories |

Enums are extended only when a new stable domain category exists. Content IDs
must not be encoded as enum members.

## Definition Types

| Type | Required responsibility |
| --- | --- |
| `TagDefinition` | Stable tag identity and editor-facing metadata |
| `HeroDefinition` | Initial relics, exclusive pools, tag preferences, Art pools, and starting configuration |
| `UnitDefinition` | Maximum health, base attack, maximum AP, slots, tags, and default Arts |
| `ArtDefinition` | Rarity, category, AP cost, cooldown, targeting, requirements, effects, and upgrade data |
| `ArtDefinition.upgraded_variant` | A typed upgraded Art variant |
| `RelicDefinition` | Run or battle triggers, conditions, and configured effects |
| `ScrollDefinition` | Carrying rules, targeting, requirements, and one-use effects |
| `EnemyDefinition` | Base unit definition, decision policy, phases, and reward references |
| `EnemyPhaseDefinition` | Entry condition and decision policy for a phase |
| `TerrainDefinition` | Blocking, movement cost, interaction, and configured traits |
| `BuffDefinition` | Duration, stacking, modifiers, triggers, and configured effects |
| `RewardPoolDefinition` | Weighted authored entries and pool-level constraints |
| `MapEventDefinition` | Typed entry conditions, choices, and outcomes |

Definition Resources may reference other Definition Resources. They must not
store current health, current AP, current cooldown, stack count, grid position,
or any other per-run mutable value.

## Runtime State Types

| Type | Authoritative data |
| --- | --- |
| `UnitState` | Battle-local identity, source Run identity, Definition, health, AP, side, installed Arts, and defeat state |
| `RunUnitState` | Run-owned Unit health and installed Art references without Battle state |
| `ArtState` | Art definition reference, upgrade variant, cooldown, and per-battle usage state |
| `BuffState` | Buff definition reference, source, stacks, and remaining duration |
| `GridState` | Bounds, cells, terrain references, and occupancy |
| `CellState` | Coordinate and terrain; occupancy remains exclusively in Grid State |
| `TurnState` | Round, active side, phase, and acting order |
| `BattleState` | Grid, Battle-local Units, phase, active side, round, and Unit ID allocation |
| `IntentPlan` | Intent kind, actor, execution data, and authoritative preview data |
| `TeamState` | Owned units and their between-battle configuration |
| `RelicState` | Relic definition and per-run trigger or charge state |
| `ScrollStackState` | Scroll definition and current quantity |
| `RunState` | Hero, team, currency, relics, scrolls, progress, seed, and unlock view |
| `MapState` | Generated nodes, connections, current node, and visited state |

Runtime state may expose read-only snapshots, but external systems must mutate it
only through its owning command service.

## Rule Types

| Type | Responsibility |
| --- | --- |
| `ConditionDefinition` | Immutable condition configuration |
| `ConditionContext` | Typed read-only facts available to a condition |
| `ConditionResult` | Boolean outcome plus typed failure information |
| `TargetingDefinition` | Candidate rules, geometry, range, and selection limits |
| `TargetQuery` | Actor, origin, and typed targeting request |
| `TargetSelection` | Cells, Units, objects, or Battle submitted as the action aim |
| `ResolvedTargetSet` | Submitted aim, affected Cells, and occupancy-derived hits |
| `TargetSnapshot` | Resolved targets retained by a locked intent |
| `EffectDefinition` | Immutable configuration for one generic effect |
| `EffectContext` | Actor, source, targets, battle access, and execution metadata |
| `EffectResult` | State changes, events, and explicit failure information |
| `ModifierDefinition` | Attribute, operation, value, and priority |
| `AttributeQuery` | Base value and contextual modifier sources |
| `TriggerDefinition` | Event type, condition, limits, and requested effects |
| `WeightedEntry` | Typed candidate reference and non-negative weight |
| `RandomSource` | Seeded random operations supplied to random consumers |

Implemented reusable rule types include Condition composition, event Unit
relations, Battle target resolution, damage, healing, shield, movement,
Apply Buff, Remove Buff, attribute modifiers, relative affected-Cell
footprints, and explicit hit requirements. Forced movement, directional or
rotated footprints, and additional factual content Conditions remain planned.

## Battle Action Types

| Type | Responsibility |
| --- | --- |
| `BattleActionRequest` | Typed base request with actor and request identity |
| `MoveActionRequest` | Destination and optional path choice |
| `UseArtActionRequest` | Art state and target selection |
| `EndTurnActionRequest` | Request to end the active side's turn |
| `ExecuteIntentActionRequest` | Authoritative intent plan selected for execution |
| `ActionValidationResult` | Success or typed rejection with explanation data |
| `ActionExecutionPlan` | Fully validated costs, targets, and ordered effects |
| `ActionExecutionResult` | Committed changes and resulting Battle phase |
| `BattleOutcome` | Victory, failure, rewards context, and surviving unit results |

An execution plan is not a second state store. It is short-lived immutable data
used to ensure predictable validation finishes before mutation begins.

## Event Types

`BattleEvent` is the typed base event and contains sequence identity and source
metadata. Event payload subclasses contain only the data required by observers.

Implemented Battle event families are:

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

Event names describe completed facts. Events do not grant direct mutable access
to their source state.

## Art Types

| Type | Responsibility |
| --- | --- |
| `ArtLoadoutService` | Installation, removal, and upgrade validation for Run Units |
| `ArtLoadoutResult` | Typed loadout success or requirement failure |
| `UseArtActionRequest` | Battle actor, installed slot, and submitted target selection |
| `ArtDefinition.upgraded_variant` | Data-driven upgraded variant |
| `BattleEventProcessor` | Runtime passive Art and Buff trigger processing |

Installation validation uses slot rules and conditions. Art execution submits a
Battle action; it does not apply effects directly from UI or a Unit node.

## Intent Types

| Type | Responsibility |
| --- | --- |
| `EnemyDecisionContext` | Read-only battle facts visible to decision logic |
| `EnemyDecisionPolicy` | Selects and builds the next intent plan |
| `LockedIntentData` | Resolved target snapshot retained across movement |
| `PatternIntentData` | Pattern resolved from the actor's execution position |
| `EnhanceIntentData` | Self-targeted charging, shielding, or modifier plan |
| `IntentPreview` | Read-only visualization data derived from an intent plan |
| `EnemyPhaseState` | Current enemy phase and transition history |

Intent preview is derived data. It must never become the execution source of
truth.

## Run and Reward Types

| Type | Responsibility |
| --- | --- |
| `RunSetup` | Hero, seed, difficulty, and initial content references |
| `RunCommand` | Typed request to change Run state |
| `RunResult` | Applied changes or typed rejection |
| `RewardGenerationContext` | Hero, floor, rarity rules, unlock state, and random source |
| `RewardCandidate` | Typed reward reference, quantity, and computed weight |
| `RewardOffer` | Generated choices with source and generation metadata |
| `RewardGrantRequest` | Selected offer entry and destination |
| `ContentCatalog` | Stable ID lookup and validated authored content sets |
| `UnlockState` | Content and rule availability visible to generation systems |

Reward generation filters eligibility, calculates weights, and selects entries
as separate deterministic steps.

## Map and Persistence Types

| Type | Responsibility |
| --- | --- |
| `MapGenerationRequest` | Seed, floor rules, and required node constraints |
| `MapNodeDefinition` | Static node category and encounter or service reference |
| `MapNodeState` | Runtime visibility, visitation, and resolution state |
| `MapConnection` | Directed connection between node identities |
| `MapAdvanceRequest` | Selected reachable destination |
| `SaveData` | Versioned serializable run snapshot |
| `SaveVersion` | Schema version value |
| `LoadResult` | Loaded state, migration outcome, warnings, or failure |
| `ContentReferenceData` | Stable serialized reference resolved through the catalog |

Persistence adapters translate typed runtime state to serializable data and
back. Serialization dictionaries must not leak into domain systems.

## UI Boundary Types

UI receives read models and sends requests. Planned read models include:

- `BattleReadModel`
- `UnitReadModel`
- `CellReadModel`
- `ArtReadModel`
- `IntentReadModel`
- `RunReadModel`
- `RewardReadModel`
- `MapReadModel`

Read models may format already-computed state for presentation, but they do not
recalculate gameplay validity, damage, range, rewards, or intent targets.

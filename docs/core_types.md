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
- Event payload schema and context-aware trigger validation
- Transactional Battle action and initial-turn execution
- Completed Use Art action execution
- `ArtLoadoutService` for installation, removal, and upgrade variants
- Defeat cleanup and terminal Battle resolution

## Enemy Intent System v4

Implemented v4 contracts are recorded in `docs/enemy_intent_system.md`. The
implemented set adds:

- `IntentDefinition`, fixed-cycle and priority decision policy Definitions,
  reusable enemy-decision Conditions, and typed Enemy phase Definitions
- Battle-owned `EnemyState` and persistent `IntentPlan`
- Deterministic Intent generation from Battle seed and authoritative state
- Locked Unit, Cell, and scene-object commitments
- Directional pattern footprints with live preview after displacement
- Enhance intents using the existing Art and Effect system
- Ordered movement and Art execution through existing Battle action requests
- Automatic enemy turns with explicit fizzle and internal-failure semantics
- Transactional Battle start, enemy turn, and next-turn Intent generation

## Run and Reward System v5

Implemented v5 contracts are recorded in `docs/run_reward_system.md`. The
implemented set adds:

- `RunArtState`, `RunRelicState`, Battle Relic state, and Battle Scroll state
- Private Run inventories, runtime IDs, phases, sessions, offers, and optimistic
  Run transactions
- Typed Run commands for Gold, Units, Arts, Relics, Scrolls, healing, and
  Map-event damage
- `BattleSetup`, `BattleOutcome`, and one-time transactional outcome application
- Typed Battle sources, Relic trigger binding, and `UseScrollActionRequest`
- Reward payload, entry, and pool Definitions
- Deterministic filtering and weighted Reward offer generation
- Pick-one, take-all, and purchase-any offer transactions
- `RunFlowService` orchestration across Battle, reward, shop, and Run phases

## Map and Event System v6

Implemented v6 contracts are recorded in `docs/map_event_system.md`. The
implemented set adds:

- Map, typed node, Battlefield, Encounter, Event, and camp Definitions
- Deterministic layered Map generation and validated forward connections
- `MapState`, `MapNodeState`, `MapNodeSessionState`, and
  `MapEventSessionState` inside Run transactions
- `MapReadModel` with derived reachability, visibility, and current layer
- `EncounterBuildService` and runtime player deployment requests
- Generic Event Run operations and `MapEventConditionContext`
- Persisted weighted Event outcomes with atomic execution retry
- `MapFlowService` orchestration across Map, Battle, Reward, shop, chest,
  Event, camp, and Run ending

Types outside the v1 through v6 implemented sets remain planned contracts.

## Enums

| Type | Responsibility |
| --- | --- |
| `ArtRarity` | `COMMON`, `UNCOMMON`, and `RARE` |
| `ArtCategory` | `ATTACK`, `SKILL`, and `PASSIVE` |
| `BattleSide` | Player and enemy ownership |
| `BattlePhase` | Setup, player turn, enemy turn, victory, and failure |
| `IntentKind` | Locked, pattern, and enhance intent semantics |
| `IntentTargetRule` | Locked Unit, Cell, scene object, pattern direction, or self selection |
| `IntentSequence` | Art-only, Move-then-Art, or Art-then-Move ordering |
| `IntentStepStatus` | Executed, fizzled, skipped, or internal-failure outcome |
| `CardinalDirection` | Stable four-direction geometry orientation |
| `TargetRelation` | Self, ally, enemy, neutral, or any |
| `TargetKind` | Cell, unit, terrain object, or battle |
| `ModifierOperation` | Flat, additive, multiplicative, override, and clamp |
| `BuffStackingRule` | Refresh duration, add stacks, or replace |
| `EffectTargetSource` | Actor, spatially hit Units, event source, or event target |
| `HitTargetKind` | Unit, scene object, or either hit category |
| `BattleEventKind` | Stable typed Battle event categories |
| `EventUnitRole` | Source or target Unit in a typed Battle event |
| `EventDataCapability` | Typed payload facts guaranteed by an event kind |
| `ConditionContextKind` | Installation, action-use, Battle trigger, enemy decision, Reward generation, or Map Event context |
| `SideRelation` | Same or opposing side relative to a passive owner |
| `TriggerSourceKind` | Stable Art, Buff, or Relic trigger source category |
| `BattleSourceKind` | Unit, Relic, Scroll, or system effect and event origin |
| `RunPhase` | Ready, preparing or running Battle, resolving Map node, choosing Reward, shopping, or ended |
| `RunEndReason` | None, victory, defeat, or abandonment |
| `RewardKind` | Currency, Art, Relic, Scroll, Unit, healing, or Art upgrade |
| `RewardOfferRule` | Pick one, take all, or purchase any |
| `RewardSource` | Battle, shop, recruitment, chest, or event origin |
| `MapNodeKind` | Start, Battle, elite, Boss, shop, camp, chest, or Event |
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
| `IntentDefinition` | Display data, Art reference, target rule, direction, movement, and step order |
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
| `RunUnitState` | Run-owned Unit health and installed runtime Art IDs without Battle state |
| `RunArtState` | Unique owned Art identity and current Definition variant |
| `RunRelicState` | Unique owned Relic identity and Definition |
| `ArtState` | Art definition reference, upgrade variant, cooldown, and per-battle usage state |
| `BuffState` | Buff definition reference, source, stacks, and remaining duration |
| `GridState` | Bounds, cells, terrain references, and occupancy |
| `CellState` | Coordinate and terrain; occupancy remains exclusively in Grid State |
| `TurnState` | Round, active side, phase, and acting order |
| `BattleState` | Grid, Battle-local Units and Enemies, seed, phase, side, round, and identity allocation |
| `EnemyState` | Current phase, fixed-cycle progress, and current Intent plan |
| `IntentPlan` | Published actor, Art slot, target commitment, movement destination, direction, and step order |
| `TeamState` | Owned units and their between-battle configuration |
| `RelicState` | Relic definition and per-run trigger or charge state |
| `ScrollStackState` | Scroll definition and current quantity |
| `RunState` | Hero, team, currency, relics, scrolls, progress, seed, and unlock view |
| `MapState` | Generated nodes, connections, current node, status facts, and active node session |

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
relations, event side relations, Battle target resolution, damage, healing,
shield, movement, forced movement, Apply Buff, Remove Buff, attribute
modifiers, relative affected-Cell footprints, directional rotation, explicit
hit requirements, health-ratio decisions, and nearby-Unit decisions.
Additional factual content Conditions remain planned until reusable content
requires them.

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
| `BattleTransaction` | Isolated working Battle State and all-or-nothing commit |
| `UseScrollActionRequest` | Player Unit, Scroll stack, and target selection |
| `BattleOutcome` | Terminal phase, participant health, Scroll quantities, and Battle session identity |

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

`BattleEventSchema` maps each event kind to guaranteed payload capabilities and
validates the concrete event payload. Trigger configuration and runtime
processing share this mapping.

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
| `EnemyDecisionPolicyDefinition` | Typed base policy for selecting a configured Intent |
| `FixedCycleDecisionDefinition` | Deterministic authored Intent sequence |
| `PriorityDecisionDefinition` | Condition, priority, weight, and seeded selection policy |
| `IntentDefinition` | Immutable configurable enemy action description |
| `IntentPlan` | Stored target, destination, direction, Art slot, and action order |
| `IntentPreview` | Read-only visualization data derived from an intent plan |
| `EnemyState` | Current phase, fixed-cycle index, and stored plan |
| `IntentGenerationService` | Phase evaluation and deterministic plan publication |
| `IntentExecutor` | Adapts a stored plan to Move and Use Art requests |
| `EnemyTurnService` | Executes living enemies in stable Battle-ID order |
| `BattleFlowService` | Owns start and complete automatic-turn transactions |

Intent preview is derived data. It must never become the execution source of
truth.

## Run and Reward Types

| Type | Responsibility |
| --- | --- |
| `RunSetup` | Hero, seed, difficulty, and initial content references |
| `RunCommand` | Typed request to change Run state |
| `RunCommandResult` | Applied runtime IDs, quantity change, or typed rejection |
| `RunTransaction` | Deep Run working copy with version-checked atomic commit |
| `RunFlowService` | Battle, outcome, Reward, shop, and Run phase orchestration |
| `BattleSetup` | Immutable Battle input copied from one Run transaction |
| `RunBattleSessionState` | Persistent Run-to-Battle identity and inventory mapping |
| `BattleOutcome` | Typed terminal values returned without mutating Run |
| `RunOutcomeApplier` | Exact-session validation and transactional outcome writeback |
| `RewardGenerationContext` | Run, source, floor, Battle rank, and generation index |
| `RewardEntryDefinition` | Payload, rarity, weight, floor bounds, duplicate rule, price, and conditions |
| `RewardPoolDefinition` | Offer rule, option count, and authored candidates |
| `RewardOption` | Fixed payload, rarity, price, and per-option status |
| `RewardOffer` | Stored offer ID, source, rule, generation index, options, and status |
| `RewardGrantDestination` | Optional Unit, Art, or immediate-install destination |
| `RewardGenerationService` | Eligibility filtering and deterministic weighted selection |
| `RewardGrantService` | Payload-to-Run-command adapter inside a transaction |
| `RewardOfferService` | Atomic claim, purchase, take-all, and close operations |

Reward generation filters all candidates before selection. The saved offer,
not a regenerated pool roll, is the source for display and granting. Content
unlock filtering remains deferred until the Phase 9 unlock state exists.

## Map and Persistence Types

| Type | Responsibility |
| --- | --- |
| `MapDefinition` | Layer bounds, connection chance, start and Boss nodes, and weighted node pool |
| `MapGenerationRequest` | Map Definition, Run seed, and generation index |
| `MapNodeDefinition` | Typed static node category and Encounter or service reference |
| `BattlefieldDefinition` | Grid size, Terrain layout, and legal deployment Cells |
| `EncounterDefinition` | Battlefield, Enemy spawns, rank, and Battle Reward pool |
| `MapEventDefinition` | Choices, Conditions, weighted outcomes, and generic Run operations |
| `MapNodeState` | Stable generated identity, layer, selected content, and status fact |
| `MapConnection` | Directed connection between node identities |
| `MapAdvanceRequest` | Selected reachable destination |
| `MapNodeSessionState` | Current node stage and downstream Battle, Reward, or Event provenance |
| `MapEventSessionState` | Selected choice, saved outcome, Event stage, and Reward provenance |
| `MapReadModel` | Detached nodes plus derived reachability, visibility, and current layer |
| `MapFlowService` | Transactional route and downstream activity coordinator |
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

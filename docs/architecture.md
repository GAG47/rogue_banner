# Architecture

## Purpose

This document defines the stable system boundaries and dependency direction for
Rogue Banner. It describes ownership and communication rules; it does not
pre-implement every future feature.

A phase is complete when its contracts, lifecycle, failure behavior, tests, and
required implementations are complete. "Complete" does not mean predicting all
future content variants.

## Directory Layout

```text
res://
├── assets/
│   ├── audio/
│   ├── fonts/
│   ├── images/
│   └── shaders/
├── content/
│   ├── arts/
│   ├── buffs/
│   ├── encounters/
│   ├── enemies/
│   ├── heroes/
│   ├── intents/
│   ├── map_events/
│   ├── maps/
│   ├── relics/
│   ├── rewards/
│   ├── scrolls/
│   ├── terrains/
│   └── units/
├── docs/
│   └── development_logs/
├── scenes/
│   ├── battle/
│   ├── debug/
│   ├── run/
│   └── ui/
├── scripts/
│   ├── arts/
│   ├── battle/
│   ├── core/
│   ├── definitions/
│   ├── effects/
│   ├── grid/
│   ├── intents/
│   ├── map/
│   ├── persistence/
│   ├── rewards/
│   ├── rules/
│   ├── run/
│   ├── runtime/
│   └── ui/
└── tests/
    ├── fixtures/
    ├── integration/
    └── unit/
```

`content` contains authored static Resource instances. `scripts/definitions`
contains the Resource schemas used by that content. Empty directories are
intentional and receive files only when their owning system is implemented.

## Dependency Direction

Dependencies point downward:

```text
UI
├── Battle requests and read models
└── Run requests and read models

Arts and Intents
└── Battle action pipeline
    ├── Effect execution
    ├── Rule evaluation
    ├── Battle state
    │   ├── Runtime state
    │   └── Grid
    └── Domain events

Map flow and progression
├── Run and Reward transaction interfaces
├── Encounter construction and Battle flow
└── Map and Event Definitions

Run and Rewards
├── Definitions
├── Content catalog
└── Core types

Definitions, Runtime state, Grid, and Rules
└── Core types
```

The following reverse dependencies are prohibited:

- Definitions must not depend on scene nodes or runtime state.
- Grid must not depend on units, arts, intents, or UI.
- Runtime state must not depend on UI.
- Battle must not call UI.
- Effects must not search the scene tree.
- Rewards must not mutate Battle internals.
- Map must not implement Battle or Reward rules.
- UI must not mutate Battle or Run state directly.

When two systems appear to require each other, extract the smallest read-only
query or command contract into `scripts/core` or `scripts/rules`. Do not solve a
cycle with a global manager.

## Ownership and Sources of Truth

| Data | Authoritative owner | Consumers |
| --- | --- | --- |
| Authored base stats and capabilities | Definition Resources | Runtime state constructors and rules |
| Current health, AP, cooldowns, and buffs | Battle Unit state | Battle, rules, intents, and read models |
| Unit positions, Cell terrain, and occupancy | Grid state | Movement, targeting, and battle validation |
| Current phase and active side | Turn state | Action validation, AI, and UI read models |
| Installed arts | Unit runtime state | Art validation and read models |
| Generated enemy action | Intent plan | Preview and execution |
| Team, currency, owned Arts, relics, scrolls, and active offer | Run state | Rewards, map, persistence, and read models |
| Battle-to-Run participant and inventory mapping | Run battle session | Battle setup, outcome validation, and Run flow |
| Generated reward or shop inventory | Reward offer stored by Run state | Reward UI and reward grant service |
| Generated route, current node, and node status | Map state stored by Run state | Map flow and Map read model |
| Current Map activity and downstream provenance | Map node session | Map flow, Battle session, and Reward offer validation |
| Sampled Event choice and outcome | Map Event session | Event execution and Map read model |
| Formal Battle presentation snapshot | Detached Battle read model | Battle scene views |
| Active Run and current Battle object | Per-run session controller | Run screens and composed Battle screen |
| Formal Run presentation snapshot | Split detached Run read models | Map, deployment, reward, event, and inventory views |
| Available authored content | Content catalog | Run setup, rewards, and persistence |

Only an owning system may mutate its state. Other systems issue typed requests
or query read-only views.

## Static Definitions and Runtime State

Definition Resources are editor-authored, shareable, and treated as immutable at
runtime. They contain base values, tags, requirements, configured effects, and
content references.

Runtime state is created for a battle or run. It stores mutable values and may
refer to definitions, but definitions never refer to runtime state. Runtime
objects must not be written back into shared Resources.

Use typed Resource references while the game is running. Stable content IDs are
used only at catalog, save, and migration boundaries. Display names must never
serve as identifiers.

Battle-owned `UnitState` and Run-owned `RunUnitState` are separate runtime
types. Run state never retains Battle AP, cooldown, side, or grid position, and
Battle never mutates the Run team directly.

`GridState` is the only authority for Unit and scene object positions.
`UnitState` and `CellState` do not store duplicate occupancy or position data.

## Scene and Script Responsibilities

Scenes own visual composition and editor-authored node relationships. Scripts
attached to scene nodes adapt input, rendering, animation, and system lifecycle.
They do not become the authoritative source for gameplay state.

Formal Battle views receive detached `BattleReadModel` objects. The scene
controller may own the authoritative Battle lifecycle and submit typed requests,
but it does not expose mutable `BattleState` or `UnitState` references to child
views. Presentation selection, hover, and pending-target mode are UI state and
never duplicate a gameplay fact.

The formal Run screen owns one `RunSessionController`. The controller retains
the authoritative `RunState`, the current `BattleState`, and the Map flow
service for that Run only. Its visible route is derived from `RunPhase` and the
active Map node session. Views receive detached summary, Map, deployment,
reward, event, inventory, and Battle models. They never retain mutable Run
objects or duplicate the gameplay phase.

Fixed nodes are created manually in the Godot editor. Runtime code may create
truly dynamic entities such as units, indicators, projectiles, and effects from
configured scenes, but it must not recreate fixed scene structure.

Prefer exported direct node references or owner-provided dependencies. Do not
use deep node paths to reach across system boundaries.

## Core Rule Model

### Tags

Tags are typed `TagDefinition` Resources. A tag describes identity and metadata;
it does not contain mutable unit state. Install requirements and content
weighting use typed tag references.

Tags do not trigger behavior through scattered `if tag == ...` branches.
Behavioral consequences are represented by conditions, modifiers, traits, or
explicit policies owned by the appropriate system.

### Conditions

A condition is a side-effect-free, typed definition evaluated against a
read-only `ConditionContext`. Conditions return a structured result so failed
requirements can be explained to UI without UI duplicating the rule.

Common condition composition supports all, any, and negation. Content-specific
conditions are prohibited unless the concept is reusable across content.

### Targeting

A targeting definition describes candidate discovery, selection constraints,
range, shape, line-of-sight rules, and allowed target categories. Target
selection produces typed target data, never arbitrary dictionaries.

Locked intents store a resolved target snapshot. Pattern intents store a
targeting pattern and resolve it from the enemy's current execution position.
Preview and execution both consume the same persistent intent plan. The plan
stores authored commitments such as target identity, destination, direction,
Art slot, and step order. It does not retain resolved hits or a short-lived
Art execution plan.

### Effects

An effect definition is immutable configuration. Effect executors apply generic
operations through an explicit `EffectContext`, such as damage, healing,
shielding, movement, forced movement, status application, or modifier changes.

Effects are composed in an ordered list. An executor returns a typed result and
domain events. It must not directly update UI, rewards, or map state.

### Modifiers

Modifiers declare a target attribute, operation, value, and priority. Duration
and stacks belong to the Buff State that supplies the modifier.

Attribute calculation applies flat values, the combined additive percentage,
multiplicative values, then overrides and clamps. Priority and stable source
order resolve ordering within each operation group. This is the one calculation
path used by Unit refresh and scaled effects.

### Triggers and Events

Domain events are typed data objects. Signals announce completed events and use
past-tense names such as `unit_moved`, `damage_applied`, and `turn_ended`.

Triggers listen through an explicit battle or run event stream and evaluate a
condition before requesting effects. There is no untyped global string event
bus. Event processing order is deterministic and covered by tests.

Battle events use a first-in, first-out queue. Living Units are scanned by
Battle ID, passive Arts by slot, and Buffs by runtime order. Event kinds declare
their guaranteed payload capabilities in one schema, and trigger Conditions and
effects are validated against that schema before runtime.

Trigger candidates are snapshotted per event. Activation identity uses owner,
stable Art slot or Buff instance, and trigger index, so source-list mutation
cannot reset limits or make a newly added source observe the event that created
it. Battle State owns monotonic event sequence IDs.

### Random Selection

Weighted pools use an injected random source with an explicit seed. Filtering,
weight calculation, and selection are separate operations so tests can verify
each stage. Reward eligibility is owned by Rewards, not by the generic random
utility.

Enemy priority decisions derive their random stream from Battle seed, round,
enemy identity, phase, and decision progress. Equal seed and Battle state
therefore produce equal Intent selections without storing mutable random state
in a Definition.

## Battle Action Pipeline

Every player, enemy, art, and system action uses one authoritative pipeline:

1. Receive a typed action request.
2. Validate the request against authoritative state.
3. Create an isolated Battle transaction and revalidate its working state.
4. Build an execution plan with all information needed to execute the action.
5. Commit costs and cooldown changes in the working state.
6. Execute ordered effects and publish typed domain events.
7. Process follow-up triggers and resolve defeats, victory, or failure.
8. Commit the complete working state only if every step succeeds.
9. Return a typed action result and refreshed read model.

UI may request validation and preview data, but only the action pipeline commits
gameplay state. An internal failure at any execution stage discards the working
state and cannot leave a partially applied action.

## Art and Intent Integration

An Art definition configures rarity, category, AP cost, cooldown, targeting,
requirements, effects, and upgrade data. Unit state owns installed Art state and
current cooldowns. Unit scripts never implement concrete Art behavior.

Enemy decision logic produces an intent plan. Intent preview reads it, and enemy
execution submits its action through the same Battle action pipeline used by
other actions. Multi-stage enemies select decision policies through typed phase
state rather than content-specific branches in Battle.

Battle-owned `EnemyState` stores phase, fixed-cycle progress, and the current
plan. Locked targets and fixed movement destinations never retarget after the
plan is published. Pattern geometry keeps its published direction but resolves
from the enemy's current position, so forced movement changes both preview and
execution consistently.

`BattleFlowService` owns the transaction spanning a player End Turn request,
ordered enemy plans, the enemy End Turn request, and next-player-turn Intent
generation. Expected battlefield disruption produces a typed fizzle and does
not block later enemies. Internal rule failures discard the complete flow.

## Run, Reward, and Map Boundaries

Run owns the hero, team, currency, relic inventory, scroll inventory, unlock
view, and progress. Battle receives a battle setup snapshot and returns a battle
outcome; it does not mutate the run directly.

`RunFlowService` creates a `BattleSetup` from a Run transaction, records a
`RunBattleSessionState`, and commits `IN_BATTLE` only after the Battle starts.
`BattleOutcome` reports only persistent Unit health and Scroll quantities.
`RunOutcomeApplier` validates the exact session mapping and writes the whole
outcome to a Run transaction once. Battle failure ends the Run and never opens
a victory reward.

Rewards receive a typed generation context including Run seed, generation
index, hero, floor, Battle rank, inventory, and source. Eligibility is filtered
before deterministic weighted selection. The resulting `RewardOffer` is stored
in Run State and remains the one source for display and grant. A claim or
purchase changes Run only through `RunCommandService` inside the same
transaction that updates Gold and option status.

Run-owned Arts, Relics, and Scroll stacks have stable runtime instance IDs.
Battle setup copies them into Battle-owned state. Relics enter the typed Battle
event processor as side-owned sources without a Unit actor. Scrolls use
`UseScrollActionRequest` and the existing targeting, condition, effect, event,
cleanup, and terminal-resolution pipeline.

Map owns route generation, node connections, selection, and progression. Map
nodes reference encounter, reward, shop, or event definitions. They do not
implement those systems.

## Persistence Boundary

Save files contain stable IDs and serializable runtime values, never Node
references or shared mutable Resources. Schema versioning begins with the first
save type even though full persistence is implemented later. Load failures and
missing content IDs must produce explicit errors or migration results.

## Verification Strategy

Architecture is validated with permanent executable probes rather than
production content shortcuts. Examples include:

- Grid occupancy and pathfinding fixtures
- An AP movement action
- A composed damage and status effect
- A passive trigger responding to a domain event
- An intent whose preview and execution share one plan
- A seeded reward pool with deterministic output

Unit tests cover pure rules and data. Integration tests cover action pipelines
and system boundaries. Debug scenes may visualize systems, but they are not
sources of gameplay logic.

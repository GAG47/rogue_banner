# Map, Encounter, and Event System

## Scope

Version 6 owns route generation and progression between Run activities. It
adds deterministic layered Maps, typed node content, Encounter construction,
multi-step Event sessions, Map read models, and atomic coordination with the
v5 Battle and Reward boundaries.

It does not implement production Map UI, route animation, save serialization,
content unlocks, meta progression, or a general Event scripting language.

## Authority and Dependency Direction

`MapState`, stored inside `RunState`, is the sole authority for:

- Generated node instances and directed connections
- The current node
- Entered and resolved node facts
- The active node session
- The concrete content selected for every generated node

It does not store reachable nodes, visible nodes, or a duplicated floor value.
`MapReadModel` derives those values from current facts whenever UI requests a
snapshot.

```text
Map UI
→ MapFlowService
→ RunTransaction
→ MapState inside RunState

MapFlowService
├── EncounterBuildService → RunFlowService → Battle
├── MapNodePreparationService → Reward generation and shops
└── MapEventService → Run commands and Reward generation
```

Map coordinates progression but never calculates Battle damage, grants Reward
payloads directly, or changes inventory fields. Lower-level services expose
transaction-internal methods so one Map transaction can finish downstream work
and node completion atomically.

Standalone v5 Battle-resolution and Reward-offer entry points reject sessions
with a nonzero progression ID. This prevents callers from bypassing Map node
completion while retaining the standalone APIs for Runs without a Map.

## Static Definitions

`MapDefinition` configures:

- Layer count and node-count bounds
- Extra connection chance
- One start node
- One Boss encounter node
- Weighted node-pool entries with layer and copy bounds

Typed node Definitions represent standard, elite, and Boss Encounters, shops,
chests, Events, and camps. Start is the only valid generic node.

`BattlefieldDefinition` owns Grid dimensions, default Terrain, Terrain
overrides, and legal player deployment Cells. `EncounterDefinition` owns one
Battlefield, fixed Enemy spawns, Battle rank, and Battle Reward pool. Player
Unit choices and positions remain runtime input through
`EncounterStartRequest`.

`MapEventDefinition` owns typed choices. Each choice contains Conditions and
weighted outcomes. An outcome composes generic Run operations:

- Change Gold
- Heal or damage a selected Run Unit
- Consume a selected Scroll stack
- Remove a selected Relic
- Grant one typed Reward payload
- Open one Reward pool as the final operation

Camp content uses the same contract and validator, with deterministic single
outcomes. Event Conditions use `MapEventConditionContext`; they are not adapted
to Battle Condition contexts.

## Deterministic Generation

`MapGenerationService` creates a layered directed acyclic graph from Run seed,
Map generation index, and Map content ID. It first places required node copies,
then fills remaining Cells by weighted selection. Connections always point to
the next layer.

Every source receives an outgoing edge and every target receives an incoming
edge. The generated graph therefore has a route from start through each layer
to the Boss. Generated node instance IDs, concrete Definitions, and connections
are saved; opening a Map view never samples content again.

## Runtime Facts and Read Model

`MapNodeState` stores stable instance ID, layer, column, concrete Definition,
and status. Status is one of unvisited, entered, or resolved.

`MapNodeSessionState` stores one progression session ID, node ID, current
stage, and the associated Battle session, Reward offer, or Event session IDs.
Only one node session may be active.

A destination is reachable only when:

- The current node is resolved
- No node session is active
- A saved outgoing connection targets it
- The target is unvisited

Public Map and Run queries return detached copies. Mutating a read view cannot
change authoritative progression or bypass the Run state version.

## Node Progression

`MapFlowService.advance` enters only a computed reachable node and creates one
monotonic progression session. Node entry does not imply completion.

- Encounter nodes enter `PREPARING_BATTLE` and wait for player deployment.
- Shops remain active until their purchase-any offer is explicitly closed.
- Chests remain active until their take-all or pick-one offer completes.
- Events and camps remain active across choice, planned result, optional target
  selection, and optional Reward collection.
- Boss nodes complete only after Battle victory and any Boss Reward completes.

When a dynamically filtered shop, chest, Event, or Battle Reward has no legal
option, generation reports an explicit successful empty result. Map flow then
completes the downstream step without leaving an unusable session.

## Encounter and Battle Coordination

`EncounterBuildService` combines authored Battlefield and Enemy deployment
facts with a validated player deployment request. It produces the existing
`RunBattleStartRequest`; `RunFlowService` remains the Battle setup authority.

The progression session ID is copied into `RunBattleSessionState`. Battle
resolution checks the Map session, Battle session, progression session, and
Battle State IDs before writeback. Health, Scroll quantity, Reward generation,
offer installation, and node transition share one Run transaction.

Battle defeat ends the Run with `RunEndReason.DEFEAT`. Battle victory either
opens the saved Battle offer or completes the node. A repeated or foreign
Battle outcome cannot progress the Map.

## Event Planning and Retry

Event resolution deliberately uses two transactions:

1. Validate a choice, sample one weighted outcome, and save its choice and
   outcome IDs.
2. Execute that saved outcome through Run commands and Reward services.

The second transaction never samples again. If a target is invalid or any
operation fails, all operations roll back while the already committed plan
remains. The caller may correct its target request and retry the same outcome.

Reward-pool opening must be the last outcome operation. Direct operations and
offer creation therefore commit together. When an Event Reward opens, its
offer and Event session share the progression session ID; collecting the offer
finishes the Event node in the same transaction.

If an Event operation defeats every available Run Unit, the Run ends with
`RunEndReason.DEFEAT` and does not open a later Reward.

## Run Ending

`RunPhase.ENDED` is paired with an explicit `RunEndReason`:

- `VICTORY` after the resolved Boss node and Reward
- `DEFEAT` after Battle failure or loss of every available Unit
- `ABANDONED` after an explicit abandon request

The reason is authoritative Run state. UI does not infer victory from the
current node or Battle phase.

## Validation and Verification

Definition validation covers Battlefield bounds, Terrain references,
deployment overlap and passability, Enemy spawn passability, Encounter rank,
Reward rules, Map layer and nonnegative pool-copy constraints, node subtype
agreement, Event IDs, Condition contexts, outcome weights, operation values,
and Reward-pool placement. Runtime Encounter and generic Battle setup also
recheck deployment Cells against the final Grid.

Tests cover deterministic graph generation, next-layer edges, read-view
isolation, illegal advancement, deployment validation, Event rollback and
same-result retry, Event Reward correlation, shop and chest completion, Battle
provenance, Boss victory timing, duplicate outcome rejection, and explicit Run
end reasons.

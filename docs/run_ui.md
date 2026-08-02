# Complete Run UI

## Scope

v8 is the first functional interface for a complete in-run route. It composes
the systems completed in v5 through v7 without moving their rules into UI.

The authored first route is:

```text
Battle
→ Shop
→ Event
→ Camp
→ Chest
→ Elite
→ Boss
```

The route is deliberately small and deterministic. It validates system
composition and player comprehension before broad content production.

## Session Ownership

`RunSessionController` is instantiated once per Run. It owns:

- the authoritative `RunState`;
- the current `BattleState`, while a Battle is active;
- `MapFlowService` orchestration;
- typed Run commands;
- detached read-model construction.

It is not a global manager or autoload. Starting a new Run replaces the owned
state for that controller instance.

`RunSessionRoute` is derived from `RunPhase`:

| Run phase | UI route |
| --- | --- |
| `READY` | Map |
| `PREPARING_BATTLE` | Deployment |
| `IN_BATTLE` | Battle |
| `CHOOSING_REWARD` | Reward |
| `SHOPPING` | Shop |
| `RESOLVING_MAP_NODE` | Event or Camp |
| `ENDED` | Run result |

The UI does not save another authoritative flow phase. Overlay visibility and
deployment drafts are presentation state only.

## Read Models

Every refresh duplicates Run state before building the following views:

- `RunSummaryReadModel`;
- `MapReadModel`;
- `DeploymentReadModel`;
- `RewardReadModel`;
- `InventoryReadModel`;
- `EventReadModel`;
- `BattleReadModel`.

Views may hold these detached models for display. They cannot mutate Run or
Battle facts. The current Battle is handed only to the composed
`BattleScreenController`, which submits typed Battle action requests through
the existing action pipeline.

## Battle Result Boundary

Terminal Battle state and Run result submission are separate steps:

```text
Battle reaches victory or failure
→ Battle screen displays the terminal result
→ player selects Continue
→ RunSessionController calls MapFlowService.resolve_current_battle
→ Run outcome is written back
→ reward, Map completion, or Run result route is derived
```

The Battle screen does not create rewards or complete Map nodes.

## Reward Interaction

`PICK_ANY` supports independent option resolution:

- an available option may be claimed;
- an available option may be skipped;
- claiming or skipping does not close sibling options;
- explicit finish marks remaining available options as skipped and closes the
  offer;
- a failed claim leaves that option available and does not prevent another
  option from being handled.

`PICK_ONE`, `TAKE_ALL`, and `PURCHASE_ANY` retain their existing semantics.
Reward UI supplies typed destinations for healing and Art upgrade rewards.
Scroll capacity can be handled by discarding one carried Scroll through a Run
transaction while a Battle reward is open.

## Scene Composition

`scenes/run/run_screen.tscn` contains fixed editor-owned panels for:

- Run summary header;
- route Map;
- deployment;
- composed Battle screen;
- reward and Shop offers;
- Event and Camp choices;
- inventory and Art loadout management;
- victory, defeat, and abandonment results.

Runtime-created controls represent generated Map nodes, reward options, Event
choices, and deployment Cells. They are dynamic domain instances rather than
fixed scene structure.

All player-facing copy is Chinese. Identifiers, scripts, nodes, resources,
comments, and documentation remain English.

## Deferred Work

v8 does not add:

- save or load;
- hero selection;
- unlocks or meta progression;
- route randomization beyond the existing generator;
- final art, animation, audio, tutorial, or production skinning;
- broad content balance.

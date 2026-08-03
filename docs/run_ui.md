# Complete Run UI

## Scope

v8 is the first functional interface for a complete in-run route. It composes
the systems completed in v5 through v7 without moving their rules into UI.

The authored first route contains thirteen regular layers followed by one Boss
layer. Each regular layer contains two to four seeded nodes. Node kinds use
weighted layer ranges and global copy limits, so routes vary without moving
content rules into UI.

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

### Compact Run Header

The non-Battle Run header presents only immediate in-run information:

- the active Hero portrait and name tooltip;
- current Gold;
- one visual slot for every Scroll-stack capacity, including empty slots;
- Map, current Build, and Settings actions aligned to the right.

The Build overlay reads `InventoryReadModel`. It is editable only while the Run
is in the Map-ready phase and otherwise remains a read-only status view. The Map
button can temporarily show the saved Map during deployment, Reward, Shop, and
Event activities, then return to the authoritative route screen. When Map is
the required route, the button remains selected because no separate room state
exists.

Settings owns only presentation and platform state. It currently controls
fullscreen display, Map tooltips, and the existing typed abandon-Run request.
It does not write gameplay state directly.

The former permanent feedback footer is removed. Expected action failures use
a temporary toast and successful operations refresh directly from the next
snapshot.

## v8.1 Route Map Presentation

The route Map is presented as a vertically climbing graph rather than a flat
list. `MapRouteGraphView` consumes only `MapReadModel` facts and renders:

- generated nodes grouped by layer;
- authoritative connections behind the nodes;
- reachable connections and nodes in gold;
- the current and resolved path in teal;
- future connections in muted ink while future node icons remain clear;
- compact node-kind symbols without permanent labels;
- short Chinese tooltips on hover or keyboard focus;
- compact icons that enlarge on hover, with a heavier outline only for the next
  reachable layer;
- an original parchment-style background without a persistent information
  sidebar or layer guide grid.

The bottom of the graph is the Run start and the top is the Boss. When the Map
opens, the scroll view centers the current node. Only IDs contained in
`reachable_node_ids` create enabled node buttons. Visual styling never decides
whether a node can be entered.

Adjacent layers use a sparse ordered connection backbone. Every node has an
incoming and outgoing connection, every route can reach the Boss, and optional
branches preserve column order to avoid crossings. Multi-node layers are never
fully connected. Regular nodes normally expose one or two onward choices;
single start or Boss endpoints are the unavoidable exceptions.

Generated node controls are runtime presentation for generated Map data. The
fixed `MapPanel`, `RouteScroll`, and graph canvas remain scene-owned structure.

## Deferred Work

v8 does not add:

- save or load;
- hero selection;
- unlocks or meta progression;
- final art, animation, audio, tutorial, or production skinning;
- broad content balance.

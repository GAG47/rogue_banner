# Battle Presentation Layer

## Scope

Version 7 provides the first formal Battle interface and a complete single-
encounter player loop:

```text
Deployment
→ Player and automatic Enemy turns
→ Victory or failure
→ Result display
→ Restart
```

It deliberately does not present Map, Reward, shop, Event, Run inventory, or
meta-progression flows. Those systems remain headless and independently tested
until the in-Battle interaction is proven readable and usable.

## Dependency and Authority

```text
BattleState
→ BattleReadModelService
→ detached BattleReadModel
→ Battle Screen views

Player input
→ BattleScreenController
→ typed Battle request or placement request
→ existing Battle service
→ refreshed BattleReadModel
```

`BattleState` and `GridState` remain the only gameplay authorities. The formal
UI controller owns their lifecycle but does not expose them to child views.
Views receive only detached presentation objects.

`BattleReadModelService` first duplicates the complete Battle state, then builds
Cells, Units, Arts, Buffs, and Intent previews from that snapshot. Existing read
models remain stable when later actions commit. Mutating a read-model object
cannot mutate authoritative Battle state.

The controller is the only UI-layer adapter allowed to access the authoritative
Battle object. It uses that access only to submit typed requests or to build a
new read model. It does not directly change health, AP, cooldown, Buff, phase,
or occupancy.

## Formal Scene Contract

`scenes/battle/battle_screen.tscn` owns the fixed visual composition:

- `BattleScreen` owns presentation lifecycle and input adaptation.
- `Header` presents phase, active side, round, and the current objective.
- `BattleBoard` composes separate Grid, highlight, and Unit drawing layers.
- `DeploymentPanel` presents setup progress and deployment commands.
- `BattlePanel` presents selected Unit state, Buffs, passive Arts, active Arts,
  cooldowns, enemy Intents, and turn commands.
- `Footer` presents actionable operation results and failure reasons.
- `ResultOverlay` presents terminal Battle state and restart.

All fixed nodes are editor-owned scene structure. Runtime drawing iterates
configured Cells, Units, and Intents because those are dynamic Battle data.

Node and script identifiers remain English. Player-facing copy is Chinese.

## Deployment

The formal encounter uses an authored `EncounterDefinition` and
`BattlefieldDefinition`. Enemy spawns and Terrain are created from those
Resources. The screen supplies a configured list of player Unit Definitions for
this standalone encounter.

During `BattlePhase.SETUP`, clicks on authored player deployment Cells submit to
`BattlePlacementService`. Placement therefore preserves Grid bounds, Terrain,
occupancy, Unit validation, and Battle-local ID rules. Invalid or occupied Cells
do not advance deployment. Starting the Battle remains disabled until all
configured player Units are placed.

Restart creates a new setup state from the same authored scenario. It does not
attempt to undo a live Battle object.

## Battle Interaction

Selecting a player Unit queries `BattleActionService.validate` for every Cell to
produce the current weighted movement range. Clicking a destination submits a
`MoveActionRequest`; the UI never moves an occupant itself.

Selecting an Art presents its category, AP cost, base cooldown, live cooldown,
target kind, and range. Entering targeting mode separates:

- geometric Art range;
- Cells accepted by authoritative action validation;
- the affected footprint under the hovered legal aim.

Cell-targeted Arts may select empty Cells. Their AP, cooldown, actor effects,
and event processing execute normally even when the affected footprint contains
no Unit or scene object. Arts that require a hit continue to express that rule
through their configured Conditions.

The formal v7 encounter uses one-target Arts. The UI rejects a configured
multi-selection request instead of inventing partial selection state. A general
multi-selection interaction remains deferred until authored Battle content
requires it.

## Enemy Intent Presentation

`BattleReadModelService` uses `IntentPreviewService` on the same detached Battle
snapshot used for every other visual element. Each displayed Intent contains:

- actor and Intent identity;
- Locked, Pattern, or Enhance kind;
- locked Unit, Cell, or scene-object identity;
- committed movement destination and current movement path;
- current aim and affected Cells;
- current validity.

The board renders current danger Cells and planned movement paths. Pattern
danger is rebuilt after every committed action, so forced movement changes its
visual footprint without replacing the saved `IntentPlan`.

Ending the player turn calls `BattleFlowService.end_player_turn`. Enemy movement,
Arts, events, cleanup, terminal resolution, return to the player turn, and next
Intent generation therefore remain one existing transactional flow.

## Failure and Result Presentation

Expected action failures are translated from typed `ActionFailureCode` values
into Chinese operation feedback. Internal errors remain failures returned by
the owning Battle service; the UI does not repair or partially continue them.

Victory and failure are read from `BattlePhase`. The result overlay does not
infer a result by counting displayed Units. Restart returns to deployment and
rebuilds the read model.

## Authored v7 Scenario

The first interface scenario is configured by:

- `content/encounters/v7_battlefield.tres`
- `content/encounters/v7_tactical_encounter.tres`

It contains two deployable Vanguards and the existing Archer, Heavy, and Priest
enemy behaviors. The encounter proves Locked, Pattern, and Enhance previews in
one formal screen. The Resources are validation content, not production balance
or final art.

## Deferred Work

Version 7 does not include:

- Map, Reward, shop, camp, chest, Event, or Run inventory UI;
- permanent hero selection or meta progression;
- final assets, animation, VFX, audio, tutorial, or settings;
- general multi-target selection;
- player deployment sourced from a persistent Run session.

Those features must continue to use existing Run and Map request boundaries
when their presentation layers are implemented.

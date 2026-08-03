# Battle Presentation Layer

## Scope

Version 7 provides the first formal Battle interface and a complete single-
encounter player loop. Version 8.2 integrates that loop into the persistent Run
shell and replaces its diagnostic presentation with the shared formal board:

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
- `BoardArea` gives the shared board the main Battle surface.
- `BattleBoardView` composes separate Grid, highlight, and Unit drawing layers.
- `DeploymentPanel` presents setup progress and deployment commands.
- `SelectedUnitHud` appears only for a selected friendly Unit and presents its
  portrait, name, health, status slots, Arts, and AP without an enclosing panel.
- `TurnControl` keeps round and end-turn controls fixed at the lower right.
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

The Run deployment screen and the Battle screen instantiate the same
`scenes/battle/battle_board.tscn` composition. Deployment presents the complete
authored Battlefield, including terrain and enemy spawns, then Battle presents
the resulting `BattleState` without switching to a second grid renderer.

## Battle Interaction

Selecting a player Unit queries `BattleActionService.validate` for every Cell to
produce the current weighted movement range. Clicking a destination submits a
`MoveActionRequest`; the UI never moves an occupant itself.

Mouse selection is handled by `BattleBoardView._gui_input`. The board converts
its local pointer position into a `GridCoordinate` and emits a Cell request to
the controller. Parent Run controls ignore board pointer events instead of
depending on `_unhandled_input`, so a hosted Battle remains interactive.

The Battle surface does not keep a second local title bar or a permanent side
panel. With no friendly selection, the Unit HUD is hidden and the Battlefield
remains unobstructed except for the fixed lower-right turn controls. Inspecting
an Enemy does not expose its Arts as player actions.

`BoardArea` covers the complete space below the persistent Run header. The lower
Unit HUD is an overlay and never reserves layout height, resizes the board, or
changes its position when selection changes. It has no rectangular background,
outer border, or permanent divider, so the Battle background remains continuous.

Holding Space and dragging with the left mouse button pans the board
presentation. Middle-mouse dragging provides the same operation. Panning changes
only the drawing offset owned by `BattleBoardView`; Grid coordinates, occupancy,
targeting, Intents, and authoritative Battle state are unchanged.

Clicking an available Art selects it and immediately enters targeting. Passive,
cooling-down, and unaffordable Arts remain visible but disabled. Right-clicking
the board cancels either Art or Scroll targeting and restores the selected
Unit's validated movement range. The board state communicates selectable Cells
without a transient instruction or operation-message layer.
Targeting presentation separates:

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

Expected action failures and internal errors remain typed results returned by
the owning Battle service. The formal Battle view does not render generic
transient message banners or repair and partially continue failed actions.

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

## Run Shell Integration

While a Run Battle is active, the compact Hero, Gold, Scroll-slot, Map, Build,
and Settings header remains visible. The Battle screen is hosted below that
header instead of replacing the whole Run interface. Opening the Map temporarily
hides the Battle presentation but keeps the same current `BattleState` bound;
closing the Map returns to the unchanged Battle.

Occupied Scroll slots are buttons. Hovering presents the configured generic
effect summary, quantity, and range. Clicking opens only a compact Use and
Discard menu; clicking the same slot or outside the menu closes it. Use sends
the stable stack ID to `BattleScreenController`. The currently selected friendly
Unit remains the actor, and target selection, conditions, execution,
consumption, and failure reporting stay in the existing Scroll action pipeline.
Discard submits a typed `DiscardScrollActionRequest`, decrements the Battle
stack transactionally, and does not emit a Scroll-used event. During Battle the
header refreshes quantities from the detached `BattleReadModel`, not the
uncommitted Run inventory snapshot.

## Deferred Work

The current formal Battle interface does not include:

- permanent hero selection or meta progression;
- final assets, animation, VFX, audio, tutorial, or settings;
- general multi-target selection;
- player deployment sourced from a persistent Run session.

Those features must continue to use existing Run and Map request boundaries
when their presentation layers are implemented.

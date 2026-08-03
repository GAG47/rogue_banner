# v8.2 Deployment and Battle UI

## Outcome

v8.2 replaces the diagnostic deployment form and hosted Battle presentation
with one shared Battlefield view. Deployment shows the complete board and a
bottom Unit roster; Battle keeps the persistent Run header and adds a focused
command panel. The implementation retains the v6 Encounter authority, the v7
Battle action pipeline, and the v8 typed UI request boundary.

## Presentation

- Rendered every Battlefield Cell at once in its authored grid position.
- Removed coordinate labels, raw terrain names, the unit dropdown, and the
  permanent assignment list.
- Added distinct visual states for normal, difficult, blocked, enemy-spawn,
  deployable, and occupied Cells.
- Highlighted authored deployment Cells in cyan without changing their
  authoritative eligibility.
- Replaced the dropdown with compact Unit cards in a horizontal bottom roster.
- Kept undeployed Units bright, the current Unit strongly outlined, and
  deployed Units muted but still selectable for repositioning.
- Moved Unit health and detailed Cell facts into tooltips.
- Added a compact deployment count plus top-aligned reset and Battle start
  actions.

## Interaction

- The first undeployed Unit is selected automatically.
- Selecting a valid Cell places the current Unit and advances selection to the
  next undeployed Unit.
- Selecting a deployed Unit allows it to be moved to another valid Cell.
- Reset clears only the presentation draft.
- Start Battle converts the deterministic draft into typed
  `RunUnitDeployment` requests.
- Selection, placement, and reset refresh existing controls in place so a
  pressed control is never deleted during its own signal callback.
- The same board contract handles Battle Cell selection locally, so a hosted
  Battle does not depend on global unhandled input.
- Clicking a player Unit selects it, displays its movement range and Arts, and
  keeps every action routed through the existing typed Battle services.

## Battle Presentation

- Kept the Run Hero, Gold, Scroll-slot, Map, Build, and Settings header visible
  throughout Battle while removing the second Battle title bar.
- Removed the permanent right-side Unit panel and gave the Battle surface to the
  Battlefield.
- Added a friendly-selection-only lower HUD with a placeholder portrait, name,
  health bar, status slots, horizontal Arts, and available AP.
- Kept round and end-turn controls fixed at the lower right, including when no
  Unit is selected.
- Removed permanent and transient generic operation-message overlays.
- Removed the bordered board frame and permanent lower layout reservation. The
  board now occupies the complete area below the Run header while selection and
  turn controls remain overlays.
- Added Space plus left-drag and middle-mouse drag board panning without changing
  Grid or Battle state.
- Removed the enclosing lower-HUD panel, border, divider, manual target button,
  and duplicated Scroll controls.
- Made an available Art button enter target selection immediately and added
  right-click cancellation back to validated movement mode.
- Made occupied persistent-header Scroll slots clickable and routed their Use
  action through the selected Battle Unit and existing Scroll request pipeline.
- Refreshed top-bar Scroll quantities from Battle read models while an encounter
  is active.
- Moved Scroll effect details to a compact custom card attached below the
  hovered header slot and reduced the click popup to a tightly fitted Use and
  Discard pair with no dedicated Cancel action.
- Closed both Scroll cards as soon as the pointer leaves the selected slot and
  their combined bounds.
- Added transactional Battle Scroll discard requests and retained Run-command
  discard on supported progression routes.
- Centered equal fixed-width Art controls across the center lower HUD with
  deliberate spacing while keeping Unit status and turn controls on one band.
- Removed instructional, success, and failure banners from formal Battle and
  Run presentation; typed service results remain unchanged.
- Added pointer-centered mouse-wheel zoom plus public zoom and reset methods to
  the shared Battle board.
- Replaced the coordinate-heavy board and verbose status dump with terrain,
  faction markers, health bars, AP, shield, Buff, Intent, movement, and target
  states.
- Allowed the read-only route Map to open during Battle without clearing the
  current Battle object.

## Boundaries

- `BattlefieldDefinition` remains the static source for dimensions, terrain,
  enemy spawns, and player deployment Cells.
- `DeploymentReadModel` remains a detached presentation snapshot.
- The owning Map node instance ID resets drafts between same-name Encounters.
- `DeploymentPanelView` owns only selection and draft assignments.
- `BattleBoardView` owns only fitting, drawing-model presentation, and local
  Cell input conversion.
- `EncounterBuildService` remains the final deployment validator.
- No Battle, Run, Map, Effect, Art, Intent, or reward rules changed.

## Validation

- Added formal-scene checks for complete Battlefield rendering, bottom-roster
  population, removal of debug controls, valid placement, stable control order,
  persistent Battle shell layout, board-local Unit selection, and Battle-start
  availability.
- Project suite: 797 assertions passed at implementation time.
- The formal deployment and Battle screens were captured and visually inspected
  at the project's default 1152 by 648 viewport, including idle and selected
  overlay states.
- Godot headless editor import completed without script or resource errors.

## Deferred

- Authored Unit portraits and final Battlefield art. The current Unit portrait
  uses the existing project icon as a presentation placeholder.
- Deployment animation, audio, and final production skinning.

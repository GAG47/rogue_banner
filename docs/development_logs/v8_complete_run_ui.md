# v8 Complete Run UI

## Outcome

v8 connects the existing in-run systems into one formal playable route. A Run
can start with the authored Banner Captain, advance through all node types,
deploy Units, use the v7 Battle interface, resolve rewards and Events, manage
the team between nodes, fight the Boss, and reach an explicit terminal result.

## Implemented

- Added a per-run `RunSessionController` with authoritative Run and current
  Battle ownership.
- Added route derivation from Run phase instead of a second UI flow state.
- Added split detached read models for summary, Map, deployment, inventory,
  reward, Event, and Battle presentation.
- Added `PICK_ANY` reward semantics with claim, skip, and explicit finish.
- Added Map-aware reward completion methods so offers cannot bypass node
  progression.
- Extended the formal Battle screen for an externally owned Battle and a
  terminal Continue boundary.
- Added Battle relic and Scroll display, Scroll target preview, and Scroll use
  through `UseScrollActionRequest`.
- Added formal Chinese UI panels for Map, deployment, Battle, rewards, Shop,
  Event, Camp, inventory, and Run results.
- Added the first fixed v8 Hero, party, encounters, reward pools, Events, Camp,
  and complete route content.
- Added integration coverage for the complete route and formal Run scene.

## Authority Decisions

- `RunState` remains the only authority for team, inventory, currency, active
  offers, phase, and Map state.
- `MapState` remains the only authority for route facts and node sessions.
- `BattleState` remains the authority for the active Battle and is retained by
  the session controller until Map resolution succeeds.
- Battle completion, rewards, and Map completion are coordinated only by
  `MapFlowService`.
- UI stores only selections, hover state, overlay visibility, and deployment
  drafts.

## Validation

- Project suite: 684 assertions passed at implementation time.
- Formal Run scene loaded and ran headlessly without script or resource errors.
- Godot headless editor import completed successfully apart from the known
  sandbox TCP listener warning.

## Deferred

- Meta progression and save compatibility.
- Hero and difficulty selection.
- Final visual assets, animation, audio, tutorial, and broad content balance.

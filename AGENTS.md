# Rogue Banner Development Rules

## Project

Rogue Banner is a Godot 4.7 project written in statically typed GDScript. It is a
2D, turn-based tactical roguelike. Architecture, system boundaries, and stable
interfaces take priority over quickly assembling a playable loop.

This file applies to the entire repository. More detailed rules are defined in:

- `docs/development_rules.md`
- `docs/architecture.md`
- `docs/core_types.md`
- `docs/development_roadmap.md`

## Language and Naming

Use English for all files, folders, scenes, nodes, classes, methods, variables,
signals, resource fields, comments, documentation, and commit messages.

- Files and folders: `snake_case`
- Variables and methods: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Signals: `snake_case` names that describe events that already happened

Do not introduce Chinese identifiers or comments.

## Mandatory Workflow

Before changing code:

1. Inspect the workspace, relevant scripts, and existing architecture.
2. Identify the authoritative source for every affected piece of data.
3. Search for existing or similar logic.
4. Check effects on battle, units, arts, tags, intents, rewards, and run state.
5. Confirm that an existing abstraction can own the change naturally.
6. Describe the current structure, the smallest system-level implementation, and
   the files that will change.

When a change needs scene nodes, first list each required node name, node type,
parent, and Inspector settings. Wait for the node names to be confirmed before
writing scripts that depend on them.

After changing code:

1. Run the narrowest relevant tests.
2. Run integration checks for affected boundaries.
3. Run `godot --headless --path . --editor --quit`.
4. Report changed files, validation results, and any remaining editor work.

## Architecture Rules

- Scenes compose systems, scripts implement behavior, and Resources define
  static configuration.
- Static definitions and mutable runtime state must remain separate.
- Shared definition Resources must never hold mutable battle or run state.
- UI presents state and sends requests; it does not implement game rules.
- Systems communicate through typed requests, results, events, signals, or
  explicit service methods.
- Core gameplay types must use enums, typed Resources, and explicit data
  classes instead of unstructured strings or dictionaries.
- Content combines generic rules. Do not hard-code individual heroes, units,
  arts, relics, scrolls, enemies, or bosses into system code.
- Preview and execution must consume the same authoritative intent or action
  plan.
- Random behavior must use an injected, seeded random source.
- A lower-level system must pass its tests before an upper-level system depends
  on it.

## Editing Constraints

- Do not create or modify `.tscn` files unless the task explicitly allows it.
- Do not modify `project.godot` unless the task explicitly allows it.
- Do not generate fixed editor-owned scene structure from code.
- Do not modify files unrelated to the task.
- Preserve user-authored changes in the workspace.
- Do not add speculative frameworks for unverified future requirements.

## Forbidden Shortcuts

- No content-specific branches in shared systems.
- No duplicate rule implementations across scripts.
- No temporary booleans or hidden state used to bypass the data model.
- No direct mutation of another system's internal state.
- No battle rules in UI scripts.
- No concrete art effects in unit scripts.
- No complete intent logic hard-coded in enemy scene scripts.
- No deep node paths used to control another system's internals.
- No string-based event bus for core domain events.

Stop implementation and report the architectural conflict when a request would
create duplicate sources of truth, require many special cases, touch several
unrelated systems for a small feature, or cannot be expressed through existing
interfaces without violating their responsibilities.


# Development Rules

## Engineering Principle

Architecture, system completeness, and stable interfaces come before rapid
feature assembly. Do not implement a temporary playable loop by bypassing domain
boundaries.

Every system begins with ownership, inputs, outputs, invariants, and dependency
direction. An upper-level system may depend on it only after tests validate the
contract.

## Project Constraints

- Engine: Godot 4.7
- Language: statically typed GDScript
- Game type: 2D turn-based tactical roguelike
- Scene assembly is editor-owned.
- Behavior is script-owned.
- Static configuration is Resource-owned.
- Mutable battle and run data is runtime-state-owned.

## Naming

All repository content uses English.

| Item | Convention | Example |
| --- | --- | --- |
| File | `snake_case` | `battle_state.gd` |
| Folder | `snake_case` | `scripts/battle` |
| Scene | `snake_case` | `battle_debug.tscn` |
| Node | `PascalCase` | `BattleBoard` |
| Class | `PascalCase` | `BattleState` |
| Variable | `snake_case` | `current_health` |
| Method | `snake_case` | `validate_action` |
| Constant | `UPPER_SNAKE_CASE` | `MAX_PATH_LENGTH` |
| Signal | past event in `snake_case` | `turn_ended` |

Comments, documentation, Resource fields, and commit messages also use English.

## Static Typing

- Type every variable, parameter, return value, signal argument, exported field,
  collection, and intermediate value when GDScript permits it.
- Avoid `Variant` in domain APIs.
- Do not pass untyped dictionaries between systems.
- Use enums for closed categories.
- Use typed Resources or data classes for extensible content concepts.
- Do not use raw strings as core types.
- Use explicit result types for expected validation failures.

## Domain Boundaries

### Definitions

Own authored schemas for Hero, Unit, Art, Relic, Scroll, Enemy, Terrain, Buff,
and other content. Definition Resources are immutable during play.

### Runtime State

Own current health, AP, cooldowns, Buff stacks, positions, inventories, and
progress. Runtime state references definitions but never writes into them.

### Grid

Own coordinates, bounds, cells, occupancy, distance, terrain traversal, and
pathfinding. Grid does not know Art or UI rules.

### Battle

Own turn flow, action validation and execution, damage resolution coordination,
movement coordination, victory, failure, and Battle outcomes.

### Rules and Effects

Own conditions, targeting, modifiers, effects, Buffs, triggers, and deterministic
random utilities. Rules operate through explicit contexts.

### Intents

Own enemy decisions, locked targets, live patterns, enhancement plans, preview,
and execution plans. Preview and execution use the same intent plan.

### Rewards

Own eligibility, rarity, weight calculation, offers, and grants. Reward
generation receives Hero, floor, unlock, and random context explicitly.

### Run

Own Hero, team, currency, relics, scrolls, seed, difficulty, and progression.
Run creates Battle setup and consumes Battle outcomes through typed boundaries.

### Map

Own route generation, connections, node selection, and floor progression. Map
references encounters and services but does not implement them.

### UI

Own presentation, animation, and input translation. UI sends requests and
renders read models. UI never owns authoritative gameplay state.

## Content Composition

Specific content combines reusable definitions:

- An Art combines targeting, conditions, costs, cooldown, and effects.
- A charge combines direction targeting, movement, and collision effects.
- A Relic combines triggers, conditions, modifiers, and effects.
- An Enemy combines a Unit definition, decision policies, and intent patterns.
- A Reward pool combines eligibility rules, rarity rules, and weighted entries.

Do not add shared-system branches for a single Hero, Unit, Art, Relic, Scroll,
Enemy, or Boss. If content cannot be expressed, identify the missing reusable
concept and correct the model first.

## Source-of-Truth Rules

- Base content values come from Definition Resources.
- Current values come from runtime state.
- Occupancy comes from Grid state.
- Action validity comes from the Battle action pipeline.
- Intent execution data comes from the intent plan.
- Reward availability comes from Rewards.
- Run inventory and progress come from Run state.
- Display state is derived and never authoritative.

Do not cache a second writable copy of authoritative data in UI, scene nodes, or
another system.

## Communication Rules

- Use explicit commands for state changes.
- Use read-only queries or read models for observation.
- Use typed results for success and expected rejection.
- Use typed domain events for completed facts.
- Use signals to announce completed events at Node boundaries.
- Inject required collaborators rather than searching the scene tree.
- Avoid global managers and service locators.
- Avoid node paths that cross multiple system boundaries.

## Scene Editing

The project owner creates fixed scenes, nodes, and visual layouts in the Godot
editor. Before writing a script that relies on new nodes, provide:

- Node name
- Node type
- Parent node
- Required Inspector settings

Do not create or modify `.tscn` files or `project.godot` without explicit task
authorization. Do not dynamically generate fixed scene structure in code.

## Change Procedure

Before implementation:

1. Inspect relevant files and architecture documents.
2. Identify each affected system and its authoritative data.
3. Search for equivalent logic.
4. Verify the dependency direction.
5. Define or confirm input, output, invariant, and failure contracts.
6. List files to create or modify.
7. List required manual editor work.

During implementation:

1. Implement the owning abstraction.
2. Keep changes within the task scope.
3. Preserve static definition and runtime state separation.
4. Add tests at the same abstraction level.
5. Add a boundary integration test when another system will consume the API.

After implementation:

1. Run focused tests.
2. Run affected integration tests.
3. Run `godot --headless --path . --editor --quit`.
4. Report actual changes, validation results, and manual steps.

## Phase Gates

A phase is ready for upper-level dependencies only when:

- Ownership and lifecycle are documented.
- Public requests, results, events, and query interfaces are explicit.
- Invalid input behavior is defined.
- Deterministic behavior is testable.
- Unit tests cover pure rules.
- Integration tests cover public boundaries.
- A permanent fixture or debug probe demonstrates real composition.
- The Godot headless editor check succeeds.

A phase gate does not require production content or final presentation.

## Stop Conditions

Stop coding and explain the problem when:

- A requirement conflicts with the documented architecture.
- A change creates a duplicate source of truth.
- Many content-specific cases are required.
- A small feature requires changes across unrelated systems.
- The public interface cannot express the requirement naturally.
- A dependency would point in the prohibited direction.
- Correct behavior depends on hidden or temporary state.

Repair the responsible abstraction before building more features on it.

## Prohibited Patterns

- Gameplay rules implemented in UI
- Concrete Art effects implemented in Unit scripts
- Complete intent behavior embedded in Enemy scene scripts
- Shared Resource mutation for battle or run state
- Untyped string event buses
- Content identity based on display names
- Multiple implementations of AP, cooldown, damage, targeting, or reward rules
- Temporary booleans that bypass a missing state model
- Direct writes into another system's internal fields
- Random calls without an injected seedable source
- Speculative frameworks without a current verified use


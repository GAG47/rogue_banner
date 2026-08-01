# Development Roadmap

## Execution Model

Development is architecture-first, interface-first, and phase-gated. The goal is
not to assemble a temporary minimal game loop. Each phase delivers a reliable
system boundary that later phases may use.

Executable probes and debug fixtures are still required. They validate that
contracts compose in practice and become permanent tests rather than temporary
gameplay shortcuts.

## Phase 1: Standards and Domain Boundaries

Deliver:

- Repository structure and naming rules
- Scene and script responsibilities
- Definition and runtime-state boundary
- System dependency direction
- Event, effect, tag, targeting, modifier, and condition contracts
- Development rules
- Architecture document
- Core type inventory

Gate:

- Documents agree on ownership and dependency direction.
- No core concept has two authoritative owners.
- The Godot project opens successfully in headless editor mode.

## Phase 2: Data Models

Define:

- Hero
- Unit
- Art
- Relic
- Scroll
- Enemy
- Terrain
- Intent
- Effect
- Run
- Reward

Deliver:

- Typed Definition Resource schemas
- Typed runtime-state schemas where required
- Stable content identity and catalog boundary
- Validation rules for authored content
- Serialization boundaries without full save implementation
- Tests for defaults, validation, and definition/runtime separation

Gate:

- Invalid authored definitions fail with explicit diagnostics.
- Shared Resources remain unchanged when runtime state changes.
- Cross-definition references resolve through typed references or the catalog.

## Phase 3: Battle Kernel and Shared Rule Contracts

Build the smallest stable foundation required by rules:

- Grid coordinates and bounds
- Cells, terrain references, and occupancy
- Unit runtime state
- Turn and Battle state
- Typed action requests, validation results, execution plans, and results
- Read-only condition and targeting contexts
- Typed domain events
- Seeded random source

Then implement shared rules against that foundation:

- Tags and installation conditions
- Attribute calculation and modifiers
- Condition composition
- Target discovery and selection
- Effect execution
- Buff duration and stacking
- Trigger processing
- Upgrade variants
- Weighted pools

Gate:

- Rules do not depend on UI or scene nodes.
- Validation completes before predictable state mutation.
- Event and modifier order is deterministic.
- Grid, rule, and action tests pass.

## Phase 4: Board and Battle Foundation

Complete:

- Terrain traversal and blocking
- Unit placement and occupancy
- Movement and pathfinding
- AP and cooldown lifecycle
- Player and enemy turn transitions
- Action validation and execution
- Damage and defeat coordination
- Victory, failure, and Battle outcomes

Exclude:

- Rewards
- Map progression
- Shops
- Meta progression

Gate:

- A headless integration fixture completes movement, AP spending, turns, damage,
  defeat, and terminal Battle resolution.
- No UI component is required for rule correctness.

## Phase 5: Arts and Effects

Complete:

- Installation and removal
- Tag and slot requirements
- Use conditions
- Target selection
- AP spending
- Cooldowns
- Ordered effect composition
- Passive subscriptions
- Upgrade variants

Gate:

- Concrete Arts are authored only by composing generic capabilities.
- Active and passive Arts use the same event and effect infrastructure.
- UI previews use Battle validation results.

## Phase 6: Enemies and Intents

Implemented in v4. Final contracts and failure semantics are recorded in
`docs/enemy_intent_system.md`.

Complete:

- Enemy decision context and policy
- Locked intents
- Pattern intents
- Enhance intents
- Intent preview
- Intent execution
- Typed enemy phases
- Reusable Boss phase transitions

Gate:

- Preview and execution consume one intent plan.
- Locked targets remain stable after movement.
- Pattern targets resolve from the execution position.
- Enemy execution uses the Battle action pipeline.

Boss infrastructure is limited to reusable phase and policy concepts proven by
actual behavior requirements. Do not predict a complete Boss scripting language.

## Phase 7: Run Construction

Implemented in v5. Final contracts and failure semantics are recorded in
`docs/run_reward_system.md`.

Complete:

- Team and Unit management
- Art acquisition, installation, removal, and forgetting
- Relics
- Scroll carrying and consumption
- Currency
- Reward pools
- Shops
- Recruitment
- Between-floor rewards

Gate:

- All rewards use one generation pipeline.
- Hero, floor, rarity, unlock state, and seeded randomness are explicit inputs.
- Battle returns outcomes and never mutates Run directly.

The v5 implementation passes hero and current Run ownership through the
generation context. Content unlock filtering remains an explicit Phase 9 input
because no authoritative unlock state exists yet.

## Phase 8: Map and Events

Implemented in v6. Final contracts and failure semantics are recorded in
`docs/map_event_system.md`.

Complete:

- Route generation
- Node connection constraints
- Battle, elite, boss, shop, camp, chest, and event nodes
- Route selection
- Floor progression
- Event conditions, choices, and results

Gate:

- Map owns progression only.
- Encounter, reward, and event systems remain separate.
- Seeded maps are reproducible and validate reachability constraints.

## Interim v7 Battle Presentation Milestone

Before Phase 9, v7 introduces the first formal Battle presentation milestone.
Its final boundary is recorded in `docs/battle_ui.md`. This milestone validates
the usability of already completed Battle, Art, effect, Buff, and Intent systems
without adding Map, Reward, or meta-progression UI.

The v7 gate is:

- A player can deploy, move, use Arts, inspect enemy Intents, end turns, reach a
  terminal Battle result, and restart without debug controls.
- UI views consume detached Battle read models and submit typed requests.
- The formal interface displays empty-Cell aims, affected footprints, current
  Pattern danger, AP, cooldowns, Buffs, and actionable failures.

Map and Run presentation remain deferred; this is not an implementation of the
full Phase 12 production interface.

## Phase 9: Heroes and Meta Progression

Complete:

- Hero-specific Art pools
- Hero-specific Relics
- Unit tag preferences
- Starting configurations
- Content unlocks
- Hero unlocks
- Difficulty levels
- Save and load

Gate:

- Meta progression changes availability and rules rather than relying on
  permanent numerical domination.
- Save data is versioned and handles missing content references explicitly.

## Phase 10: Content Production

Produce:

- Heroes
- Unit tag combinations
- Arts
- Relics
- Scrolls
- Enemies
- Bosses
- Terrain
- Events

Gate:

- New content uses existing configuration types.
- A single content entry never requires a lower-level architecture branch.
- Content validation and catalog tests pass.

## Phase 11: Balance and Experience

Evaluate each build across:

- Damage
- Survival
- Mobility
- Setup

Also evaluate:

- Floor-specific pressure
- Reward strength and frequency
- AP and cooldown economy
- Intent readability
- Invalid or nonfunctional build paths

Balance changes modify authored values or reusable rules, not UI logic or
content-specific system branches.

## Phase 12: Presentation, Persistence, and Release

Complete:

- Production UI
- Animation and visual effects
- Audio
- Tutorial
- Settings
- Save compatibility and migrations
- Performance work
- Windows export
- Test coverage and version release

Save schema planning begins in Phase 2. This phase completes compatibility,
migration policy, and release validation rather than introducing persistence
constraints for the first time.

## Required Order

```text
Standards
→ Data models
→ Battle kernel and shared rules
→ Board and Battle
→ Arts and Effects
→ Enemies and Intents
→ Run construction
→ Map and Events
→ Heroes and meta progression
→ Content production
→ Balance and presentation
→ Release
```

When a requirement cannot be expressed naturally, return to the owning lower
layer and correct its model before continuing.

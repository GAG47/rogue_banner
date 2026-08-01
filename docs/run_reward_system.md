# Run, Reward, and Battle Outcome System

## Scope

Version 5 owns persistent in-run construction across Battles. It implements Run
inventory mutation, Battle snapshots and outcomes, Relic and Scroll Battle
integration, deterministic Reward offers, shops, recruitment, and the phase
orchestration needed to enter another Battle.

It does not implement route maps, node progression, random events, camps,
chests, content unlocks, saves, meta progression, or production UI.

Version 6 composes this boundary through transaction-internal methods described
in `docs/map_event_system.md`. Standalone v5 entry points retain their original
phase behavior; Map-owned calls attach a progression session and leave final
node completion to `MapFlowService`.

## Authority and Dependency Direction

`RunState` is the sole authority for:

- Hero and Run seed
- Gold
- Team membership and between-Battle health
- Owned Art, Relic, and Scroll instances
- Team and Scroll capacities
- Current Run phase
- Active Battle session mapping
- Active Reward or shop offer
- Runtime identity allocation and Reward generation count

Version 6 adds progression provenance to Battle sessions and Reward offers.
These IDs correlate downstream work without making Battle or Reward depend on
Map types. Standalone public resolution and offer methods reject nonzero
progression IDs; only Map-owned transaction orchestration may complete them.

Battle receives copies through `BattleSetup`. Rewards change Run only through
Run commands. Public inventory queries return detached snapshots, while Run
domain services use internal mutable access only inside a transaction. UI reads
fresh snapshots and submits service requests; it must not retain a snapshot as
a live reference across a Run state-version change.

```text
Run UI
→ RunFlowService / RunCommandService / RewardOfferService
→ RunTransaction
→ RunState

RunState
→ BattleSetupService
→ BattleSetup
→ BattleSetupFactory
→ BattleState
→ BattleOutcomeService
→ BattleOutcome
→ RunOutcomeApplier
→ RunTransaction
```

## Runtime Inventory Identity

Every Run Unit, Art, Relic, and Scroll stack has a monotonic runtime instance
ID. A Unit slot stores a `RunArtState.instance_id`, not an Art Definition
reference. Default Arts use the same ownership and installation rules as
acquired Arts.

Two instances of one Art Definition can be installed on different Units and
upgraded independently. Removing a Unit clears its slots and returns its Arts
to the derived uninstalled inventory.

## Run Commands and Transactions

`RunCommandService` supports:

- Gold gain and spending
- Unit recruitment and removal
- Art grant, install, uninstall, forget, and upgrade
- Relic grant and removal
- Scroll grant and consumption
- Unit healing and Map-event damage

Every public command begins a `RunTransaction`, rechecks the current phase and
rules against its working copy, and commits once. A failed command discards the
copy. Commits compare the captured Run state version, so a stale transaction
cannot overwrite a later result.

Run identity, seed, capacities, Gold, phase, inventories, sessions, offers, and
counters are private state. Public Unit, Art, Relic, Scroll, session, and offer
queries return detached state snapshots. Mutating a returned object therefore
cannot bypass validation or create an unversioned authoritative change.

Reward grants use the same command implementations inside the Reward
transaction. Buying an item therefore commits price, payload, destination, and
option status together.

## Battle Setup

`RunFlowService.start_battle` accepts a `RunBattleStartRequest` containing the
Grid, selected Run Unit deployments, enemy deployments, floor, Battle rank, and
Battle Reward pool.

`BattleSetupService` validates:

- Run is ready
- The Grid and deployments are valid and unique
- Every selected Run Unit exists and is alive
- Every complete installed Art loadout is valid
- Enemy Definitions are valid
- Relic and Scroll inventory references are valid

The resulting `BattleSetup` copies Unit health and Art Definitions, Relic
instances, Scroll quantities, and a deterministic Battle seed. The Battle owns
all copied mutable state. Run changes to `IN_BATTLE` only after the Battle
successfully starts.

`RunBattleSessionState` retains the Battle session ID, exact participant Run
Unit IDs, exact Scroll stack IDs, floor, rank, and Reward pool. This mapping is
not removed when a Battle Unit is defeated.

## Battle Outcome

`BattleOutcomeService` accepts only terminal Battles and returns:

- Battle session ID
- Victory or failure phase
- Final round
- Remaining health for every original Run participant
- Initial and remaining quantity for every copied Scroll stack

`RunOutcomeApplier` requires the exact active session and exact Unit and Scroll
ID sets. It rejects duplicates, missing entries, invalid health, changed initial
quantities, and repeated application before writing any value.

Victory applies the outcome and attempts to create one saved pick-one offer in
the same Run transaction. Runtime filtering may reduce a Battle offer below its
authored maximum option count. If no candidate remains eligible, the outcome,
health, and Scroll consumption still commit, the Battle session is cleared, and
the Run returns directly to `READY` without an offer. Failure applies health and
Scroll consumption, clears the session, sets the Run to `ENDED`, and creates no
Reward.

## Typed Battle Sources

`BattleSource` distinguishes Unit, Relic, Scroll, and system origins. Battle
events carry this source plus an optional acting Unit identity. Event schema
validation distinguishes payload capabilities that are possible from those
guaranteed for every source.

Relics are player-side trigger sources with no Unit owner. Relic configuration
validation rejects:

- Conditions that require an owner Unit
- Actor-targeted effects
- Unit-attribute scaling
- Actor-relative forced movement

Each owned Relic instance binds and triggers independently in stable runtime ID
order. An internal Relic trigger failure aborts and rolls back the complete
Battle action.

## Scroll Actions

`UseScrollActionRequest` identifies the player Unit using the item, one Battle
Scroll stack, and a typed target selection. Scroll validation and execution
reuse the existing target resolver, conditions, effect planner, event processor,
defeat cleanup, and Battle resolution.

Scroll use costs no AP and applies no Art cooldown. A successful action consumes
one quantity in the Battle copy and publishes `ScrollUsedEvent`. An internal
failure rolls back the quantity and every effect. The terminal Battle outcome
later writes the remaining quantity to Run.

Run Scroll grants preflight total capacity before filling existing stacks and
then creating new stacks. They never silently discard or partially grant an
overflowing quantity.

## Reward Definitions

`RewardPoolDefinition` contains:

- Offer rule
- Option count
- Authored `RewardEntryDefinition` values

Each entry contains a typed payload, rarity, positive weight, floor bounds,
duplicate rule, price, and Reward-generation Conditions.

Implemented payload types are:

- Currency
- Art instance
- Relic instance
- Scroll quantity
- Unit recruitment
- Unit healing
- Art upgrade

The validator checks payload/type agreement, referenced content, values, floor
bounds, price usage, Conditions, and destination-free take-all pools.

## Deterministic Offer Generation

`RewardGenerationService` receives the current Run, pool, source, floor, Battle
rank, and generation index. It:

1. Filters every candidate by floor, Conditions, duplicate policy, inventory
   capacity, and current grantability.
2. Creates one deterministic random stream from Run seed, generation index, and
   pool content ID.
3. Selects from the filtered candidates by positive authored weights.
4. Stores fixed payload, rarity, price, and status in a `RewardOffer`.

An illegal candidate is never selected and redrawn. The generated offer is
stored in Run State, and reopening the view reads the same object.

For Battle `PICK_ONE` offers, `option_count` is the authored maximum. Generation
uses every currently eligible distinct payload up to that count, and an empty
result is an explicit successful no-offer outcome. Other offer sources still
require their configured count.

`TAKE_ALL` selection uses a duplicate Run simulation. Each selected payload is
granted to that simulation before the next candidate is evaluated, so team,
Scroll, Relic, and other cumulative limits are checked for the complete set.
Generation fails before storing an offer if the selected set cannot be granted
atomically.

Unlock filtering is intentionally deferred until the Phase 9 unlock system
defines its authoritative state.

## Offer Rules

- `PICK_ONE` grants one option, closes the others, clears the active offer, and
  returns the Run to `READY`.
- `TAKE_ALL` grants all destination-free options in one transaction. Generation
  has already verified the options cumulatively against the same Run rules.
- `PURCHASE_ANY` atomically spends Gold and grants each selected option. The
  offer remains active with per-option sold status until explicitly closed.

Healing and Art upgrades require a `RewardGrantDestination`. Art rewards may
optionally include an immediate installation destination; grant and installation
then share one transaction.

## Run Flow Phases

The implemented phases are:

- `READY`
- `IN_BATTLE`
- `CHOOSING_REWARD`
- `SHOPPING`
- `ENDED`

Run commands reject incompatible phases. The flow prevents simultaneous offers,
build changes during Battle, Battle entry from a shop, repeated outcome
application, and post-failure mutation.

## Debug Composition

`res://scenes/debug/run_debug.tscn` is a Chinese debug view for the complete v5
boundary:

```text
create Run
→ first Battle
→ enemy damage
→ Scroll victory
→ outcome writeback
→ choose and install Art
→ buy Relic and recruit Unit
→ second Battle
→ Relic trigger and new Art execution
```

The scene presents Run, Battle-copy, and Offer state in separate panels. It
contains no Reward, Battle, or inventory rules.

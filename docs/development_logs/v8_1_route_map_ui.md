# v8.1 Route Map UI

## Outcome

v8.1 replaces the functional Map list and its debug-style inspector with a
formal vertically climbing route Map. The implementation uses an original
parchment presentation while retaining the existing Map authority and Chinese
player interface.

## Route Generation

- Expanded the first route to thirteen regular layers followed by the Boss.
- Each regular layer deterministically contains two to four nodes.
- Distributed Battles, Elites, Events, Shops, Camps, and Chests through weighted
  layer ranges and copy limits.
- Replaced offset-based connections with an ordered non-crossing backbone.
- Limited optional edges to a sparse budget and at most two onward choices for
  regular nodes when the adjacent layer widths allow it.
- Preserved an incoming and outgoing connection for every node and a complete
  path from the start to the Boss.

## Presentation

- Removed the permanent information sidebar, layer guide lines, and permanent
  node names.
- Expanded the route canvas across the Map panel.
- Added compact node-kind symbols and short Chinese tooltips.
- Added parchment colors and subtle map marks using code-native drawing.
- Kept future routes muted, reachable choices gold, and the completed route
  teal.
- Kept automatic scrolling centered near the current node.
- Replaced the diagnostic Run title and counters with a compact Hero portrait,
  Gold, and Scroll-slot summary.
- Added right-aligned Map, current Build, and Settings actions.
- Added a read-only Map overlay for active node activities and kept Map entry
  validity derived from `MapReadModel`.
- Added fullscreen, Map-tooltip, and abandon-Run settings.
- Removed the permanent feedback footer and retained actionable failures as a
  temporary toast.
- Reduced node controls to icon scale, kept future nodes clear, strengthened
  only reachable outlines, and enlarged icons on hover.
- Added a Hero portrait field and used the existing project icon as a temporary
  Banner Captain placeholder.

## Boundaries

- `MapDefinition` remains the static source for layer bounds and node pools.
- `MapGenerationService` remains the only route topology generator.
- `MapState` remains the only source of saved nodes, connections, status, and
  current position.
- `MapRouteGraphView` consumes only detached `MapReadModel` facts.
- `MapPanelView` forwards only a selected runtime node ID.
- Header Scroll slots are rebuilt from detached `InventoryReadModel` state.
- Header and overlay toggles remain presentation state and do not duplicate
  `RunPhase` or Map progression.
- No Battle, Reward, Event, or Run transaction behavior changed.

## Validation

- Added repeated-seed checks for sparse edges, non-crossing connections, and
  limited onward choices.
- Added formal-scene checks for the long variable-width route and absence of the
  old information sidebar.
- Project suite: 752 assertions passed at implementation time.
- The formal Run scene rendered through the standalone X11 compatibility path.

## Deferred

- Production Map textures and authored node icon assets.
- Route transition animation and sound.
- Interactive top-bar detail popups.

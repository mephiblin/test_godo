# Task: Runtime map query helper

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` map/cell responsibility.
Goal: Move runtime map cell, blocking, vision, front placement, and path query logic into a dedicated helper while preserving existing scene/helper calls.

## P0
- Required item: map/cell blocking and vision checks move out of `grid_scene.gd`.
- Required item: placement runtime cell, front interaction placement, dungeon focus path, and visited-cell key logic move out of `grid_scene.gd`.
- Required item: existing helper calls such as `_is_blocked`, `_cell_hard_blocked`, `_cell_blocks_vision`, `_placement_runtime_cell`, `_front_interaction_placement`, and `_dungeon_path_to_cell` remain valid.

## P1
- Important item: preserve movement, field monster, minimap, interaction, and focus path behavior.
- Important item: avoid save schema, editor payload, imported manifest, or authored content changes.

## P2
- Optional/follow-up item: later move route-gate condition checks into a route runtime helper if the map query boundary remains stable.

## Scope
In:
- Runtime map/cell query helpers.
- Compatibility delegates in `grid_scene.gd`.

Out:
- Player movement orchestration.
- Interaction execution.
- UI layout.
- Content data changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/field_monster_runtime.gd`
- `scripts/runtime/dungeon_affordance_presenter.gd`
- `scripts/runtime/runtime_snapshot_builder.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer owns the large map query method bodies.
- Current movement, minimap, focus path, and interaction smoke flows still work.
- Relevant Godot boot/probe/smoke checks pass.

## Verification
- Command: Godot headless boot
- Result: Passed; exits 0.
- Command: validation probe
- Result: Passed; `VALIDATION definitions_ok=true map_ok=true`.
- Command: imported runtime probe
- Result: Passed; `IMPORTED_RUNTIME_PROBE ok=true manifest=res://data/imported/content_build_manifest.json slot=3`.
- Command: editor smoke
- Result: Passed; `imported_manifest_flow_ok=true`.
- Command: visual smoke
- Result: Passed; `SMOKE: done`, with floor3 movement/minimap/path-state capture inspected.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/runtime_map_query.gd`: Owns runtime map/cell blocking, vision, placement-cell, front-interaction, focus path, and visited-key helpers.
- `scripts/runtime/grid_scene.gd`: Keeps compatibility delegates for movement, minimap, focus path, field-monster, and smoke/helper callers.
- `docs/planning/next_implementation_priority.md`: Records the runtime map query cleanup.

## Follow-ups
- Remaining work: Later move route-gate condition checks into a route runtime helper if the map query boundary remains stable.

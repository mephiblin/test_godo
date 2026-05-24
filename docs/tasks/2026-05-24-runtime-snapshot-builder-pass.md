# Task: Runtime snapshot builder pass

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` HUD/minimap snapshot responsibility.
Goal: Move runtime HUD/minimap route, quest marker, and field monster snapshot helper logic into a dedicated runtime helper while preserving existing scene/test calls.

## P0
- Required item: route state, route summary, visible minimap placements, field monster snapshot/summary, visited keys, and quest marker key builders move out of `grid_scene.gd`.
- Required item: existing scene and smoke-driver methods continue working as delegates.

## P1
- Important item: preserve HUD/minimap dictionary shape.
- Important item: avoid gameplay/save/editor behavior changes.

## P2
- Optional/follow-up item: later move the whole `hud_snapshot()` construction if the helper proves stable.

## Scope
In:
- Runtime display/snapshot helpers.
- Existing minimap and objective marker data.

Out:
- UI layout.
- Interaction execution.
- Save schema changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/ui/grid_hud.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer owns the large minimap/route/quest marker helper bodies.
- Existing `_quest_target_keys`, `_quest_turn_in_keys`, and `_quest_seed_objective_keys` smoke calls still work.
- Relevant Godot boot/probe/smoke checks pass.

## Verification
- Command: Godot headless boot
- Result: Passed; exits 0.
- Command: validation probe
- Result: Passed; `VALIDATION definitions_ok=true map_ok=true`.
- Command: imported runtime probe
- Result: Passed; `IMPORTED_RUNTIME_PROBE ok=true manifest=res://data/imported/content_build_manifest.json slot=3`.
- Command: editor smoke
- Result: Passed; imported manifest flow succeeded.
- Command: visual smoke
- Result: Passed; `SMOKE: done`, with town and dungeon HUD/minimap captures inspected.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/runtime_snapshot_builder.gd`: Owns HUD/minimap route, field monster, visited-cell, and quest marker snapshot helpers.
- `scripts/runtime/grid_scene.gd`: Delegates existing snapshot helper methods to the builder.
- `docs/planning/next_implementation_priority.md`: Records this runtime responsibility cleanup.

## Follow-ups
- Remaining work: Consider moving the whole `hud_snapshot()` construction after the helper boundary remains stable.

# Task: Town focus wrapper direct pass

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` town-specific wrapper responsibility.
Goal: Route remaining town focus presentation and HUD callers through `town_focus_runtime` directly where the owner already exists.

## P0
- Required item: remove pass-through town focus wrapper methods from `grid_scene.gd` when callers can use `town_focus_runtime`.
- Required item: update town scene and town world presenter to use `town_focus_runtime` directly for focus snapshots, anchors, and paths.

## P1
- Important item: preserve town HUD focus data and focus anchor/path visuals.
- Important item: keep imported runtime/editor/game smoke checks passing.

## P2
- Optional/follow-up item: evaluate whether the remaining `_interaction_snapshot()` builder should move to a dedicated interaction snapshot presenter/runtime.

## Scope
In:
- Existing town focus runtime access paths.
- Existing town HUD and focus visual behavior.

Out:
- New town UI features.
- New authoring workflows.
- Combat or dungeon logic changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_focus_runtime.gd`
- `scripts/runtime/town_scene.gd`
- `scripts/runtime/town_world_presenter.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `town_scene.gd` no longer calls `_town_focus_snapshot()`.
- `town_world_presenter.gd` no longer calls `_town_interaction_anchor_cell()` or `_town_path_to_anchor()`.
- `grid_scene.gd` removes town focus wrapper methods that only forwarded to `town_focus_runtime`.
- Relevant Godot boot/probe/smoke checks pass.

## Verification
- Command: Godot headless boot
- Expected: exits 0
- Result: Passed.
- Command: validation probe
- Expected: validation succeeds
- Result: Passed. `VALIDATION definitions_ok=true map_ok=true`
- Command: imported runtime probe
- Expected: imported-only runtime boundary succeeds
- Result: Passed. `IMPORTED_RUNTIME_PROBE ok=true manifest=res://data/imported/content_build_manifest.json`
- Command: editor smoke
- Expected: editor/build/imported boundary checks succeed
- Result: Passed. `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: visual smoke
- Expected: title, town, dungeon, combat, reward, and editor fallback captures complete
- Result: Passed. Reached `SMOKE: done`; inspected `output/03_town.png` and `output/07_editor_fallback_town.png`.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/grid_scene.gd`: Removed remaining pass-through town focus wrapper methods and calls `town_focus_runtime` directly inside the interaction snapshot/focus refresh flow.
- `scripts/runtime/town_scene.gd`: Reads town focus HUD snapshot directly from `town_focus_runtime`.
- `scripts/runtime/town_world_presenter.gd`: Reads focus anchors and focus paths directly from `town_focus_runtime`.
- `docs/planning/next_implementation_priority.md`: Records this responsibility cleanup.

## Follow-ups
- Remaining work: Consider a dedicated interaction snapshot owner if `grid_scene.gd` remains the main mixed town/dungeon snapshot builder after the current wrapper cleanup.

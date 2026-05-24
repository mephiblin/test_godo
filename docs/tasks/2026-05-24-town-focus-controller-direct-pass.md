# Task: Town focus controller direct pass

Date: 2026-05-24
Request: Continue the Godot port cleanup by reducing generic runtime scene responsibility.
Goal: Move external town focus interaction callers away from `grid_scene.gd` private wrapper methods and onto the town focus runtime surface.

## P0
- Required item: `town_hub_controller.gd` must drive town focus movement, cycling, approach, and nearby lookup through `town_focus_runtime`.
- Required item: visual smoke town focus cycling must not call `grid_scene.gd` town focus wrapper methods.
- Required item: remove `grid_scene.gd` town focus wrappers that no longer have production or test callers.

## P1
- Important item: preserve town keyboard behavior and visual smoke coverage.
- Important item: keep editor/game data boundary checks passing.

## P2
- Optional/follow-up item: continue extracting remaining town interaction snapshot logic from `grid_scene.gd` if a clean owner emerges.

## Scope
In:
- Town focus controller/runtime dependency direction.
- Test-only visual smoke town focus cycling.

Out:
- New gameplay features.
- Event/NPC authoring expansion.
- Large interaction snapshot rewrite.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_hub_controller.gd`
- `scripts/runtime/town_focus_runtime.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `town_hub_controller.gd` no longer calls `_cycle_town_focus`, `_try_advance_town_focus_path`, `_try_approach_town_focus`, `_selected_town_focus_placement`, or `_town_nearby_interaction_placement` on the scene.
- `grid_scene_smoke_driver.gd` no longer calls `_cycle_town_focus`.
- `grid_scene.gd` no longer defines unused `_cycle_town_focus`, `_try_advance_town_focus_path`, or `_try_approach_town_focus` wrappers.
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
- Result: Passed. Reached `SMOKE: done`; inspected `output/03_town.png` and `output/04_dungeon.png`.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/grid_scene.gd`: Removed now-unused town focus pass-through wrappers.
- `scripts/runtime/town_hub_controller.gd`: Calls `town_focus_runtime` directly for focus advance, cycling, selected approach, and nearby fallback.
- `scripts/tests/grid_scene_smoke_driver.gd`: Uses `town_focus_runtime` directly for test-only focus cycling.
- `docs/planning/next_implementation_priority.md`: Records this responsibility cleanup.

## Follow-ups
- Remaining work: Continue reducing the remaining town interaction snapshot dependency in `grid_scene.gd` when a clean owner is available.

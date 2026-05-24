# Task: Dungeon world presenter pass

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` dungeon presentation responsibility.
Goal: Move dungeon floor/wall/ceiling, decor, material, and chunk overlay construction into a dedicated presenter while preserving current gameplay.

## P0
- Required item: dungeon world mesh/decor/chunk overlay build logic moves out of `grid_scene.gd`.
- Required item: `grid_scene.gd` delegates dungeon world build and active chunk label lookup to the presenter.

## P1
- Important item: preserve imported compiled dungeon visual smoke behavior.
- Important item: keep town build path unchanged through `town_world_presenter.gd`.

## P2
- Optional/follow-up item: move remaining dungeon marker focus visual refresh into a presenter only if it remains a practical blocker.

## Scope
In:
- Dungeon world floor/wall/ceiling construction.
- Dungeon decor placement.
- Compiled chunk/generated placement overlay.
- Surface material resolution for dungeon world meshes.

Out:
- Town world rendering.
- Field monster runtime behavior.
- Gameplay interaction logic.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/dungeon_affordance_presenter.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer owns the large dungeon world/decor/chunk overlay body.
- Dungeon visual smoke still captures floors 1-3, combat, and reward routes.
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
- Result: Passed. Reached `SMOKE: done`; inspected `output/04_dungeon.png` and `output/04_floor3.png`.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/dungeon_world_presenter.gd`: Owns dungeon floor/wall/ceiling, decor, material, and compiled chunk overlay construction.
- `scripts/runtime/grid_scene.gd`: Delegates dungeon world build and active chunk label lookup to the presenter.
- `docs/planning/next_implementation_priority.md`: Records this runtime responsibility cleanup.

## Follow-ups
- Remaining work: Continue reducing `grid_scene.gd` compatibility delegates where smoke/runtime callers can move to focused helpers safely.

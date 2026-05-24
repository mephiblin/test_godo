# Task: Field monster tick runtime pass

Date: 2026-05-24
Request: Continue Godot port cleanup by moving dungeon gameplay responsibility out of `grid_scene.gd`.
Goal: Move field monster runtime initialization, tick/update, pathing, LOS, and alert propagation into `field_monster_runtime.gd` while preserving the existing scene/test call surface.

## P0
- Required item: `field_monster_runtime.gd` owns field monster initialization and tick/update behavior.
- Required item: `grid_scene.gd` keeps only thin delegate methods for existing runtime/test callers.

## P1
- Important item: preserve patrol, ambush, warning, chase, give-up/return, alert group, LOS, and auto-combat behavior.
- Important item: keep imported runtime/editor/game smoke checks passing.

## P2
- Optional/follow-up item: later move field monster visual refresh into a presenter if it remains coupled to dungeon marker rendering.

## Scope
In:
- Field monster runtime state initialization.
- Field monster tick/update/pathing/LOS/alert logic.

Out:
- New field AI behavior.
- Save schema changes.
- Visual marker tuning.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/field_monster_runtime.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer contains the full field monster tick/update body.
- Existing `_tick_field_monsters()` and related smoke call surface still works as delegates.
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
- Result: Passed. Reached `SMOKE: done`; inspected `output/04_floor3.png` and `output/05_combat.png`.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/field_monster_runtime.gd`: Owns field monster initialization, tick/update, pathing, LOS, alert propagation, and auto-engage checks.
- `scripts/runtime/grid_scene.gd`: Keeps existing field monster method names as thin delegates for runtime and smoke-driver callers.
- `docs/planning/next_implementation_priority.md`: Records this runtime responsibility cleanup.

## Follow-ups
- Remaining work: Move field monster visual refresh into a presenter only if the dungeon marker rendering coupling becomes a practical blocker.

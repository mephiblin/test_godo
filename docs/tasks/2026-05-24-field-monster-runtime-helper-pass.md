# Task: Field monster runtime helper pass

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` dungeon runtime responsibility.
Goal: Move field monster AI configuration/state helper contracts into a dedicated runtime helper while preserving existing gameplay and smoke driver calls.

## P0
- Required item: field monster behavior/config/alert group/state-cell/marker color helper logic moves out of `grid_scene.gd`.
- Required item: existing `_field_ai_config`, `_field_ai_behavior`, `_field_alert_group_id`, `_field_monster_marker_color`, and `_state_cell` calls keep working through thin scene delegates.

## P1
- Important item: avoid changing field monster movement, detection, alert, or combat behavior.
- Important item: keep imported runtime/editor/game smoke checks passing.

## P2
- Optional/follow-up item: later move the full tick/update loop into the field monster runtime helper once the helper owns enough dependencies.

## Scope
In:
- Field monster helper contracts.
- Runtime responsibility cleanup.

Out:
- New field AI behavior.
- Data/schema changes.
- Visual tuning.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- A dedicated field monster runtime helper owns the helper contracts.
- `grid_scene.gd` delegates those contracts instead of implementing them inline.
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
- Result: Passed. Reached `SMOKE: done`; inspected `output/04_floor2.png` and `output/05_combat.png`.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/field_monster_runtime.gd`: Owns field monster AI config, behavior, alert group, patrol route/target, marker color, and state-cell helper contracts.
- `scripts/runtime/grid_scene.gd`: Initializes the helper and delegates the existing field monster helper call surface to it.
- `docs/planning/next_implementation_priority.md`: Records this runtime responsibility cleanup.

## Follow-ups
- Remaining work: Move the full field monster tick/update loop into the helper once pathing and blockage dependencies are narrow enough.

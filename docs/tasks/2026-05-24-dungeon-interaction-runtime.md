# Task: Dungeon interaction runtime

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` gameplay execution responsibility.
Goal: Move dungeon/town placement interaction execution bodies into a runtime helper while preserving existing scene and smoke-driver calls.

## P0
- Required item: placement interaction dispatch moves out of `grid_scene.gd`.
- Required item: route, combat, event, locked door, secret, loot, rest, and trap execution bodies move out of `grid_scene.gd`.
- Required item: existing `_trigger_interaction_placement`, `_route_from_placement`, `_enter_combat`, `_discover_secret`, `_trigger_event_placement`, and `_try_rest` calls remain valid.

## P1
- Important item: avoid save schema, imported manifest, editor payload, or UI behavior changes.
- Important item: keep service/inventory overlay ownership in the scene while interaction execution delegates through the helper.

## P2
- Optional/follow-up item: later remove private smoke-driver compatibility calls after test drivers target the helper directly.

## Scope
In:
- Runtime placement interaction execution.
- Compatibility delegates in `grid_scene.gd`.

Out:
- Interaction snapshot/preview text.
- Content data changes.
- Save schema changes.
- New gameplay features.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_hub_controller.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer owns the large placement execution method bodies.
- Existing visual/domain smoke call sites still work.
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
- Result: Passed; `SMOKE: done`, with combat and reward captures inspected.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/dungeon_interaction_runtime.gd`: Owns placement interaction dispatch and route/combat/event/door/secret/loot/rest/trap execution.
- `scripts/runtime/grid_scene.gd`: Keeps compatibility delegates for existing scene, UI, and smoke-driver callers.
- `docs/planning/next_implementation_priority.md`: Records the interaction execution cleanup.

## Follow-ups
- Remaining work: Later retarget smoke drivers to runtime helpers directly, then remove compatibility delegates where no production caller needs them.

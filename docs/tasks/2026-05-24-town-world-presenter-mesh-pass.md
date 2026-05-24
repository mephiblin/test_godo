# Task: Town World Presenter Mesh Pass

Date: 2026-05-24
Request:
Continue the Godot port by separating Game Runtime responsibilities, avoiding
new features, and improving real playability evidence.

Goal:
Move remaining town landmark and actor mesh construction out of
`grid_scene.gd` so town presentation lives in the town presenter while the
shared grid scene keeps runtime interaction state.

## P0
- Required item: keep town map world construction working.
- Required item: move town placement landmark, actor, campfire, gate, stall,
  table, crate, and ambient dressing mesh helpers into `town_world_presenter.gd`.
- Required item: keep placement interaction beacons and runtime colors owned by
  `grid_scene.gd`.

## P1
- Important item: preserve town visual smoke behavior and no editor/runtime data
  boundary changes.

## P2
- Optional/follow-up item: continue splitting remaining dungeon-specific
  affordance helpers from the shared grid scene.

## Scope
In:
- `grid_scene.gd`
- `town_world_presenter.gd`
- Task/backlog documentation

Out:
- New town features.
- Editor UI changes.
- Save data changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_world_presenter.gd`
- `scripts/runtime/town_scene.gd`

## Acceptance
- `grid_scene.gd` no longer contains town actor/landmark mesh construction
  helpers.
- Town visual smoke still renders the town hub world and interaction markers.
- Existing validation/imported runtime/editor smoke checks still pass.

## Verification
- Command: `Godot --headless --path . --quit`
- Expected: boot exits 0.
- Command: `Godot --headless --path . --script res://scripts/tests/imported_runtime_probe.gd`
- Expected: `IMPORTED_RUNTIME_PROBE ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/validation_probe.gd`
- Expected: `VALIDATION definitions_ok=true map_ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/editor_smoke.gd`
- Expected: `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR=output xvfb-run -a Godot --path . --smoke`
- Expected: title, town, dungeon, combat, reward, and editor fallback captures
  are written. Town/dungeon/editor fallback captures were visually checked.

## Result
- Status: Passed. Town mesh construction now lives in the town presenter, while
  `grid_scene.gd` retains placement beacon/runtime marker ownership.

## Files Changed
- `scripts/runtime/grid_scene.gd`: delegates town placement mesh construction
  to `town_world_presenter.gd` and keeps placement beacons.
- `scripts/runtime/town_world_presenter.gd`: owns town service landmarks,
  actors, gates, campfire, props, and ambient dressing mesh construction.
- `docs/tasks/2026-05-24-town-world-presenter-mesh-pass.md`: records scope,
  result, and verification.
- `docs/planning/next_implementation_priority.md`: marks town landmark/actor
  mesh extraction done.

## Follow-ups
- Remaining work: continue reducing generic dungeon-world assumptions from the
  town route after the next runtime boundary pass.

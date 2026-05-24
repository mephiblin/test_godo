# Task: Town Focus Visual Presenter Pass

Date: 2026-05-24
Request:
Continue the Godot port by separating runtime scene responsibilities without
adding new gameplay features.

Goal:
Move town focus anchor/path visual node construction and animation out of
`grid_scene.gd` into `town_world_presenter.gd`.

## P0
- Required item: keep town focus selection/path calculation in
  `town_focus_runtime.gd` and `grid_scene.gd` helper calls.
- Required item: move town focus anchor mesh/material/scale, path node
  construction, and anchor animation into `town_world_presenter.gd`.
- Required item: preserve town visual smoke behavior.

## P1
- Important item: avoid content, save, editor, or gameplay behavior changes.
- Important item: keep existing imported runtime and editor smoke checks
  passing.

## P2
- Optional/follow-up item: continue reducing generic dungeon-world assumptions
  from the town route.

## Scope
In:
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_world_presenter.gd`
- Task/backlog documentation.

Out:
- New town gameplay.
- Editor UI changes.
- Save schema changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_world_presenter.gd`
- `scripts/runtime/town_scene.gd`

## Acceptance
- `grid_scene.gd` no longer owns town focus anchor/path mesh construction.
- `town_world_presenter.gd` owns town focus visual nodes and animation.
- Town visual smoke still shows the focus UI and world markers.

## Verification
- Command: `Godot --headless --path . --quit`
- Expected: boot exits 0.
- Command: `Godot --headless --path . --script res://scripts/tests/validation_probe.gd`
- Expected: `VALIDATION definitions_ok=true map_ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/imported_runtime_probe.gd`
- Expected: `IMPORTED_RUNTIME_PROBE ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/editor_smoke.gd`
- Expected: `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/content_registry_contract_probe.gd`
- Expected: `CONTENT_REGISTRY_CONTRACT ok=true`
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR=output xvfb-run -a Godot --path . --smoke`
- Expected: title, town, dungeon, combat, reward, and editor fallback captures
  are written. Town focus/service and dungeon captures were visually checked.

## Result
- Status: Passed. Town focus anchor/path visual node construction and anchor
  animation now live in `town_world_presenter.gd`.

## Files Changed
- `scripts/runtime/grid_scene.gd`: delegates town focus visual updates to the
  town world presenter.
- `scripts/runtime/town_world_presenter.gd`: owns town focus anchor/path nodes,
  meshes, materials, scales, clearing, and anchor animation.
- `docs/tasks/2026-05-24-town-focus-visual-presenter-pass.md`: records scope,
  result, and verification.
- `docs/planning/next_implementation_priority.md`: updates current baseline and
  town runtime separation backlog.

## Follow-ups
- Remaining work: continue reducing generic dungeon-world assumptions from the
  town route.

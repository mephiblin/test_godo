# Task: Dungeon Focus Path Presenter Pass

Date: 2026-05-24
Request:
Continue the Godot port by tightening runtime scene responsibility boundaries
without adding new gameplay features.

Goal:
Move dungeon focus path visual node construction out of `grid_scene.gd` into
`dungeon_affordance_presenter.gd`, leaving pathfinding and interaction logic in
the runtime scene.

## P0
- Required item: keep dungeon pathfinding and interaction snapshot ownership in
  `grid_scene.gd`.
- Required item: move focus path marker sampling, color, mesh, height, scale,
  and node creation into `dungeon_affordance_presenter.gd`.
- Required item: preserve dungeon visual smoke behavior.

## P1
- Important item: avoid save/content/editor changes.
- Important item: keep imported runtime and editor smoke checks passing.

## P2
- Optional/follow-up item: evaluate whether town focus path visuals should move
  to a town focus presenter later.

## Scope
In:
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/dungeon_affordance_presenter.gd`
- Task/backlog documentation.

Out:
- New gameplay.
- Field monster AI changes.
- Editor UI changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/dungeon_affordance_presenter.gd`

## Acceptance
- `grid_scene.gd` computes the target path and delegates focus path rendering.
- `dungeon_affordance_presenter.gd` owns focus path node sampling and visuals.
- Visual smoke still captures dungeon focus/path affordances.

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
  are written. Dungeon floor 1/2/3 captures were visually checked.

## Result
- Status: Passed. Dungeon focus path sampling and marker node construction now
  live in `dungeon_affordance_presenter.gd`; `grid_scene.gd` only computes the
  gameplay path and delegates rendering.

## Files Changed
- `scripts/runtime/grid_scene.gd`: delegates dungeon focus path rendering after
  computing the target path.
- `scripts/runtime/dungeon_affordance_presenter.gd`: owns focus path marker
  sampling, color, mesh, height, scale, node creation, clearing, and animation.
- `docs/tasks/2026-05-24-dungeon-focus-path-presenter-pass.md`: records scope,
  result, and verification.
- `docs/planning/next_implementation_priority.md`: updates current baseline and
  dungeon affordance backlog.

## Follow-ups
- Remaining work: evaluate whether town focus path visuals should move to a
  town focus presenter later.

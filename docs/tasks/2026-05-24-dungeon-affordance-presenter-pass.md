# Task: Dungeon Affordance Presenter Pass

Date: 2026-05-24
Request:
Continue the Godot port by separating runtime scene responsibilities and
focusing on real game execution rather than adding new systems.

Goal:
Move dungeon placement/focus affordance presentation out of `grid_scene.gd` into
a dungeon-specific presenter while leaving dungeon gameplay and interaction
logic unchanged.

## P0
- Required item: move dungeon marker mesh, intent mesh, height, scale, ring, and
  animation presentation code into `dungeon_affordance_presenter.gd`.
- Required item: keep `grid_scene.gd` responsible for gameplay state,
  interaction snapshots, routes, and field monster logic.
- Required item: preserve imported runtime and visual smoke behavior.

## P1
- Important item: avoid changing content, save data, or authored map behavior.
- Important item: keep the change compatible with existing town presenter split.

## P2
- Optional/follow-up item: move dungeon focus path node construction into the
  presenter after pathfinding/query boundaries are cleaner.

## Scope
In:
- Dungeon affordance presenter.
- `grid_scene.gd` delegation.
- Task/backlog documentation.

Out:
- New dungeon gameplay.
- Combat changes.
- Editor UI changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_world_presenter.gd`

## Acceptance
- `grid_scene.gd` no longer owns the bulk of dungeon marker shape and animation
  implementation.
- Dungeon visual smoke still shows dungeon markers and focus affordances.
- Existing imported runtime and editor smoke checks pass.

## Verification
- Command: `Godot --headless --path . --quit`
- Expected: boot exits 0.
- Command: `Godot --headless --path . --script res://scripts/tests/validation_probe.gd`
- Expected: `VALIDATION definitions_ok=true map_ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/imported_runtime_probe.gd`
- Expected: `IMPORTED_RUNTIME_PROBE ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/content_registry_contract_probe.gd`
- Expected: `CONTENT_REGISTRY_CONTRACT ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/editor_smoke.gd`
- Expected: `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR=output xvfb-run -a Godot --path . --smoke`
- Expected: title, town, dungeon, combat, reward, and editor fallback captures
  are written. Dungeon floor 1/2 and town captures were visually checked.

## Result
- Status: Passed. Dungeon marker shape, focus marker, intent marker, ring, and
  affordance animation presentation now live in
  `dungeon_affordance_presenter.gd`.

## Files Changed
- `scripts/runtime/dungeon_affordance_presenter.gd`: added dungeon affordance
  presentation owner.
- `scripts/runtime/grid_scene.gd`: delegates dungeon placement/focus marker
  creation and affordance animation to the presenter.
- `docs/tasks/2026-05-24-dungeon-affordance-presenter-pass.md`: records scope,
  result, and verification.
- `docs/planning/next_implementation_priority.md`: updates current baseline and
  dungeon affordance backlog.

## Follow-ups
- Remaining work: move dungeon focus path node construction into the presenter
  once pathfinding/query boundaries are cleaner.

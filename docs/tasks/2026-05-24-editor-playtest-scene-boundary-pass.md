# Task: Editor Playtest Scene Boundary Pass

Date: 2026-05-24
Request:
Continue the Godot port by separating Editor tooling from Game Runtime and
keeping real runtime play based on imported content rather than editor state.

Goal:
Stop real town/dungeon runtime scenes from consuming editor test payloads by
moving editor custom play into explicit playtest scenes.

## P0
- Required item: keep `TownScene.tscn` and `DungeonScene.tscn` as normal runtime
  scenes that do not consume editor test payload by default.
- Required item: add editor-only playtest scenes that opt in to editor test
  payload consumption.
- Required item: keep the editor plugin Play Selected flow working through the
  playtest scenes.
- Required item: extend imported runtime probe to fail if the real runtime scene
  consumes editor test payload.

## P1
- Important item: preserve editor smoke compiled/authored handoff checks.
- Important item: avoid save data changes and avoid new gameplay features.

## P2
- Optional/follow-up item: move remaining smoke-only helpers out of production
  scene scripts when a dedicated test harness exists.

## Scope
In:
- Runtime scene payload gate.
- Editor playtest scenes.
- Editor plugin test-play target.
- Imported runtime probe.
- Task/backlog documentation.

Out:
- New editor authoring features.
- Gameplay behavior changes.
- Save schema changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `addons/connan_editor/plugin.gd`
- `scripts/tests/imported_runtime_probe.gd`
- `scripts/tests/editor_smoke.gd`

## Acceptance
- Real `DungeonScene.tscn` ignores pending editor test payload.
- Editor playtest scenes can still receive editor test payload.
- Imported runtime, editor smoke, validation, and visual smoke pass.

## Verification
- Command: `Godot --headless --path . --script res://scripts/tests/imported_runtime_probe.gd`
- Expected: `IMPORTED_RUNTIME_PROBE ok=true`
- Command: `Godot --headless --path . --quit`
- Expected: boot exits 0.
- Command: `Godot --headless --path . --script res://scripts/tests/validation_probe.gd`
- Expected: `VALIDATION definitions_ok=true map_ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/content_registry_contract_probe.gd`
- Expected: `CONTENT_REGISTRY_CONTRACT ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/editor_smoke.gd`
- Expected: `EDITOR_SMOKE ... compiled_handoff=true authored_handoff=true`
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR=output xvfb-run -a Godot --path . --smoke`
- Expected: title, town, dungeon, combat, reward, and editor fallback captures
  are written. Town, dungeon, and combat captures were visually checked.

## Result
- Status: Passed. Production town/dungeon scenes no longer opt in to editor
  test payload, and editor custom play now uses explicit playtest scenes.

## Files Changed
- `scripts/runtime/grid_scene.gd`: added opt-in gate for editor test payload.
- `scenes/editor_tools/PlaytestTownScene.tscn`: added editor-only town
  playtest scene.
- `scenes/editor_tools/PlaytestDungeonScene.tscn`: added editor-only dungeon
  playtest scene.
- `addons/connan_editor/plugin.gd`: targets playtest scenes for editor custom
  play.
- `scripts/tests/imported_runtime_probe.gd`: asserts real `DungeonScene.tscn`
  ignores pending editor test payload.
- `scripts/tests/editor_smoke.gd`: validates compiled/authored handoff through
  the playtest dungeon scene.
- `docs/tasks/2026-05-24-editor-playtest-scene-boundary-pass.md`: records
  result and verification.
- `docs/planning/next_implementation_priority.md`: updates current baseline and
  editor/runtime boundary backlog.

## Follow-ups
- Remaining work: move remaining smoke-only methods out of production scene
  scripts after a dedicated test harness exists.

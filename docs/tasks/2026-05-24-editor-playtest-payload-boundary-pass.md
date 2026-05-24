# Task: Editor playtest payload boundary pass

Date: 2026-05-24
Request:
Continue the Godot port cleanup by keeping editor draft/playtest payload state out of the real game app state.
Goal:
Move editor custom-play payload storage from `GameApp` into an editor-tool bridge used only by explicit playtest scenes.

## P0
- Required item: remove `editor_test_payload` storage and accessors from `scripts/autoload/game_app.gd`.
- Required item: route editor plugin custom play and playtest scenes through a separate editor-tool bridge.
- Required item: keep real town/dungeon runtime scenes from consuming editor playtest payload.

## P1
- Important item: verify imported runtime probe still proves real runtime ignores editor playtest payload.
- Important item: verify editor smoke and visual smoke still pass.
- Important item: update current implementation priority notes.

## P2
- Optional/follow-up item: keep evaluating whether editor-only bridge autoload should be replaced by a custom resource handoff later.

## Scope
In:
- Editor playtest payload handoff boundary.
- Explicit playtest scene setup path.
- Tests and docs tied to that boundary.

Out:
- Gameplay save/runtime behavior changes.
- New editor features.
- Unrelated Godot `.uid` cleanup.

## Files To Inspect
- `scripts/autoload/game_app.gd`
- `scripts/runtime/grid_scene.gd`
- `addons/connan_editor/plugin.gd`
- `scripts/tests/imported_runtime_probe.gd`
- `scripts/tests/editor_smoke.gd`
- `project.godot`

## Acceptance
- `GameApp` no longer stores editor playtest payload.
- Only `allow_editor_test_payload=true` playtest scenes consume the editor playtest bridge.
- Real runtime scene probe confirms the bridge payload remains unconsumed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Result: Passed; `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/imported_runtime_probe.gd`
- Result: Passed; `IMPORTED_RUNTIME_PROBE ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Result: Passed; editor smoke reported all core checks true.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Result: Passed; visual smoke reached `SMOKE: done`.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/editor_tools/editor_playtest_bridge.gd`: added editor-tool payload bridge for explicit custom play scenes.
- `project.godot`: registered `EditorPlaytestBridge` autoload.
- `scripts/autoload/game_app.gd`: removed editor playtest payload storage/accessors.
- `scripts/runtime/grid_scene.gd`: consumes playtest payload only through the bridge when explicitly allowed.
- `addons/connan_editor/plugin.gd`: writes custom play payload to the bridge.
- `scripts/tests/imported_runtime_probe.gd`: verifies real runtime scenes do not consume bridge payload.
- `scripts/tests/editor_smoke.gd`: uses the bridge for playtest scene handoff checks.
- `docs/planning/next_implementation_priority.md`: recorded the boundary cleanup.

## Follow-ups
- Remaining work: continue reducing production runtime dependencies on editor/test helpers.

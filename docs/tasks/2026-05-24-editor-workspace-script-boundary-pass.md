# Task: Editor workspace script boundary pass

Date: 2026-05-24
Request:
Continue the Godot port cleanup by keeping editor tooling files outside the game runtime script tree.
Goal:
Move the fallback editor workspace script from `scripts/runtime` to an editor-tool script location and update direct references.

## P0
- Required item: move `scripts/runtime/editor_workspace.gd` out of runtime.
- Required item: update `EditorWorkspace.tscn` and tests to use the new editor-tool path.

## P1
- Important item: verify Godot boot, validation, imported runtime, editor smoke, and visual smoke still pass.
- Important item: update current implementation priority notes.

## P2
- Optional/follow-up item: keep scanning for editor/test files that still live under runtime naming.

## Scope
In:
- EditorWorkspace script file location.
- Scene and smoke preload references.
- Task and priority documentation.

Out:
- Editor fallback UX changes.
- Gameplay runtime behavior changes.
- Unrelated Godot `.uid` cleanup.

## Files To Inspect
- `scenes/editor_tools/EditorWorkspace.tscn`
- `scripts/editor_tools/editor_workspace.gd`
- `scripts/tests/editor_smoke.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- No tracked scene/test reference points to `res://scripts/runtime/editor_workspace.gd`.
- The editor fallback workspace still loads and passes smoke checks.
- Runtime script tree no longer contains the editor workspace script.

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
- `scripts/editor_tools/editor_workspace.gd`: moved fallback editor workspace script out of runtime.
- `scripts/editor_tools/editor_workspace.gd.uid`: moved matching Godot UID with the script.
- `scenes/editor_tools/EditorWorkspace.tscn`: updated script resource path.
- `scripts/tests/editor_smoke.gd`: updated preload path.
- `docs/planning/next_implementation_priority.md`: recorded the boundary cleanup.
- `docs/tasks/2026-05-24-editor-fallback-smoke-driver-pass.md`: updated current path reference.

## Follow-ups
- Remaining work: continue separating editor-only tooling and test-only drivers from production runtime files.

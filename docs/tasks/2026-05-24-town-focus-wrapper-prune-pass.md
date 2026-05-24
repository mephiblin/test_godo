# Task: Town focus wrapper prune pass

Date: 2026-05-24
Request:
Continue the Godot port cleanup by reducing town-only wrapper surface on the generic grid scene.
Goal:
Remove unused town focus pass-through wrappers from `grid_scene.gd`.

## P0
- Required item: remove town focus wrappers that no current runtime/test path calls.
- Required item: keep town focus, town hub, dungeon, editor, and smoke behavior unchanged.

## P1
- Important item: verify Godot boot, validation, imported runtime, editor smoke, and visual smoke still pass.
- Important item: update current implementation priority notes.

## P2
- Optional/follow-up item: continue moving still-used town focus calls from `grid_scene.gd` into town-owned runtime/controller surfaces.

## Scope
In:
- Unused town focus wrapper cleanup.
- Task and priority documentation.

Out:
- New town focus behavior.
- Dungeon interaction behavior changes.
- Unrelated Godot `.uid` cleanup.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_focus_runtime.gd`
- `scripts/runtime/town_hub_controller.gd`
- `scripts/runtime/town_world_presenter.gd`

## Acceptance
- Removed wrappers have no remaining references.
- Existing smoke checks continue to pass.

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
- `scripts/runtime/grid_scene.gd`: removed unused town focus pass-through wrappers.
- `docs/planning/next_implementation_priority.md`: recorded the responsibility cleanup.

## Follow-ups
- Remaining work: still-used town focus wrappers can be reduced in a later pass if the caller is moved to town-specific code.

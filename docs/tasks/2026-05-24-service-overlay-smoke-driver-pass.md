# Task: Service overlay smoke driver pass

Date: 2026-05-24
Request:
Continue the Godot port cleanup by keeping editor/test helpers out of real game runtime UI.
Goal:
Move the remaining service overlay smoke-only service selector out of the production overlay and into a test-only smoke driver.

## P0
- Required item: remove `smoke_select_service_type()` from `scripts/ui/service_overlay.gd`.
- Required item: keep visual smoke coverage for NPC service selection through a test-only driver.

## P1
- Important item: verify imported/runtime/editor smoke still pass after the boundary cleanup.
- Important item: update the current implementation priority notes.

## P2
- Optional/follow-up item: continue scanning for public smoke/debug methods in production runtime surfaces.

## Scope
In:
- Service overlay smoke helper boundary.
- Visual smoke NPC service selection call sites.
- Task and priority documentation.

Out:
- New gameplay services.
- Editor dock feature expansion.
- Unrelated Godot `.uid` cleanup.

## Files To Inspect
- `scripts/ui/service_overlay.gd`
- `scripts/ui/main_root.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Production service overlay no longer exposes a smoke-only service selection method.
- Visual smoke can still select gatekeeper and scholar NPC services through a test-only driver.
- Relevant Godot smoke/probe checks pass.

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
- `scripts/ui/service_overlay.gd`: removed the production smoke-only service selector.
- `scripts/ui/main_root.gd`: routed visual smoke NPC service selection through a test driver.
- `scripts/tests/service_overlay_smoke_driver.gd`: added a test-only service selector.
- `docs/planning/next_implementation_priority.md`: recorded the boundary cleanup.

## Follow-ups
- Remaining work: continue reducing production runtime/editor-test coupling where current-state scans find it.

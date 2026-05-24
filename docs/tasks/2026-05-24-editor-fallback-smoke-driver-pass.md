# Task: Editor fallback smoke driver pass

Date: 2026-05-24
Request:
Continue the Godot port cleanup by keeping editor/test workspace manipulation out of the real app root.
Goal:
Move editor fallback route-preview workspace smoke logic out of `scripts/ui/main_root.gd` into a test-only driver while preserving visual capture support.

## P0
- Required item: remove `_capture_editor_fallback_snapshot()` and `_fallback_variant_contains()` from `scripts/ui/main_root.gd`.
- Required item: keep save migration, benchmark, content import, and visual smoke fallback preview checks intact.

## P1
- Important item: verify Godot boot, validation, imported runtime, editor smoke, content import smoke, save migration smoke, benchmark smoke, and visual smoke still pass.
- Important item: update current implementation priority notes.

## P2
- Optional/follow-up item: continue scanning production runtime roots for smoke-only helper methods after this pass.

## Scope
In:
- Editor fallback workspace smoke helper boundary.
- Main root smoke driver wiring.
- Task and priority documentation.

Out:
- Editor preview feature changes.
- Gameplay route behavior changes.
- Unrelated Godot `.uid` cleanup.

## Files To Inspect
- `scripts/ui/main_root.gd`
- `scripts/editor_tools/editor_workspace.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Main root no longer owns editor fallback workspace smoke manipulation or variant text assertions.
- Smoke flows still verify editor fallback route preview variants.
- Visual smoke can still capture editor fallback screens.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Result: Passed; `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/imported_runtime_probe.gd`
- Result: Passed; `IMPORTED_RUNTIME_PROBE ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Result: Passed; editor smoke reported all core checks true.
- Command: `CONAN_DOT_CONTENT_IMPORT_SMOKE=1 "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Result: Passed; `CONTENT_IMPORT_SMOKE ok=true`.
- Command: `CONAN_DOT_SAVE_MIGRATION_SMOKE=1 "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Result: Passed; `SAVE_MIGRATION_SMOKE legacy_ok=true future_ok=true`.
- Command: `CONAN_DOT_BENCHMARK_SMOKE=1 xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan`
- Result: Passed; `BENCHMARK_SMOKE ok=true`.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Result: Passed; visual smoke reached `SMOKE: done`.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/ui/main_root.gd`: removed editor fallback workspace smoke manipulation and variant assertion helpers.
- `scripts/tests/editor_fallback_smoke_driver.gd`: added test-only fallback route-preview smoke support with optional capture callback.
- `docs/planning/next_implementation_priority.md`: recorded the boundary cleanup.

## Follow-ups
- Remaining work: continue removing production runtime test-only surfaces where current-state scans find them.

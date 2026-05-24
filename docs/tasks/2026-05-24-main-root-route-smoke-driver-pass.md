# Task: Main root route smoke driver pass

Date: 2026-05-24
Request:
Continue the Godot port cleanup by keeping smoke/debug runtime probes out of real game UI/root surfaces.
Goal:
Move domain-smoke route snapshot and transition helpers out of `scripts/ui/main_root.gd` into a test-only driver.

## P0
- Required item: remove `_debug_route_snapshot()` and `_debug_route_transition()` from `scripts/ui/main_root.gd`.
- Required item: keep domain smoke route-gate and HUD snapshot coverage intact through a test-only driver.

## P1
- Important item: verify Godot boot, validation, imported runtime, domain smoke, and visual smoke still pass.
- Important item: update current implementation priority notes.

## P2
- Optional/follow-up item: move editor fallback smoke capture support out of `main_root.gd` in a later pass if it can stay screenshot-capable.

## Scope
In:
- Domain smoke route snapshot/transition helper boundary.
- Main root smoke driver wiring.
- Task and priority documentation.

Out:
- Gameplay route behavior changes.
- Editor fallback preview capture refactor.
- Unrelated Godot `.uid` cleanup.

## Files To Inspect
- `scripts/ui/main_root.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Main root no longer owns route debug scene-instantiation helpers.
- Domain smoke still verifies route snapshots/transitions using imported compiled runtime data.
- Relevant smoke/probe checks pass.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Result: Passed; `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/imported_runtime_probe.gd`
- Result: Passed; `IMPORTED_RUNTIME_PROBE ok=true`.
- Command: `CONAN_DOT_DOMAIN_SMOKE=1 "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Result: Passed; `DOMAIN_SMOKE ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Result: Passed; editor smoke reported all core checks true.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Result: Passed; visual smoke reached `SMOKE: done`.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/ui/main_root.gd`: removed direct route debug helper implementations and calls into a test driver.
- `scripts/tests/route_smoke_driver.gd`: added test-only route snapshot/transition probe support.
- `docs/planning/next_implementation_priority.md`: recorded the boundary cleanup.

## Follow-ups
- Remaining work: inspect whether editor fallback smoke capture support should be extracted without weakening screenshot verification.

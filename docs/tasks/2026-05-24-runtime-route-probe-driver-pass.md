# Task: Runtime Route Probe Driver Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 Game Runtime에 test/debug helper가 섞이지 않도록 점검한다.
Goal: domain smoke 전용 route transition probe를 production `grid_scene.gd` public API에서 제거하고 test driver로 이동한다.

## P0
- Required item: `grid_scene.gd`의 `smoke_probe_route_to_map()`을 제거한다.
- Required item: domain smoke의 `_debug_route_transition()`은 test-only `grid_scene_smoke_driver.gd`로 route 상태를 검사한다.

## P1
- Important item: route blocked/unblocked 판정 결과는 유지한다.
- Important item: imported runtime and visual smoke checks still pass.

## P2
- Optional/follow-up item: field monster AI/LOS/secret-door `smoke_probe_*` helpers를 별도 domain probe harness로 이동한다.

## Scope
In:
- `scripts/runtime/grid_scene.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

Out:
- Gameplay route behavior 변경
- Field monster/secret door probe 이동
- Combat smoke/debug API 정리

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer exposes `smoke_probe_route_to_map`.
- Domain smoke still validates route gating before/after quest progression.
- Core headless/runtime/editor/visual checks still pass.

## Verification
- Command: Godot headless boot
- Expected: exits 0
- Result: Pass
- Command: domain smoke
- Expected: exits 0 and writes a domain report with route checks
- Result: Pass; reports `DOMAIN_SMOKE ok=true`
- Command: `res://scripts/tests/validation_probe.gd`
- Expected: exits 0 and reports validation ok
- Result: Pass; reports `VALIDATION definitions_ok=true map_ok=true`
- Command: `res://scripts/tests/imported_runtime_probe.gd`
- Expected: exits 0 and reports imported runtime ok
- Result: Pass; reports `IMPORTED_RUNTIME_PROBE ok=true`
- Command: `res://scripts/tests/editor_smoke.gd`
- Expected: exits 0 and keeps editor/game boundary checks green
- Result: Pass; reports `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: visual smoke
- Expected: exits 0 and captures gameplay screenshots
- Result: Pass; captured town, dungeon, combat, reward, and editor fallback screenshots.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Pass

## Result
- Status: Implemented

## Files Changed
- `scripts/runtime/grid_scene.gd`: Removed `smoke_probe_route_to_map()` from the runtime scene public API.
- `scripts/tests/grid_scene_smoke_driver.gd`: Added `route_probe()` for domain smoke route gate checks.
- `scripts/ui/main_root.gd`: Uses the smoke driver for `_debug_route_transition()`.
- `docs/planning/next_implementation_priority.md`: Records the route probe driver pass.
- `docs/tasks/2026-05-24-runtime-route-probe-driver-pass.md`: Tracks scope, verification, and result.

## Follow-ups
- Remaining work: `grid_scene.gd` still exposes field monster and secret-door `smoke_probe_*` helpers.

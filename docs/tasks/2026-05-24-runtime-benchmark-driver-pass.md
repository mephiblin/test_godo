# Task: Runtime Benchmark Driver Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 Game Runtime에 test/debug helper가 섞이지 않도록 점검한다.
Goal: benchmark smoke 전용 snapshot helper를 production `grid_scene.gd` public API에서 제거하고 test driver로 이동한다.

## P0
- Required item: `grid_scene.gd`의 `debug_benchmark_snapshot()`을 제거한다.
- Required item: benchmark smoke는 test-only `grid_scene_smoke_driver.gd`를 통해 동일한 snapshot을 수집한다.

## P1
- Important item: benchmark smoke의 route/move/combat 검증은 유지한다.
- Important item: visual smoke와 imported runtime 검증은 변경 없이 통과해야 한다.

## P2
- Optional/follow-up item: domain smoke의 `smoke_probe_*` field monster/route probes를 별도 harness로 분리한다.

## Scope
In:
- `scripts/runtime/grid_scene.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

Out:
- Gameplay behavior 변경
- AI/LOS/secret-door probe 이동
- Combat runtime debug API 정리

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer exposes `debug_benchmark_snapshot`.
- `CONAN_DOT_BENCHMARK_SMOKE=1` still reports `BENCHMARK_SMOKE ok=true`.
- Core headless/runtime/editor/visual checks still pass.

## Verification
- Command: Godot headless boot
- Expected: exits 0
- Result: Pass
- Command: `res://scripts/tests/validation_probe.gd`
- Expected: exits 0 and reports validation ok
- Result: Pass; reports `VALIDATION definitions_ok=true map_ok=true`
- Command: `res://scripts/tests/imported_runtime_probe.gd`
- Expected: exits 0 and reports imported runtime ok
- Result: Pass; reports `IMPORTED_RUNTIME_PROBE ok=true`
- Command: `res://scripts/tests/editor_smoke.gd`
- Expected: exits 0 and keeps editor/game boundary checks green
- Result: Pass; reports `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: benchmark smoke
- Expected: exits 0 and reports `BENCHMARK_SMOKE ok=true`
- Result: Pass; reports `BENCHMARK_SMOKE ok=true`
- Command: visual smoke
- Expected: exits 0 and captures gameplay screenshots
- Result: Pass; captured town, dungeon, combat, reward, and editor fallback screenshots.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Pass

## Result
- Status: Implemented

## Files Changed
- `scripts/runtime/grid_scene.gd`: Removed `debug_benchmark_snapshot()` from the runtime scene public API.
- `scripts/tests/grid_scene_smoke_driver.gd`: Added `benchmark_snapshot()` for benchmark-only state capture.
- `scripts/ui/main_root.gd`: Reads benchmark dungeon snapshots through the test driver.
- `docs/planning/next_implementation_priority.md`: Records the benchmark driver pass.
- `docs/tasks/2026-05-24-runtime-benchmark-driver-pass.md`: Tracks scope, verification, and result.

## Follow-ups
- Remaining work: `grid_scene.gd` still exposes complex domain `smoke_probe_*` helpers.

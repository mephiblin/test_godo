# Task: Runtime Smoke Driver Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 Game Runtime에 editor/test helper가 섞이지 않도록 점검한다.
Goal: `grid_scene.gd`의 단순 visual smoke 조작 API를 테스트 전용 driver로 옮겨 production scene의 public smoke 표면을 줄인다.

## P0
- Required item: visual/benchmark smoke가 town/dungeon scene의 단순 `smoke_*` action 메서드를 직접 요구하지 않는다.
- Required item: `grid_scene.gd`에서 quest accept, route, event trigger, inventory/service open, combat enter 같은 단순 smoke action wrappers를 제거한다.

## P1
- Important item: 기존 imported manifest 기반 town -> dungeon -> combat -> reward smoke 루프는 유지한다.
- Important item: 복잡한 AI/route probe류는 이번 변경에서 무리하게 옮기지 않고 후속 작업으로 분리한다.

## P2
- Optional/follow-up item: domain smoke의 field monster probe와 benchmark snapshot도 별도 테스트 harness로 이동한다.

## Scope
In:
- `scripts/tests/grid_scene_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `scripts/runtime/grid_scene.gd`
- `docs/planning/next_implementation_priority.md`

Out:
- Runtime gameplay behavior 변경
- Combat smoke/debug API 정리
- Field monster/domain probe 정리

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/ui/main_root.gd`
- `scripts/tests`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- visual smoke still captures the full play loop.
- benchmark smoke can still drive route/move/combat actions.
- `grid_scene.gd` no longer exposes the migrated simple smoke action methods.

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
- Expected: exits 0 and keeps editor/game file boundary checks green
- Result: Pass; reports `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: visual smoke
- Expected: exits 0 and captures gameplay screenshots
- Result: Pass; captures title, town, dungeon, combat, reward, and editor fallback screenshots.
- Command: benchmark smoke
- Expected: exits 0 and writes benchmark report
- Result: Pass; reports `BENCHMARK_SMOKE ok=true`
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Pass

## Result
- Status: Implemented

## Files Changed
- `scripts/tests/grid_scene_smoke_driver.gd`: Added a test-only driver for simple grid scene smoke actions.
- `scripts/ui/main_root.gd`: Uses the smoke driver in visual and benchmark smoke, loaded only when smoke code runs.
- `scripts/runtime/grid_scene.gd`: Removed migrated simple smoke action wrappers from the runtime scene.
- `docs/planning/next_implementation_priority.md`: Recorded the runtime smoke driver pass.
- `docs/tasks/2026-05-24-runtime-smoke-driver-pass.md`: Tracks scope, verification, and result.

## Follow-ups
- Remaining work: complex `smoke_probe_*` and `debug_benchmark_snapshot` methods still live on runtime scenes.

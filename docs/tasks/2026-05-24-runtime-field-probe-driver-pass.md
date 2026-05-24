# Task: Runtime Field Probe Driver Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 Game Runtime에 test/debug helper가 섞이지 않도록 점검한다.
Goal: field monster/secret-door domain probes를 production `grid_scene.gd` public API에서 제거하고 test-only smoke driver로 이동한다.

## P0
- Required item: `grid_scene.gd`의 남은 `smoke_probe_*` public methods를 제거한다.
- Required item: domain smoke는 `grid_scene_smoke_driver.gd`를 통해 field monster AI, LOS, door, secret-door probes를 실행한다.

## P1
- Important item: 기존 domain smoke 결과와 route/combat/play smoke는 유지한다.
- Important item: gameplay behavior는 변경하지 않는다.

## P2
- Optional/follow-up item: smoke driver가 내부 scene methods를 많이 호출하는 구조를 추후 dedicated domain harness로 더 정리한다.

## Scope
In:
- `scripts/runtime/grid_scene.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

Out:
- Runtime gameplay behavior 변경
- Combat runtime smoke/debug API 정리
- Editor authoring 기능 추가

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer exposes public `smoke_probe_*` methods.
- Domain smoke still passes.
- Core imported/editor/visual checks still pass.

## Verification
- Command: Godot headless boot
- Expected: exits 0
- Result: Pass
- Command: domain smoke
- Expected: exits 0 and reports `DOMAIN_SMOKE ok=true`
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
- `scripts/runtime/grid_scene.gd`: Removed remaining public field monster and secret-door `smoke_probe_*` helpers.
- `scripts/tests/grid_scene_smoke_driver.gd`: Added test-only field monster AI, LOS, door, and secret-door probes.
- `scripts/ui/main_root.gd`: Runs domain smoke probes through the test driver instead of runtime scene public methods.
- `docs/planning/next_implementation_priority.md`: Records the field probe driver pass.
- `docs/tasks/2026-05-24-runtime-field-probe-driver-pass.md`: Tracks scope, verification, and result.

## Follow-ups
- Remaining work: consider moving smoke driver internals into a dedicated `field_monster_domain_probe.gd` if more domain probes are added.

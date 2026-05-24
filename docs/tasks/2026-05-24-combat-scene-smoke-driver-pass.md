# Task: Combat Scene Smoke Driver Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 Game Runtime에 test/debug helper가 섞이지 않도록 점검한다.
Goal: `CombatScene`의 public smoke/debug wrappers를 제거하고 visual/domain/benchmark smoke가 test-only driver를 통해 combat scene runtime을 조작한다.

## P0
- Required item: `combat_scene.gd`의 public `smoke_*` and `debug_*` wrappers를 제거한다.
- Required item: `main_root.gd` smoke paths use a test-only combat smoke driver instead of calling those scene methods.

## P1
- Important item: combat runtime behavior and presenter behavior remain unchanged.
- Important item: visual smoke still completes combat victory/defeat/reward loops.

## P2
- Optional/follow-up item: move `combat_runtime.gd` smoke/debug domain probes into the test driver or a dedicated domain probe.

## Scope
In:
- `scripts/runtime/combat_scene.gd`
- `scripts/tests/combat_smoke_driver.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

Out:
- Combat rules 변경
- Combat runtime internal probe method migration
- UI redesign

## Files To Inspect
- `scripts/runtime/combat_scene.gd`
- `scripts/runtime/combat_runtime.gd`
- `scripts/ui/main_root.gd`
- `scripts/tests`

## Acceptance
- `combat_scene.gd` no longer exposes public smoke/debug wrapper methods.
- Domain, benchmark, and visual smoke still pass.
- Core imported/editor validation still passes.

## Verification
- Command: Godot headless boot
- Expected: exits 0
- Result: Pass
- Command: domain smoke
- Expected: exits 0 and reports `DOMAIN_SMOKE ok=true`
- Result: Pass; reports `DOMAIN_SMOKE ok=true`
- Command: benchmark smoke
- Expected: exits 0 and reports `BENCHMARK_SMOKE ok=true`
- Result: Pass; reports `BENCHMARK_SMOKE ok=true`
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
- `scripts/runtime/combat_scene.gd`: Removed public smoke/debug wrapper methods from the production scene.
- `scripts/tests/combat_smoke_driver.gd`: Added a test-only driver for combat scene victory, defeat, item use, and debug/probe access.
- `scripts/ui/main_root.gd`: Uses the combat smoke driver in domain, visual, and benchmark smoke flows.
- `docs/planning/next_implementation_priority.md`: Records the combat scene smoke driver pass.
- `docs/tasks/2026-05-24-combat-scene-smoke-driver-pass.md`: Tracks scope, verification, and result.

## Follow-ups
- Remaining work: `combat_runtime.gd` still contains smoke/debug probe methods for direct domain tests.

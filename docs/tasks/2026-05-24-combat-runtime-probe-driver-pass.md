# Task: Combat Runtime Probe Driver Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 Game Runtime에 test/debug helper가 섞이지 않도록 점검한다.
Goal: `combat_runtime.gd`의 smoke/debug probe methods를 test-only `combat_smoke_driver.gd`로 이동한다.

## P0
- Required item: `combat_runtime.gd`의 `smoke_*` and `debug_*` probe methods를 제거한다.
- Required item: domain smoke and direct combat domain probe use `combat_smoke_driver.gd`.

## P1
- Important item: combat runtime gameplay API remains unchanged for real input flow.
- Important item: combat scene, visual smoke, benchmark smoke, and imported runtime checks still pass.

## P2
- Optional/follow-up item: split `combat_smoke_driver.gd` into smaller domain probe files if it grows further.

## Scope
In:
- `scripts/runtime/combat_runtime.gd`
- `scripts/tests/combat_smoke_driver.gd`
- `scripts/tests/combat_domain_probe.gd`
- `scripts/ui/main_root.gd`
- `docs/planning/next_implementation_priority.md`

Out:
- Combat rule changes
- Combat HUD redesign
- New gameplay systems

## Files To Inspect
- `scripts/runtime/combat_runtime.gd`
- `scripts/tests/combat_smoke_driver.gd`
- `scripts/tests/combat_domain_probe.gd`
- `scripts/ui/main_root.gd`

## Acceptance
- `combat_runtime.gd` no longer exposes public `smoke_*` or `debug_*` probe methods.
- `COMBAT_DOMAIN_PROBE`, domain smoke, benchmark smoke, and visual smoke still pass.

## Verification
- Command: Godot headless boot
- Expected: exits 0
- Result: Pass
- Command: `res://scripts/tests/combat_domain_probe.gd`
- Expected: exits 0 and reports `COMBAT_DOMAIN_PROBE ok=true`
- Result: Pass
- Command: domain smoke
- Expected: exits 0 and reports `DOMAIN_SMOKE ok=true`
- Result: Pass
- Command: benchmark smoke
- Expected: exits 0 and reports `BENCHMARK_SMOKE ok=true`
- Result: Pass
- Command: `res://scripts/tests/validation_probe.gd`
- Expected: exits 0 and reports validation ok
- Result: Pass
- Command: `res://scripts/tests/imported_runtime_probe.gd`
- Expected: exits 0 and reports imported runtime ok
- Result: Pass
- Command: `res://scripts/tests/editor_smoke.gd`
- Expected: exits 0 and keeps editor/game boundary checks green
- Result: Pass
- Command: visual smoke
- Expected: exits 0 and captures gameplay screenshots
- Result: Pass; combat screenshot inspected.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Pending

## Result
- Status: Implemented

## Files Changed
- `scripts/runtime/combat_runtime.gd`: Removed smoke/debug probe methods from production combat runtime.
- `scripts/tests/combat_smoke_driver.gd`: Added runtime-level combat win, loss, item, state, roll, enemy-turn, and skill-effect probes.
- `scripts/tests/combat_domain_probe.gd`: Uses combat smoke driver instead of runtime probe methods.
- `scripts/ui/main_root.gd`: Uses combat smoke driver for direct runtime probes.
- `docs/planning/next_implementation_priority.md`: Records the combat runtime probe driver pass.

## Follow-ups
- Remaining work: consider splitting the combined smoke driver into scene-driver and runtime-domain-driver files.

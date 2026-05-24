# Task: Combat Domain Probe Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 플레이 가능성을 높이는 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: combat 검증을 큰 smoke 경로에만 기대지 않고 combatProfile, skill effectOps, item combatUse가 실제 전투 도메인에서 작동하는지 직접 검증한다.

## P0
- Required item: combat runtime에 저장 상태를 망가뜨리지 않는 직접 probe helper를 추가한다.
- Required item: guard/armor break/lifesteal/heal/item damage/status cure/enemy combatProfile을 직접 assertion하는 headless probe를 추가한다.

## P1
- Important item: 기존 domain smoke와 editor/validation smoke가 계속 통과한다.

## P2
- Optional/follow-up item: multi-enemy target mode와 party member별 combat role probe로 확장한다.

## Scope
In:
- CombatRuntime probe hooks
- Dedicated combat domain probe script
- planning/task docs
Out:
- combat UI redesign
- new combat content
- multi-enemy combat implementation

## Acceptance
- Headless combat domain probe passes and catches direct skill/item/profile behavior.
- Existing validation, editor smoke, domain smoke, and diff check pass.
- Completed unit is committed and pushed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/combat_domain_probe.gd`
- Expected: combat domain probe passes.
- Result: Pass. `COMBAT_DOMAIN_PROBE ok=true failures=0`
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: validation passes.
- Result: Pass. `VALIDATION definitions_ok=true map_ok=true`
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes.
- Result: Pass. `EDITOR_SMOKE ... definition_authoring_ok=true ... compiled_handoff=true authored_handoff=true ...`
- Command: `CONAN_DOT_DOMAIN_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: domain smoke passes.
- Result: Pass. `DOMAIN_SMOKE ok=true stock_before=2 stock_refresh=2 stock_after=1`
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result:

## Result
- Status: Completed.
- Added `combat_domain_probe.gd`, a direct headless combat domain probe that backs up/restores the probe save slot and asserts skill, item, and enemy-profile behavior without relying on the full visual smoke route.
- Added a non-destructive `CombatRuntime.smoke_probe_skill_effect` helper for direct skill effectOps assertions.
- Combat runtime and combat view model builder now resolve autoload services through runtime lookup, so `CombatRuntime` can be preloaded and exercised directly by headless probes.
- Probe coverage now directly checks armor break and weakened status, lifesteal healing, direct healing, party guard, firebomb damage/burning, antivenom poison cure, guardian guard profile, priest mask poison resistance, and coward low-HP heal/guard behavior.

## Files Changed
- docs/planning/next_implementation_priority.md: records direct combat domain probe coverage.
- docs/tasks/2026-05-24-combat-domain-probe-pass.md: records scope, verification, results, and follow-ups.
- scripts/runtime/combat_runtime.gd: adds direct skill effect probe and makes autoload access testable from headless scripts.
- scripts/runtime/combat_view_model_builder.gd: uses runtime service access for inventory view model data.
- scripts/tests/combat_domain_probe.gd: adds focused combat domain assertions.

## Follow-ups
- Remaining work: expand combat probes to multi-enemy target mode, party-member-specific roles, and broader authored skill/item families once those systems are ported.

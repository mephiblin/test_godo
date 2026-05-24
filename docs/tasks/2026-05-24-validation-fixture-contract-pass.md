# Task: Validation Fixture Contract Pass

Date: 2026-05-24
Request: 남은 포팅 작업을 계속 진행하며, 실제 플레이 가능한 게임 개발을 위해 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: validation/import contract가 정상 콘텐츠만 통과시키는지뿐 아니라, 의도적으로 깨진 참조/맵 fixture를 실제로 차단하는지 검증한다.

## P0
- Required item: broken definition references를 fixture로 만들고 validator error를 직접 확인한다.
- Required item: broken map/material/fieldAi/placement references를 fixture로 만들고 map validator error를 직접 확인한다.

## P1
- Important item: 기존 validation/editor/domain/visual smoke와 함께 돌아가도록 독립 probe를 추가한다.

## P2
- Optional/follow-up item: fixture probe를 CI 계층으로 분리하고 coverage를 더 세분화한다.

## Scope
In:
- validation fixture probe
- map dictionary validation test entry point
- planning/task docs
Out:
- source JSON content mutation
- CI setup
- full test framework rewrite

## Files To Inspect
- scripts/editor/content_tools.gd
- scripts/tests/validation_probe.gd
- docs/planning/next_implementation_priority.md

## Acceptance
- Fixture probe asserts at least broken quest reward item, event entry/choice/effect refs, NPC handoff refs, vendor skill refs, map material refs, map placement refs, and fieldAi invalid values.
- Probe exits non-zero if any expected broken contract is not caught.
- Existing headless boot, validation probe, editor smoke, domain smoke, visual smoke, and diff check pass.
- Completed unit is committed and pushed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_fixture_probe.gd`
- Expected: fixture probe passes and prints expected case count.
- Result: Passed. `VALIDATION_FIXTURE ok=true cases=14`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds.
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: current content validation passes.
- Result: Passed. `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes.
- Result: Passed. `EDITOR_SMOKE ... placement_affordance_ok=true ... compiled_handoff=true authored_handoff=true`.
- Command: `CONAN_DOT_DOMAIN_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: domain smoke passes.
- Result: Passed. `DOMAIN_SMOKE ok=true`.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: visual smoke passes.
- Result: Passed. Captured town, dungeon floor 1/2/3, combat, defeat, reward, and editor fallback screens.
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result: Passed.

## Result
- Status: Done
- Added a dedicated validation fixture probe with 14 negative contract cases.
- Added a map dictionary validation entry point for tests without mutating source JSON.
- Verified the fixture probe catches broken quest reward item, event graph refs, event effect refs, quest seed refs, NPC handoff refs, vendor skill refs, map material refs, map placement refs, and invalid fieldAi values.

## Files Changed
- docs/planning/next_implementation_priority.md: marked validation fixture coverage as complete and recorded remaining import/export contract work.
- docs/tasks/2026-05-24-validation-fixture-contract-pass.md:
- scripts/editor/content_tools.gd: exposed test-only map dictionary validation wrapper.
- scripts/tests/validation_fixture_probe.gd: added negative validation fixture probe.

## Follow-ups
- Remaining work: source JSON/imported manifest export boundary hardening, stale content-version mismatch expansion, and CI grouping for validator/domain/scene/export probes.

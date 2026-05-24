# Task: Imported Manifest Authority Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 플레이 가능성을 높이는 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: runtime content registry가 stale imported bundle을 무조건 우선하지 않도록 source/imported manifest 권한 경계를 강화한다.

## P0
- Required item: imported manifest의 `contentVersion`이 source manifest보다 낮으면 runtime이 source manifest로 fallback한다.
- Required item: fallback/warning 상태를 검증 가능한 report로 노출한다.

## P1
- Important item: stale imported manifest fixture probe를 추가해 source fallback이 실제로 동작하는지 검증한다.

## P2
- Optional/follow-up item: imported bundle의 map-level stale/hash 계약까지 확장한다.

## Scope
In:
- ContentRegistry manifest selection
- stale imported manifest probe
- planning/task docs
Out:
- contentVersion bump
- source JSON mutation
- packaging/CI setup

## Files To Inspect
- scripts/autoload/content_registry.gd
- scripts/ui/main_root.gd
- scripts/editor/content_tools.gd
- data/source_json/content_manifest.json
- data/imported/content_build_manifest.json

## Acceptance
- Normal current bundle still loads imported manifest.
- Temporarily stale imported manifest causes source fallback and warning without corrupting files.
- Existing boot, validation, editor smoke, domain smoke, content import smoke, visual smoke, and diff check pass.
- Completed unit is committed and pushed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/content_registry_contract_probe.gd`
- Expected: contract probe passes.
- Result: Passed. `CONTENT_REGISTRY_CONTRACT ok=true active=res://data/imported/content_build_manifest.json warnings=[]`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds.
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: validation passes.
- Result: Passed. `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes.
- Result: Passed. `EDITOR_SMOKE ... bundle_ok=true content_ok=true manifest=res://data/imported/content_build_manifest.json ...`.
- Command: `CONAN_DOT_CONTENT_IMPORT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: content import smoke passes.
- Result: Passed. `CONTENT_IMPORT_SMOKE ok=true manifest=res://data/imported/content_build_manifest.json generated_cells=19 route_preview=true`.
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
- Runtime content registry now compares source/imported content versions before choosing the active manifest.
- Stale imported manifests fall back to source JSON and expose a validation warning instead of silently overriding newer source content.
- Added a contract probe that temporarily writes a stale imported manifest, verifies source fallback, restores the file, and confirms imported runtime loading returns.

## Files Changed
- docs/planning/next_implementation_priority.md: recorded stale imported fallback completion and remaining map-level authority work.
- docs/tasks/2026-05-24-imported-manifest-authority-pass.md:
- scripts/autoload/content_registry.gd: added manifest selection, stale fallback, and warning reporting.
- scripts/tests/content_registry_contract_probe.gd: added stale imported manifest authority probe.

## Follow-ups
- Remaining work: map-level source/imported hash or timestamp contract, runtime no-write path documentation, and broader stale bundle mismatch handling.

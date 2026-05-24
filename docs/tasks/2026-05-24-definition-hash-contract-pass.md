# Task: Definition Hash Contract Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 플레이 가능성을 높이는 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: imported bundle이 source definition JSON 변경보다 뒤처진 경우를 contentVersion만으로 놓치지 않도록 definition-family source hash 계약을 추가한다.

## P0
- Required item: build bundle manifest에 definition family별 source path/hash를 기록한다.
- Required item: runtime registry가 imported definition hash mismatch를 감지하면 source manifest로 fallback한다.

## P1
- Important item: contract probe가 임시 stale definition hash를 만들고 fallback/warning/restore를 검증한다.

## P2
- Optional/follow-up item: exported package metadata에도 동일 hash 계약을 노출한다.

## Scope
In:
- ContentTools build manifest definition hashes
- ContentRegistry imported definition hash validation
- content registry contract probe
- planning/task docs
Out:
- contentVersion bump
- source JSON gameplay content changes
- packaging/CI setup

## Acceptance
- Current valid imported bundle still loads.
- A stale definition source hash causes source fallback with a warning.
- Existing content registry probe, boot, validation, editor smoke, domain smoke, and diff check pass.
- Completed unit is committed and pushed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/content_registry_contract_probe.gd`
- Expected: contract probe passes.
- Result: Pass. `CONTENT_REGISTRY_CONTRACT ok=true active=res://data/imported/content_build_manifest.json warnings=[]`
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds.
- Result: Pass.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: validation passes.
- Result: Pass. `VALIDATION definitions_ok=true map_ok=true`
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes and regenerated imported manifest has definition hashes.
- Result: Pass. `bundle_ok=true content_ok=true`; regenerated imported manifest includes `definitionHashes`.
- Command: `CONAN_DOT_DOMAIN_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: domain smoke passes.
- Result: Pass. `DOMAIN_SMOKE ok=true stock_before=2 stock_refresh=2 stock_after=1`
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result: Pass.

## Result
- Status: Completed.
- Build bundle export now records `definitionHashes` for every source definition family.
- Runtime `ContentRegistry` rejects imported bundles whose definition source hashes no longer match source JSON and falls back to the source manifest with a warning.
- Contract probe now mutates imported manifest definition hashes, verifies source fallback, and restores the manifest.
- Tracked imported manifest includes the current definition hash contract so the default runtime path is protected.

## Files Changed
- data/imported/content_build_manifest.json: records current definition family hashes.
- docs/planning/next_implementation_priority.md: marks definition-family hash contract complete and narrows remaining export metadata work.
- docs/tasks/2026-05-24-definition-hash-contract-pass.md: records scope, verification, result, and follow-ups.
- scripts/autoload/content_registry.gd: validates imported definition hashes before selecting the imported manifest.
- scripts/editor/content_tools.gd: writes definition hash metadata during build bundle export.
- scripts/tests/content_registry_contract_probe.gd: adds stale definition hash fallback coverage.

## Follow-ups
- Remaining work: expose the same source-hash contract in exported package metadata and future CI artifact reports.

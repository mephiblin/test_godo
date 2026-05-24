# Task: Imported Map Hash Contract Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 플레이 가능성을 높이는 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: imported bundle이 source map 변경보다 뒤처진 경우를 contentVersion만으로 놓치지 않도록 map-level source hash 계약을 추가한다.

## P0
- Required item: build bundle manifest에 각 compiled map의 source path/hash를 기록한다.
- Required item: runtime registry가 imported compiled map sourceHash mismatch를 감지하면 source manifest로 fallback한다.

## P1
- Important item: contract probe가 임시 stale map hash를 만들고 fallback/warning/restore를 검증한다.

## P2
- Optional/follow-up item: definition family hash까지 확장한다.

## Scope
In:
- ContentTools build manifest map source hashes
- ContentRegistry imported map hash validation
- content registry contract probe
- planning/task docs
Out:
- contentVersion bump
- source JSON gameplay content changes
- packaging/CI setup

## Acceptance
- Current valid imported bundle still loads.
- A stale compiled map sourceHash causes source fallback with a warning.
- Existing boot, validation, editor smoke, content registry probe, domain smoke, visual smoke, and diff check pass.
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
- Expected: editor smoke passes and regenerated imported manifest has hashes.
- Result: Pass. `bundle_ok=true content_ok=true`; generated imported manifest now records `sourcePath` and `sourceHash` for each compiled map.
- Command: `CONAN_DOT_CONTENT_IMPORT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: content import smoke passes with imported manifest active.
- Result: Pass. `CONTENT_IMPORT_SMOKE ok=true manifest=res://data/imported/content_build_manifest.json generated_cells=19 route_preview=true`
- Command: `CONAN_DOT_DOMAIN_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: domain smoke passes.
- Result: Pass. `DOMAIN_SMOKE ok=true stock_before=2 stock_refresh=2 stock_after=1`
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: visual smoke passes.
- Result: Pass. Captured title, town, dungeon floors 1-3, combat, epilogue/reward, and editor fallback screens.
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result: Pass.

## Result
- Status: Completed.
- Build bundle export now records a source path/hash contract for each compiled map.
- Runtime content registry rejects imported compiled maps whose recorded source hash no longer matches the source JSON and falls back to the source manifest with a warning.
- Contract probe mutates the imported manifest into both stale contentVersion and stale map-hash states, verifies source fallback, and restores the manifest.

## Files Changed
- data/imported/content_build_manifest.json: records map `sourcePath` and `sourceHash` in the tracked imported manifest.
- docs/planning/next_implementation_priority.md: marks map-level source/imported hash contract complete and narrows follow-up contract work.
- docs/tasks/2026-05-24-imported-map-hash-contract-pass.md: records scope, verification, result, and follow-ups.
- scripts/autoload/content_registry.gd: validates imported compiled map source hashes before choosing the imported manifest.
- scripts/editor/content_tools.gd: writes source path/hash metadata when exporting imported build bundles.
- scripts/tests/content_registry_contract_probe.gd: adds stale map-hash fallback coverage.

## Follow-ups
- Remaining work: extend the same authority contract to definition-family source hashes and exported bundle metadata if source JSON changes continue to outpace contentVersion bumps.

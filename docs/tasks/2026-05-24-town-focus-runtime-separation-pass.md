# Task: Town Focus Runtime Separation Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 플레이 가능성을 높이는 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: generic dungeon runtime surface에 남은 town focus/path/service helper를 별도 runtime helper로 분리해 town route 책임을 더 명확히 한다.

## P0
- Required item: town focus target ranking, selected/nearby lookup, anchor/path stepping, direction hints, snapshot, and service preview logic을 `grid_scene.gd` 밖으로 옮긴다.
- Required item: 기존 town hub input, HUD snapshot, world anchor/path marker 동작을 유지한다.

## P1
- Important item: dungeon route smoke와 town visual smoke가 기존 town focus/route affordance를 계속 검증한다.

## P2
- Optional/follow-up item: town landmark/ambient drawing도 별도 presenter로 추가 분리한다.

## Scope
In:
- Town focus runtime helper
- GridScene/TownScene delegation glue
- Smoke/validation verification
- task/planning docs
Out:
- town landmark mesh rewrite
- town HUD visual redesign
- dungeon affordance behavior changes

## Acceptance
- `grid_scene.gd` no longer owns the bulk of town focus/path/service preview logic.
- Town route keyboard flow and HUD `townFocus` snapshot still work.
- Existing headless boot, validation, editor smoke, domain/content smoke, visual smoke, and diff check pass.
- Completed unit is committed and pushed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds.
- Result: Pass.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: validation passes.
- Result: Pass. `VALIDATION definitions_ok=true map_ok=true`
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes.
- Result: Pass. `EDITOR_SMOKE ... definition_authoring_ok=true ... fallback_workspace_detail_ok=true ...`
- Command: `CONAN_DOT_DOMAIN_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: domain smoke passes.
- Result: Pass. `DOMAIN_SMOKE ok=true stock_before=2 stock_refresh=2 stock_after=1`
- Command: `CONAN_DOT_CONTENT_IMPORT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: content import smoke passes.
- Result: Pass. `CONTENT_IMPORT_SMOKE ok=true manifest=res://data/imported/content_build_manifest.json generated_cells=19 route_preview=true`
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: visual smoke passes.
- Result: Pass. Captured title, town route, dungeon floors 1-3, combat, epilogue/reward, and editor fallback screens.
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result: Pass.

## Result
- Status: Completed.
- Added `town_focus_runtime.gd` as a dedicated town focus helper for focus target ranking, nearby/selected lookup, approach/path stepping, town HUD focus snapshots, direction hints, anchor snapshots, and town service preview summaries.
- `grid_scene.gd` now delegates town focus behavior through the helper while retaining dungeon interaction and world-marker responsibilities.
- Existing town hub input, HUD focus panel, route approach behavior, service overlays, and visual smoke route continue to work.

## Files Changed
- docs/planning/next_implementation_priority.md: records town focus/path/service helper separation and narrows remaining town separation work.
- docs/tasks/2026-05-24-town-focus-runtime-separation-pass.md: records scope, verification, result, and follow-ups.
- scripts/runtime/grid_scene.gd: removes bulk town focus state/logic in favor of delegated helper calls.
- scripts/runtime/town_focus_runtime.gd: owns town focus ranking, pathing, hints, snapshots, and service previews.

## Follow-ups
- Remaining work: split town landmark/ambient presentation out of `grid_scene.gd`, then remove remaining town-specific world dressing from the generic dungeon runtime.

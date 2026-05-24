# Task: Play View HUD Occlusion Pass

Date: 2026-05-24
Request: 실제 게임 구동한것으로 개발에 집중해. 원본에 없던 불필요한 확장성이나, 추가 개발 금지
Goal: 실제 Godot 구동 화면에서 HUD가 3D 플레이 화면과 표식을 가리는 문제를 줄인다.

## P0
- Required item: 기존 HUD 정보는 유지하되 플레이 화면을 덮는 디버그성 긴 상태 표시를 줄인다.
- Required item: 던전/마을의 3D 장면과 월드 마커가 화면 오른쪽에서 계속 보이게 한다.

## P1
- Important item: 새 기능이나 원본에 없던 확장 시스템을 추가하지 않는다.
- Important item: 기존 smoke snapshot 데이터 계약은 유지한다.

## P2
- Optional/follow-up item: 실제 수동 플레이에서 작은 화면 해상도별 추가 조정을 한다.

## Scope
In:
- `grid_hud.gd`, `town_hud.gd`의 화면 표시 크기, 불투명도, 표시 줄 수 조정.
- planning backlog의 수동 플레이 튜닝 항목 갱신.

Out:
- 새 HUD 기능 추가.
- 런타임/데이터/에디터 구조 변경.
- 원본 브라우저판 handoff 확장.

## Files To Inspect
- `scripts/ui/grid_hud.gd`
- `scripts/ui/town_hud.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Godot visual smoke가 끝까지 통과한다.
- 던전/마을 캡처에서 HUD가 화면 대부분을 덮지 않는다.
- 기존 `hud_snapshot()`의 구조와 내용은 테스트용 데이터로 남는다.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: exits 0
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: exits 0
- Result: Passed, `VALIDATION definitions_ok=true map_ok=true`.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: exits 0 and captures play routes
- Result: Passed, including town, dungeon floor 1/2/3, combat, rewards, and editor fallback captures.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: exits 0
- Result: Passed, `EDITOR_SMOKE ... authored_handoff=true`.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Implemented. The grid/town HUD now uses fixed-height play panels, compact state/log text, lower-opacity panels, and a true bottom-anchored prompt strip so the smoke-tested 3D town and dungeon views remain visible.

## Files Changed
- `scripts/ui/grid_hud.gd`: Reduced panel footprint, clipped long play text, compacted state/log rendering, and fixed the prompt strip to the lower viewport instead of spanning the full height.
- `scripts/ui/town_hud.gd`: Matched town HUD/focus panel sizes to the compact play-view layout.
- `docs/planning/next_implementation_priority.md`: Recorded the play-view HUD occlusion pass and narrowed the remaining marker tuning follow-up.
- `docs/tasks/2026-05-24-play-view-hud-occlusion-pass.md`: Recorded scope, acceptance, verification, result, and follow-ups.

## Follow-ups
- Remaining work: Continue manual marker-size tuning in narrow halls and crowded authored encounters.

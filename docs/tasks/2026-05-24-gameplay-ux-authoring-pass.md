# Task: Gameplay UX And Authoring Pass

Date: 2026-05-24
Request: dungeon HUD intent/next-step guide, combat reward/defeat/end-state UX polish, editor를 실제 map/event/NPC 제작 도구로 확장한다.
Goal: 플레이 중 다음 행동이 더 잘 보이고, 전투 종료 선택이 더 명확하며, placement authoring 반복 작업이 줄어든다.

## P0
- Required item: dungeon HUD에 intent chip과 next-step guide를 추가한다.
- Required item: combat victory/defeat/end-state UX를 더 명확하게 만든다.

## P1
- Important item: editor placement authoring에 타입별 guided quick action을 추가한다.

## P2
- Optional/follow-up item: 이후 editor full authoring surface와 combat reward detail을 더 넓힌다.

## Scope
In:
- grid HUD
- combat scene/runtime/presenter
- editor placement affordance panel
- docs/planning update
Out:
- full editor graph rewrite
- new combat mechanics
- CI setup

## Files To Inspect
- scripts/ui/grid_hud.gd
- scripts/runtime/grid_scene.gd
- scripts/runtime/combat_scene.gd
- scripts/runtime/combat_runtime.gd
- scripts/runtime/combat_hud_presenter.gd
- addons/connan_editor/docks/content_editor_dock.gd

## Acceptance
- Dungeon HUD shows an intent chip and next-step/action guide for the active interaction.
- Combat victory does not immediately disappear without context; player sees outcome and can continue.
- Defeat overlay provides clearer recovery/title consequences.
- Editor placement preview includes practical authoring quick actions for common gameplay placements.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds.
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: validation passes.
- Result: Passed. `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes.
- Result: Passed. `EDITOR_SMOKE validation_ok=true map_ok=true preview_ok=true ... placement_affordance_ok=true ...`.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: visual smoke captures dungeon/combat screens.
- Result: Passed. Captured title, town, dungeon floors, combat, defeat, reward, and editor fallback screens.
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result: Passed.

## Result
- Status: Done
- Added dungeon HUD intent chip and next-step/guide row using the runtime interaction snapshot.
- Added combat victory summary overlay before returning to dungeon, while keeping smoke win auto-exit behavior.
- Clarified defeat overlay consequences and recovery/title choices.
- Added editor placement quick-author actions for common gameplay placements.

## Files Changed
- addons/connan_editor/docks/content_editor_dock.gd: added placement type quick-author actions for common dungeon/town gameplay objects.
- docs/planning/next_implementation_priority.md: recorded completed gameplay UX/editor authoring pass and remaining follow-ups.
- scripts/runtime/combat_hud_presenter.gd: added victory summary presentation text.
- scripts/runtime/combat_runtime.gd: added structured victory summary data for reward/end-state display.
- scripts/runtime/combat_scene.gd: added victory overlay and clearer defeat overlay.
- scripts/runtime/grid_scene.gd: added interaction next-step and guide data to dungeon snapshots.
- scripts/ui/grid_hud.gd: added dungeon intent chip and next-step guide row.

## Follow-ups
- Remaining work: add optional path-to-object world guidance, convert event/NPC previews into guided field editors, and add direct combat domain tests for outcome summaries.

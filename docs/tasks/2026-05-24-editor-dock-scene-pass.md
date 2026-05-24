# Task: Editor Dock Scene Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 범위가 사실상 종료인지 판단하고, 아직 남은 Editor Dock 구조 문제를 최소 변경으로 정리한다.
Goal: Content editor dock이 Godot 에디터 도구답게 명명된 `.tscn` 루트에서 생성되고, 플러그인과 smoke가 같은 Dock scene을 사용한다.

## P0
- Required item: `ConnanEditorPlugin`이 `content_editor_dock.gd`를 직접 `new()` 하지 않고 named Dock scene을 인스턴스화한다.
- Required item: editor smoke가 Dock root 이름과 scene path를 검증한다.

## P1
- Important item: 기존 Definition, Map/Placement, Grid, Build/Status 흐름은 그대로 유지한다.
- Important item: 원본에 없던 추가 authoring 기능은 만들지 않는다.

## P2
- Optional/follow-up item: 남은 production scene smoke/debug API를 테스트 adapter로 분리할 범위를 별도 판단한다.

## Scope
In:
- `addons/connan_editor/docks/ContentEditorDock.tscn`
- `addons/connan_editor/plugin.gd`
- `scripts/tests/editor_smoke.gd`
- `docs/planning/next_implementation_priority.md`

Out:
- 신규 editor authoring 기능
- Runtime gameplay behavior 변경
- Godot 생성 `.uid` 미추적 파일 정리

## Files To Inspect
- `addons/connan_editor/plugin.gd`
- `addons/connan_editor/docks/content_editor_dock.gd`
- `scripts/tests/editor_smoke.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Dock root is a named scene rather than only a runtime-created anonymous container.
- Editor smoke verifies the named Dock scene contract.
- Existing validation/import/runtime probes still pass.

## Verification
- Command: Godot headless boot
- Expected: exits 0
- Result: Pass
- Command: `res://scripts/tests/editor_smoke.gd`
- Expected: exits 0 and reports `EDITOR_SMOKE_OK`
- Result: Pass; reports `EDITOR_SMOKE ... dock_root_named=true ...`
- Command: `res://scripts/tests/imported_runtime_probe.gd`
- Expected: exits 0 and reports imported-only runtime contract ok
- Result: Pass; reports `IMPORTED_RUNTIME_PROBE ok=true`
- Command: `res://scripts/tests/validation_probe.gd`
- Expected: exits 0 and reports validation ok
- Result: Pass; reports `VALIDATION definitions_ok=true map_ok=true`
- Command: visual smoke
- Expected: exits 0 and writes current screenshots
- Result: Pass; captured title, town, dungeon, combat, reward, and editor fallback screenshots under `output/`.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Pass

## Result
- Status: Implemented

## Files Changed
- `addons/connan_editor/docks/ContentEditorDock.tscn`: Added a named Dock scene root with the existing content editor script.
- `addons/connan_editor/plugin.gd`: Loads the named Dock scene instead of creating the Dock from script only.
- `scripts/tests/editor_smoke.gd`: Instantiates the same Dock scene and verifies the scene path/root name contract.
- `docs/planning/next_implementation_priority.md`: Records the Dock scene pass in the current backlog state.
- `docs/tasks/2026-05-24-editor-dock-scene-pass.md`: Tracks scope, verification, and result.

## Follow-ups
- Remaining work: production scene smoke/debug API boundary remains a separate cleanup candidate.
- Remaining work: editor fallback smoke report text still overlaps gameplay HUD in fallback screenshots; this predates the Dock scene pass.

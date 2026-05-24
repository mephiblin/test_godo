# Task: Editor Dock Engineizing Pass

Date: 2026-05-24
Request: `@VBoxContainer@18511` 같은 익명 Dock과 화면을 과도하게 차지하는 단일 목록형 에디터를 Godot식 파일 제작 도구로 정리한다.
Goal: 에디터를 라이브 게임 화면이 아니라 `source_json` 편집, 검증, build/imported 산출물 생성, test play 진입을 분리해서 수행하는 Godot EditorPlugin Dock으로 정리한다.

## P0
- Required item: Dock root와 탭 이름이 익명 `@VBoxContainer@...`가 아니라 사람이 읽는 이름으로 표시된다.
- Required item: Definition, Map/Placement, Grid, Build/Status 기능이 한 세로 목록에 모두 펼쳐지지 않고 기능별 탭으로 분리된다.
- Required item: 기존 save/validate/build/play callbacks와 smoke helper가 유지된다.

## P1
- Important item: editor smoke가 Dock root 이름과 imported manifest/file boundary를 직접 검증한다.
- Important item: 런타임 파일이나 게임 규칙은 변경하지 않는다.

## P2
- Optional/follow-up item: 다음 단계에서 Dock을 `.tscn` 기반 scene과 InspectorPlugin/EditorResourcePreview 구조로 더 분리한다.

## Scope
In:
- `addons/connan_editor/plugin.gd`
- `addons/connan_editor/docks/content_editor_dock.gd`
- `scripts/tests/editor_smoke.gd`
- planning/task docs
Out:
- runtime gameplay scene behavior
- content JSON schema expansion
- new gameplay/editor features

## Files To Inspect
- `addons/connan_editor/plugin.gd`
- `addons/connan_editor/docks/content_editor_dock.gd`
- `scripts/editor/content_tools.gd`
- `scripts/tests/editor_smoke.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Godot editor dock root name is `Connan Content Editor`.
- Content editor UI has separate Definition, Map/Placement, Grid, and Build/Status sections.
- Editor smoke reports `dock_root_named=true` and `imported_manifest_flow_ok=true`.
- Runtime visual smoke still reaches town, dungeon, combat, reward, and editor fallback routes.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: exits 0
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: exits 0 and reports `dock_root_named=true imported_manifest_flow_ok=true`
- Result: Passed, `EDITOR_SMOKE ... dock_root_named=true ... imported_manifest_flow_ok=true`.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: exits 0
- Result: Passed, including town, dungeon floor 1/2/3, combat, reward, and editor fallback captures.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed before documentation finalization; rerun before commit.

## Result
- Status: Implemented. The content editor dock has a stable human-readable root name and presents authoring surfaces as Definition, Map/Placement, Grid, and Build/Status tabs while preserving existing save/build/play callbacks and smoke helpers.

## Files Changed
- `addons/connan_editor/plugin.gd`: Sets an explicit dock name and sizing defaults before registering the dock.
- `addons/connan_editor/docks/content_editor_dock.gd`: Names the root and splits the generated UI into feature tabs.
- `scripts/tests/editor_smoke.gd`: Asserts the dock root name and imported manifest handoff metadata.
- `docs/planning/next_implementation_priority.md`: Records the dock engineizing pass and boundary checks.
- `docs/tasks/2026-05-24-editor-dock-engineizing-pass.md`: Records scope, acceptance, verification, result, and follow-ups.
- `docs/tasks/2026-05-24-editor-game-file-boundary-validation.md`: Records the focused smoke boundary additions.

## Follow-ups
- Remaining work: Move the dock from script-generated UI to a named `.tscn` dock scene and eventually split large authoring surfaces into dedicated inspector/resource editors.

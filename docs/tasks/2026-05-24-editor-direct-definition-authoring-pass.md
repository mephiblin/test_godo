# Task: Editor Direct Definition Authoring Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 플레이 가능한 게임 제작 효율을 높이는 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: editor가 map placement preview를 넘어 event/NPC definition row 자체를 직접 제작할 수 있는 guided authoring surface를 제공한다.

## P0
- Required item: selected event definition row에서 entry step 지정과 selected step choice 추가를 직접 조작할 수 있게 한다.
- Required item: selected NPC definition row에서 service 목록을 보고 기본 talk service를 직접 추가할 수 있게 한다.

## P1
- Important item: editor smoke가 guided definition authoring을 저장 없이 수집 결과로 검증한다.

## P2
- Optional/follow-up item: event graph node/edge editor와 NPC service field별 row editor로 확장한다.

## Scope
In:
- Connan editor dock definition authoring surface
- smoke-only editor authoring helpers
- editor smoke assertion
- task/planning docs
Out:
- destructive source JSON content edits
- full event graph visual editor
- material/light authoring

## Acceptance
- Event row authoring can set an entry step and add a choice to a selected step through guided controls/helpers.
- NPC row authoring can append a basic talk service through guided controls/helpers.
- Existing validation/editor smoke remains green.
- Completed unit is committed and pushed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes with guided definition authoring assertions.
- Result: Pass. `definition_authoring_ok=true`; existing placement/grid/build/runtime handoff checks also stayed green.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: validation passes.
- Result: Pass. `VALIDATION definitions_ok=true map_ok=true`
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result: Pass.

## Result
- Status: Completed.
- The editor editable definition list now includes `events` and `npcs`, so authors can edit those source JSON families from the dock instead of treating them as preview-only data.
- Selected event rows now expose a guided authoring panel for graph summary, entry-step selection, setting `entryStepId`, and adding a continue choice to a selected step.
- Selected NPC rows now expose service summary/selection and a guided action for adding a draft talk service.
- Editor smoke verifies the guided authoring surface through in-memory row collection without leaving destructive source JSON changes.

## Files Changed
- addons/connan_editor/docks/content_editor_dock.gd: adds event/NPC definition authoring panels and smoke helpers.
- docs/planning/next_implementation_priority.md: records direct event/NPC definition authoring progress.
- docs/tasks/2026-05-24-editor-direct-definition-authoring-pass.md: records scope, verification, results, and follow-ups.
- scripts/editor/content_tools.gd: exposes events and NPCs as editable definition families.
- scripts/tests/editor_smoke.gd: asserts guided event/NPC definition authoring.

## Follow-ups
- Remaining work: replace JSON-array editing for event steps and NPC services with row-level field editors, then add a visual event graph node/edge surface.

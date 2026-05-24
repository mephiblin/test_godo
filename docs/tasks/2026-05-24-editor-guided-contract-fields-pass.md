# Task: Editor Guided Contract Fields Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 계속 진행하고, 실제 플레이 가능한 게임 개발을 위해 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: editor placement preview를 실제 제작 도구에 더 가깝게 만들어, 선택한 event graph/NPC service 정보를 authored placement contract field로 적용할 수 있게 한다.

## P0
- Required item: event/rest/trap placement에서 선택한 event step/choice를 placement authoring field로 적용한다.
- Required item: NPC service placement에서 선택한 service row를 placement authoring field로 적용한다.

## P1
- Important item: editor smoke에서 적용된 contract fields가 source map save/import round-trip까지 유지되는지 검증한다.

## P2
- Optional/follow-up item: 실제 event graph row 자체를 편집하는 UI로 확장한다.

## Scope
In:
- editor placement guided contract fields
- editor smoke assertions
- planning/task docs
Out:
- full graph editor
- NPC definition row editing
- runtime behavior changes

## Files To Inspect
- addons/connan_editor/docks/content_editor_dock.gd
- scripts/tests/editor_smoke.gd
- docs/planning/next_implementation_priority.md

## Acceptance
- Selected event step/choice can be applied as authored placement metadata.
- Selected NPC service can be applied as authored placement metadata.
- Saved source map and imported map preserve those fields during editor smoke.
- Existing boot, validation, editor smoke, domain smoke, visual smoke, and diff check pass.
- Completed unit is committed and pushed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds.
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: validation passes.
- Result: Passed. `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes and reports guided contract fields.
- Result: Passed. `EDITOR_SMOKE ... placement_reference_ok=true placement_affordance_ok=true ...`.
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
- Added editor actions to apply the selected event step/choice into placement authoring fields.
- Added editor actions to apply the selected NPC service row into placement authoring fields.
- Extended editor smoke to save those fields and verify they survive source map save plus imported bundle rebuild.

## Files Changed
- addons/connan_editor/docks/content_editor_dock.gd: added selected event/NPC contract apply actions and smoke methods.
- docs/planning/next_implementation_priority.md: recorded guided placement contract fields as complete.
- docs/tasks/2026-05-24-editor-guided-contract-fields-pass.md:
- scripts/tests/editor_smoke.gd: verifies event/NPC contract fields round-trip through source/imported maps.

## Follow-ups
- Remaining work: direct editing of event definition graph rows, direct editing of NPC service definition rows, and fuller map/build/generator authoring surfaces.

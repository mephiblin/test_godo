# Task: Editor Row Authoring Fields Pass

Date: 2026-05-24
Request: Continue the remaining Godot port work as playable game development, committing and pushing each major completed unit.
Goal: Improve the Godot editor from JSON-array patching toward practical event/NPC production tools.

## P0
- Required item: Add row-level field editing for selected event steps and event choices.
- Required item: Add row-level field editing for selected NPC services.

## P1
- Important item: Keep existing definition save/import/validation smoke behavior intact.
- Important item: Prove the guided editors mutate the authored row data before save.

## P2
- Optional/follow-up item: Replace the remaining raw JSON array editor with visual event graph and service list widgets.

## Scope
In:
- `ConnanEditorPlugin` content dock authoring surface.
- Editor smoke coverage for row-level event/NPC authoring fields.
- Planning backlog update.

Out:
- Full visual event graph.
- Inspector write-back contract changes.
- Runtime gameplay logic changes.

## Files To Inspect
- `addons/connan_editor/docks/content_editor_dock.gd`
- `scripts/tests/editor_smoke.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Event authors can edit selected step title/text and selected choice label/next step without hand-editing the whole `steps` JSON array.
- NPC authors can edit selected service type/label/note and common `opensService` fields without hand-editing the whole `services` JSON array.
- Editor smoke verifies the guided field mutations.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: exits 0
- Result: Passed, including `definition_authoring_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: exits 0
- Result: Passed, `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: exits 0
- Result: Passed.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Implemented. The content dock now exposes guided row-level fields for selected event steps, selected event choices, and selected NPC services. The editor smoke mutates those fields through the same authoring functions and verifies the authored row data changes before save.

## Files Changed
- `addons/connan_editor/docks/content_editor_dock.gd`: Added event step/choice field editors, NPC service field editors, and smoke-callable mutation helpers.
- `scripts/tests/editor_smoke.gd`: Verifies row-level event step, event choice, and NPC service authoring mutations.
- `docs/planning/next_implementation_priority.md`: Marks row-level editor fields complete and narrows the remaining editor UX backlog.
- `docs/tasks/2026-05-24-editor-row-authoring-fields-pass.md`: Records scope, acceptance, verification, result, and follow-ups.

## Follow-ups
- Remaining work: Build a visual event graph node/edge editor and a dedicated NPC service list editor.

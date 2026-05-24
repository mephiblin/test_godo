# Task: Editor Game File Boundary Validation

Date: 2026-05-24
Request: Worker 3 adds focused validation/tests/docs for the editor/game file boundary after dock cleanup without touching runtime or `content_editor_dock.gd`.
Goal: Preserve editor dock identity and build/imported manifest handoff coverage while other workers continue dock cleanup.

## P0
- Required item: Add a direct editor smoke assertion that the editor dock instance has its named root.
- Required item: Add a direct editor smoke assertion that the build/imported manifest flow still records the expected manifest path, validation state, definition hashes, and compiled map source hash metadata.

## P1
- Important item: Record the boundary-test intent in the active implementation priority doc.

## P2
- Optional/follow-up item: Split editor smoke into smaller boundary probes once the test stack is reorganized.

## Scope
In:
- `scripts/tests/editor_smoke.gd`
- `docs/planning/next_implementation_priority.md`
- this task document
Out:
- `addons/connan_editor/docks/content_editor_dock.gd`
- runtime behavior
- source/imported JSON content changes

## Files To Inspect
- `scripts/tests/editor_smoke.gd`
- `scripts/editor/content_tools.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Editor smoke fails if the dock root name is lost during dock cleanup.
- Editor smoke fails if build/import no longer writes the imported manifest path, validation report, definition hashes, or compiled map source-hash metadata for `dungeon_floor_01`.
- No runtime files or dock implementation files are edited.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --check-only --script res://scripts/tests/editor_smoke.gd`
- Expected: script parses successfully without executing artifact writes.
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: `EDITOR_SMOKE` reports `dock_root_named=true` and `imported_manifest_flow_ok=true`.
- Result: Passed after dock cleanup landed, `EDITOR_SMOKE ... dock_root_named=true ... imported_manifest_flow_ok=true`.
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result: Passed.

## Result
- Status: Implemented and verified.
- Added focused editor smoke checks for the dock root name and source/imported build manifest boundary.

## Files Changed
- `docs/planning/next_implementation_priority.md`: records the new boundary validation pass.
- `docs/tasks/2026-05-24-editor-game-file-boundary-validation.md`: task breakdown and verification expectations.
- `scripts/tests/editor_smoke.gd`: adds direct dock-name and imported-manifest flow assertions.

## Follow-ups
- Remaining work: Split this large editor smoke into smaller boundary probes when the test stack is reorganized.

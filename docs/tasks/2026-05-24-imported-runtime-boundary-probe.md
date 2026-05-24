# Task: Imported Runtime Boundary Probe

Date: 2026-05-24
Request:
Continue the Godot port with focus on real game execution, editor/runtime
separation, imported content handoff, and no unnecessary expansion.

Goal:
Add a direct runtime contract probe proving that normal game startup uses the
imported content build and does not depend on editor state.

## P0
- Required item: verify `ContentRegistry` selects
  `data/imported/content_build_manifest.json`.
- Required item: verify imported town/dungeon maps keep compiled handoff
  metadata.
- Required item: verify new-game save state starts in town using compiled
  dungeon source without editor-only keys.

## P1
- Important item: keep the probe independent from editor smoke and visual smoke.
- Important item: preserve any existing local save slot used by the probe.

## P2
- Optional/follow-up item: add a scene-level imported-only route smoke if the
  runtime route host gets a dedicated headless harness.

## Scope
In:
- Headless probe script.
- Task/backlog documentation.

Out:
- New gameplay features.
- Editor UI expansion.
- Broad runtime scene refactors.

## Files To Inspect
- `scripts/autoload/content_registry.gd`
- `scripts/autoload/game_app.gd`
- `scripts/autoload/save_service.gd`
- `scripts/tests/content_registry_contract_probe.gd`

## Acceptance
- Probe fails if runtime falls back to source JSON while imported content is
  valid.
- Probe fails if the new-game save contains editor-only state.
- Probe restores the local save slot after running.

## Verification
- Command: `Godot --headless --path . --script res://scripts/tests/imported_runtime_probe.gd`
- Expected: `IMPORTED_RUNTIME_PROBE ok=true`
- Command: `Godot --headless --path . --quit`
- Expected: boot exits 0.
- Command: `Godot --headless --path . --script res://scripts/tests/validation_probe.gd`
- Expected: `VALIDATION definitions_ok=true map_ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/content_registry_contract_probe.gd`
- Expected: `CONTENT_REGISTRY_CONTRACT ok=true`
- Command: `Godot --headless --path . --script res://scripts/tests/editor_smoke.gd`
- Expected: `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR=output xvfb-run -a Godot --path . --smoke`
- Expected: title, town, dungeon, combat, reward, and editor fallback captures are written.

## Result
- Status: Passed. The probe confirms the normal new-game runtime uses the
  imported manifest and compiled dungeon source, with no editor-only payload in
  save data.

## Files Changed
- `scripts/tests/imported_runtime_probe.gd`: added imported-only runtime
  contract probe with save-slot backup/restore.
- `scripts/tests/imported_runtime_probe.gd.uid`: Godot UID for the new probe
  script.
- `docs/tasks/2026-05-24-imported-runtime-boundary-probe.md`: recorded scope,
  result, and verification.
- `docs/planning/next_implementation_priority.md`: updated current baseline and
  validation/test-stack backlog.

## Follow-ups
- Remaining work: add a scene-level imported route harness later if the runtime
  route host gets a dedicated headless fixture.

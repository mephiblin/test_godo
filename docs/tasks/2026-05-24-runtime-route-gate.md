# Task: Runtime route gate helper

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` route-condition responsibility.
Goal: Move route gate checks and campaign-clear title decisions into a dedicated runtime helper while preserving existing scene/helper calls.

## P0
- Required item: route block message logic moves out of `grid_scene.gd`.
- Required item: campaign-clear route condition and ending title resolution move out of `grid_scene.gd`.
- Required item: existing `_route_block_message`, `_should_mark_campaign_clear`, and `_resolved_campaign_clear_title` callers remain valid.

## P1
- Important item: preserve route HUD, route interaction, town gate presentation, and smoke-driver route checks.
- Important item: avoid save schema, imported manifest, editor payload, or authored content changes.

## P2
- Optional/follow-up item: later retarget route callers to the helper directly when scene compatibility delegates are no longer needed.

## Scope
In:
- Runtime route gate condition queries.
- Campaign-clear route title decision.

Out:
- Route execution.
- Map generation/import.
- UI layout.
- Content data changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/dungeon_interaction_runtime.gd`
- `scripts/runtime/runtime_snapshot_builder.gd`
- `scripts/runtime/interaction_snapshot_builder.gd`
- `scripts/runtime/town_world_presenter.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer owns the route gate condition method bodies.
- Current route HUD/open/blocked state and campaign-clear route behavior still work.
- Relevant Godot boot/probe/smoke checks pass.

## Verification
- Command: Godot headless boot
- Result: Passed; exits 0.
- Command: validation probe
- Result: Passed; `VALIDATION definitions_ok=true map_ok=true`.
- Command: imported runtime probe
- Result: Passed; `IMPORTED_RUNTIME_PROBE ok=true manifest=res://data/imported/content_build_manifest.json slot=3`.
- Command: editor smoke
- Result: Passed; `imported_manifest_flow_ok=true`.
- Command: visual smoke
- Result: Passed; `SMOKE: done`, with town gate open and campaign-clear epilogue captures inspected.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/runtime_route_gate.gd`: Owns route block-message checks and campaign-clear route title/eligibility decisions.
- `scripts/runtime/grid_scene.gd`: Keeps compatibility delegates for route HUD, route execution, town gate presentation, and smoke-driver callers.
- `docs/planning/next_implementation_priority.md`: Records the route gate cleanup.

## Follow-ups
- Remaining work: Later retarget route callers to the helper directly when scene compatibility delegates are no longer needed.

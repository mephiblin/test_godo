# Task: Interaction guide builder

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` runtime presentation responsibility.
Goal: Move objective guide and interaction affordance detail construction into `interaction_snapshot_builder.gd`.

## P0
- Required item: objective guide snapshot construction moves out of `grid_scene.gd`.
- Required item: route, field monster, event, door, secret, loot, and trap affordance detail builders move out of `grid_scene.gd`.
- Required item: existing scene/helper call surface remains valid through delegates.

## P1
- Important item: preserve HUD objective and interaction detail dictionary/text shape.
- Important item: avoid save schema, imported manifest, editor payload, or gameplay execution changes.

## P2
- Optional/follow-up item: split objective guide into its own helper later if interaction snapshot builder becomes too broad.

## Scope
In:
- Runtime objective and interaction presentation text.
- Existing helper call compatibility.

Out:
- Interaction execution.
- UI layout.
- Content data changes.
- Save schema changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/interaction_snapshot_builder.gd`
- `scripts/runtime/runtime_snapshot_builder.gd`
- `scripts/ui/grid_hud.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer owns objective/affordance detail method bodies.
- Current HUD objective and interaction panel still render during smoke.
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
- Result: Passed; `SMOKE: done`, with dungeon objective/interaction HUD and town service overlay captures inspected.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/interaction_snapshot_builder.gd`: Owns objective guide and route/monster/event/door/secret/loot/trap affordance detail text.
- `scripts/runtime/grid_scene.gd`: Keeps compatibility delegates for existing helper callers.
- `docs/planning/next_implementation_priority.md`: Records the interaction guide cleanup.

## Follow-ups
- Remaining work: Split objective guide into its own helper later only if the interaction snapshot builder becomes too broad.

# Task: Runtime HUD snapshot builder

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` runtime display responsibility.
Goal: Move HUD snapshot dictionary construction into the runtime snapshot helper while keeping the public scene call used by `grid_hud.gd`.

## P0
- Required item: `hud_snapshot()` construction moves out of `grid_scene.gd`.
- Required item: `grid_hud.gd` can still call `scene_ref.call("hud_snapshot")`.
- Required item: minimap, objective, interaction, route, field AI, quest marker, party, inventory, and log snapshot fields remain compatible.

## P1
- Important item: avoid save schema, editor payload, or imported manifest behavior changes.
- Important item: keep existing smoke/test helper calls stable.

## P2
- Optional/follow-up item: later split HUD text formatting from minimap data if the runtime helper grows too broad.

## Scope
In:
- Runtime HUD snapshot assembly.
- Existing runtime snapshot helper boundary.

Out:
- UI layout.
- Content data changes.
- Save schema changes.
- Editor authoring features.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/runtime_snapshot_builder.gd`
- `scripts/ui/grid_hud.gd`
- `scripts/tests/grid_scene_smoke_driver.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` exposes `hud_snapshot()` only as a delegate.
- `runtime_snapshot_builder.gd` owns the HUD/minimap snapshot dictionary shape.
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
- Result: Passed; `SMOKE: done`, with town and dungeon HUD/minimap captures inspected.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/runtime_snapshot_builder.gd`: Owns full runtime HUD snapshot dictionary construction.
- `scripts/runtime/grid_scene.gd`: Keeps `hud_snapshot()` as a public delegate for the HUD UI.
- `docs/planning/next_implementation_priority.md`: Records the runtime HUD snapshot cleanup.

## Follow-ups
- Remaining work: Later split HUD text formatting from minimap data if this helper grows too broad.

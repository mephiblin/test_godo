# Task: Interaction snapshot builder pass

Date: 2026-05-24
Request: Continue Godot port cleanup by reducing `grid_scene.gd` mixed runtime responsibility.
Goal: Move interaction HUD snapshot/prompt construction out of the scene script into a dedicated runtime helper without changing gameplay behavior.

## P0
- Required item: `grid_scene.gd` delegates interaction snapshot and prompt text construction to a runtime helper.
- Required item: preserve town focus fallback, dungeon interaction details, route blocked state, intent labels, next-step hints, and HUD guide text.

## P1
- Important item: avoid new gameplay or authoring features.
- Important item: keep imported runtime/editor/game smoke checks passing.

## P2
- Optional/follow-up item: later split town-specific and dungeon-specific interaction detail providers if this helper becomes too broad.

## Scope
In:
- Interaction snapshot/prompt construction.
- Existing interaction HUD data shape.

Out:
- Interaction trigger behavior.
- Route/combat/event/loot service logic.
- UI layout changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_focus_runtime.gd`
- `scripts/ui/grid_hud.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `grid_scene.gd` no longer owns the large `_interaction_snapshot()` builder body.
- Existing HUD interaction dictionary fields remain available.
- Relevant Godot boot/probe/smoke checks pass.

## Verification
- Command: Godot headless boot
- Expected: exits 0
- Result: Passed.
- Command: validation probe
- Expected: validation succeeds
- Result: Passed. `VALIDATION definitions_ok=true map_ok=true`
- Command: imported runtime probe
- Expected: imported-only runtime boundary succeeds
- Result: Passed. `IMPORTED_RUNTIME_PROBE ok=true manifest=res://data/imported/content_build_manifest.json`
- Command: editor smoke
- Expected: editor/build/imported boundary checks succeed
- Result: Passed. `EDITOR_SMOKE ... imported_manifest_flow_ok=true`
- Command: visual smoke
- Expected: title, town, dungeon, combat, reward, and editor fallback captures complete
- Result: Passed. Reached `SMOKE: done`; inspected `output/02_quest_board.png` and `output/04_dungeon.png`.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/grid_scene.gd`: Delegates interaction snapshot and prompt text construction to `interaction_snapshot_builder.gd`.
- `scripts/runtime/interaction_snapshot_builder.gd`: Owns the current HUD interaction dictionary, prompt, intent, next-step, and guide text construction.
- `docs/planning/next_implementation_priority.md`: Records this runtime responsibility cleanup.

## Follow-ups
- Remaining work: Later split the helper into town and dungeon detail providers only if the current mixed builder becomes a practical blocker.

# Task: Dungeon Route Breadcrumb Tuning Pass

Date: 2026-05-24
Request: Continue the remaining Godot port work as playable game development, committing and pushing each major completed unit.
Goal: Make dungeon interaction route markers more readable in the actual 3D play view.

## P0
- Required item: Tune dungeon focus path marker density so longer routes do not flood the cell view.
- Required item: Lift path markers above the floor and animate them so they remain visible through dungeon clutter.
- Required item: Differentiate blocked routes, hazards, combat targets, rewards, rest, service, and normal route breadcrumbs with readable color/shape emphasis.

## P1
- Important item: Preserve existing dungeon HUD intent and world marker behavior.
- Important item: Keep town path markers unaffected.

## P2
- Optional/follow-up item: Do manual camera/play tuning for final marker size after longer play sessions.

## Scope
In:
- Dungeon focus path marker generation and animation.
- Planning backlog update.

Out:
- Full dungeon camera rewrite.
- Town marker presentation changes.
- New content placements.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Active dungeon interactions still draw a path when route data exists.
- Long paths use sampled breadcrumbs instead of one marker per cell.
- The next step and final target are visually distinct.
- Blocked routes and dangerous targets use different marker tone from normal route/reward targets.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: exits 0
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: exits 0
- Result: Passed, `VALIDATION definitions_ok=true map_ok=true`.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: exits 0 and captures dungeon/combat/editor routes
- Result: Passed, including town, dungeon floor 1/2/3, combat, reward, and editor fallback captures.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Implemented. Dungeon interaction path markers now sample long paths, raise the next/final breadcrumbs above the floor, pulse/rotate active breadcrumbs, and use intent-specific color/shape treatment for blocked routes, hazards/combat, rewards, rest/service, and routes.

## Files Changed
- `scripts/runtime/grid_scene.gd`: Added sampled dungeon focus path indices, marker mesh/height/scale/color helpers, and animation metadata for route breadcrumbs.
- `docs/planning/next_implementation_priority.md`: Marked dungeon route breadcrumb tuning complete and narrowed the remaining manual play-tuning follow-up.
- `docs/tasks/2026-05-24-dungeon-route-breadcrumb-tuning-pass.md`: Recorded scope, acceptance, verification, results, and follow-ups.

## Follow-ups
- Remaining work: Manual play tuning for marker density/occlusion in narrow halls and crowded authored encounters.

# Task: Town presenter wrapper cleanup pass

Date: 2026-05-24
Request:
Continue the Godot port cleanup by reducing town-only wrapper methods on the generic grid scene.
Goal:
Remove simple `town_world_presenter` pass-through wrappers from `grid_scene.gd` and call the presenter directly from town-owned code paths.

## P0
- Required item: remove trivial town presenter wrapper methods from `grid_scene.gd`.
- Required item: keep town world build, ambient animation, and focus visuals working.

## P1
- Important item: verify Godot boot, validation, imported runtime, editor smoke, and visual smoke still pass.
- Important item: update current implementation priority notes.

## P2
- Optional/follow-up item: continue reducing remaining town focus wrappers where they carry no shared grid responsibility.

## Scope
In:
- Town presenter call routing.
- Generic grid scene surface cleanup.
- Task and priority documentation.

Out:
- New town visual features.
- Dungeon presentation changes.
- Unrelated Godot `.uid` cleanup.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_scene.gd`
- `scripts/runtime/town_world_presenter.gd`

## Acceptance
- `grid_scene.gd` no longer exposes trivial `_build_town_world()`, `_spawn_town_placement()`, `_animate_town_ambient()`, or `_animate_town_focus_anchor()` wrappers.
- Town visual smoke still captures town hub, service, and fallback editor screens.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Result: Passed; `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/imported_runtime_probe.gd`
- Result: Passed; `IMPORTED_RUNTIME_PROBE ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Result: Passed; editor smoke reported all core checks true.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Result: Passed; visual smoke reached `SMOKE: done`.
- Command: `git diff --check`
- Result: Passed.

## Result
- Status: Complete.

## Files Changed
- `scripts/runtime/grid_scene.gd`: removed trivial town presenter wrapper methods.
- `scripts/runtime/town_scene.gd`: calls `town_world_presenter` directly for ambient/focus animation.
- `scripts/runtime/town_world_presenter.gd`: spawns town placements directly and asks the scene only for runtime beacon registration.
- `docs/planning/next_implementation_priority.md`: recorded the responsibility cleanup.

## Follow-ups
- Remaining work: continue reducing generic grid responsibilities that only apply to town runtime.

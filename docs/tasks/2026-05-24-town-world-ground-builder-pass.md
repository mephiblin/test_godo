# Task: Town World Ground Builder Pass

Date: 2026-05-24
Request: Continue the remaining Godot port work as playable game development, committing and pushing each major completed unit.
Goal: Move another concrete slice of town-only world presentation out of the generic dungeon runtime.

## P0
- Required item: Move town world build loop and lighting setup into `town_world_presenter.gd`.
- Required item: Move town ground, path, and boundary mesh construction into `town_world_presenter.gd`.

## P1
- Important item: Preserve town landmark, ambient, focus, and visual smoke behavior.
- Important item: Keep dungeon world building untouched.

## P2
- Optional/follow-up item: Move remaining town landmark helper meshes into a dedicated town builder/presenter.

## Scope
In:
- Town ground/path/boundary presentation ownership.
- Planning backlog update.

Out:
- Full town landmark/NPC mesh extraction.
- Town focus marker extraction.
- Gameplay content changes.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_world_presenter.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- `town_world_presenter.gd` owns the town map cell build loop, lighting, ground path tiles, and boundary meshes.
- `grid_scene.gd` no longer contains town ground/path/boundary mesh helpers.
- Existing town/dungeon visual smoke still passes.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: exits 0
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: exits 0
- Result: Passed, `VALIDATION definitions_ok=true map_ok=true`.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: exits 0 and captures town/dungeon/combat/editor routes
- Result: Passed, including town, dungeon floor 1/2/3, combat, reward, and editor fallback captures.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Implemented. `town_world_presenter.gd` now owns town lighting, the cell build loop, ground/path tile meshes, and boundary meshes. `grid_scene.gd` still owns the remaining town landmark/actor helpers for the next split.

## Files Changed
- `scripts/runtime/town_world_presenter.gd`: Added town map loop, lighting setup, ground/path tile construction, boundary construction, and local material helpers.
- `scripts/runtime/grid_scene.gd`: Removed town ground/path/boundary build helpers and now delegates that layer to the presenter.
- `docs/planning/next_implementation_priority.md`: Marked town ground builder split complete and narrowed the remaining town runtime split.
- `docs/tasks/2026-05-24-town-world-ground-builder-pass.md`: Recorded scope, acceptance, verification, result, and follow-ups.

## Follow-ups
- Remaining work: Move town landmark and actor mesh construction helpers out of `grid_scene.gd`.

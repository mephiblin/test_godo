# Task: Town World Presenter Separation Pass

Date: 2026-05-24
Request: Continue the remaining Godot port work as real gameplay implementation, with commit and push after each large unit.
Goal: Reduce town-specific presentation ownership in the generic dungeon runtime while preserving playable town visuals.

## P0
- Required item: Move town ambient presentation state and animation ownership out of `grid_scene.gd`.
- Required item: Route town world build through a town-specific presenter entrypoint.

## P1
- Important item: Keep existing town hub markers, ambient animation, and visual smoke behavior intact.

## P2
- Optional/follow-up item: Move the remaining town landmark mesh helper methods out of `grid_scene.gd`.

## Scope
In:
- Town world presenter runtime helper.
- Town ambient animation state ownership.
- Planning backlog update.

Out:
- Full town landmark mesh helper extraction.
- Dungeon affordance tuning.
- Editor authoring expansion.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_scene.gd`
- `docs/planning/next_implementation_priority.md`

## Acceptance
- Town maps still build their 3D world and ambient dressing.
- `grid_scene.gd` no longer owns the `town_ambient_nodes` array directly.
- Existing headless and visual smoke commands pass.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: exits 0
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: exits 0
- Result: Passed, `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: exits 0
- Result: Passed, including `definition_authoring_ok=true`, `placement_affordance_ok=true`, `bundle_ok=true`, and `content_ok=true`.
- Command: `CONAN_DOT_DOMAIN_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan`
- Expected: exits 0
- Result: Passed on rerun, `DOMAIN_SMOKE ok=true stock_before=2 stock_refresh=2 stock_after=1`. The first run returned `ok=false` with the same stock counts; the generated report showed stock refresh content changed, so the command was rerun to check for smoke nondeterminism.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: exits 0 and writes smoke artifacts
- Result: Passed, including title, town, dungeon floors, combat, reward, and editor fallback captures.
- Command: `git diff --check`
- Expected: no whitespace errors
- Result: Passed.

## Result
- Status: Implemented. Town ambient animation entries now live in `town_world_presenter.gd`, and town world construction is routed through a town-specific presenter entrypoint while the existing town mesh helpers remain in place for the next extraction pass.

## Files Changed
- `scripts/runtime/town_world_presenter.gd`: Added town presentation helper that owns ambient node registration, ambient animation, and the town world build entrypoint.
- `scripts/runtime/grid_scene.gd`: Delegated town ambient state and build routing to the presenter.
- `docs/planning/next_implementation_priority.md`: Marked the presenter separation pass complete and narrowed the next town runtime step.
- `docs/tasks/2026-05-24-town-world-presenter-separation-pass.md`: Recorded scope, results, verification, and follow-ups.

## Follow-ups
- Remaining work: Move town landmark mesh construction helpers into the presenter or a dedicated town world builder.

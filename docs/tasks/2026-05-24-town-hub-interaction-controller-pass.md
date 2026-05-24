# Task: Town hub interaction controller pass

Date: 2026-05-24
Request:
Continue the Godot port cleanup by moving town-specific interaction responsibility out of the generic grid scene.
Goal:
Move town hub selected/nearby interaction decision logic from `grid_scene.gd` into `town_hub_controller.gd`.

## P0
- Required item: keep generic `_interact_forward()` focused on front-cell interactions.
- Required item: make town `Space/Enter` use `town_hub_controller` for selected hub approach and nearby hub fallback.

## P1
- Important item: verify Godot boot, validation, imported runtime, editor smoke, and visual smoke still pass.
- Important item: update current implementation priority notes.

## P2
- Optional/follow-up item: continue moving remaining town-only wrappers out of `grid_scene.gd` where practical.

## Scope
In:
- Town hub interaction input handling.
- Generic grid interaction branch cleanup.
- Task and priority documentation.

Out:
- New town gameplay actions.
- Dungeon interaction behavior changes.
- Unrelated Godot `.uid` cleanup.

## Files To Inspect
- `scripts/runtime/grid_scene.gd`
- `scripts/runtime/town_hub_controller.gd`
- `scripts/runtime/town_scene.gd`

## Acceptance
- `grid_scene.gd` no longer owns selected/nearby town hub fallback interaction logic.
- Town `Space/Enter` still approaches selected hubs and opens nearby services.
- Dungeon front-cell interaction remains unchanged.

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
- `scripts/runtime/grid_scene.gd`: removed selected/nearby town hub fallback interaction branch from generic front interaction.
- `scripts/runtime/town_hub_controller.gd`: added town hub `interact()` behavior for front, selected, and nearby hub actions.
- `docs/planning/next_implementation_priority.md`: recorded the responsibility cleanup.

## Follow-ups
- Remaining work: continue reducing town-only interaction and focus wrappers in the generic grid runtime.

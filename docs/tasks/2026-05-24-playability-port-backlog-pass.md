# Task: Playability Port Backlog Pass

Date: 2026-05-24
Request: 남은 Godot 포팅 작업을 확인해 목록화하고, 실제 플레이 가능한 게임 개발 중심으로 큰 단위마다 구현/검수/디버깅/커밋/푸시한다.
Goal: 문서상 잔여 항목을 실제 플레이 루프 기준 backlog로 재정렬하고, 첫 완료 단위로 objective/gate readability와 editor guided authoring을 강화한다.

## Remaining Porting Backlog
- P0: Dungeon/town runtime boundary cleanup: remaining town focus/anchor/proximity/service helpers should leave generic dungeon runtime.
- P0: Dungeon play readability: add stronger path-to-object/world guidance and objective/gate explanations during play.
- P0: Editor authoring parity: move from preview/import tools toward direct map/event/NPC guided authoring.
- P0: Validation/import contract: add fixture-level negative tests and stricter source/imported/export boundaries.
- P1: Field monster content depth: broaden authored AI/faction combinations only where they improve actual play.
- P1: Combat hardening: add direct domain assertions, broader combatProfile coverage, and reward/end-state polish.
- P1: NPC/quest/shop expansion: broaden quest seed hooks and objective/gating explanations across town/dungeon.
- P1: Save/packaging: collect wider exported-build play evidence and harden save regressions.
- P2: Test stack structure: separate domain, validator, scene, smoke, export, and benchmark checks.
- P2: Data authority: formalize source_json/imported/user project boundaries and canonical JSON write-back.
- P2: Planning sync: keep status docs honest as implementation diverges from older C# plan.

## P0
- Required item: play objective/gate guide를 dungeon/town HUD에 더 직접적으로 노출한다.
- Required item: dungeon path-to-object world guidance를 next-step marker 수준으로 강화한다.

## P1
- Important item: editor placement quick actions를 event/NPC authoring에 더 가까운 guided field editor로 확장한다.

## P2
- Optional/follow-up item: validation fixture tests, combat domain tests, packaging/CI는 다음 큰 단위로 분리한다.

## Scope
In:
- runtime objective/gate guide
- dungeon world next-step guidance
- editor guided placement fields
- planning/task docs
Out:
- full editor graph rewrite
- complete town runtime extraction
- C# migration
- CI setup

## Files To Inspect
- docs/planning/engine-port/godot-port-status.md
- docs/planning/next_implementation_priority.md
- scripts/runtime/grid_scene.gd
- scripts/ui/grid_hud.gd
- scripts/runtime/town_scene.gd
- scripts/ui/town_hud.gd
- addons/connan_editor/docks/content_editor_dock.gd

## Acceptance
- Player can read current objective/gate state without relying only on smoke artifacts.
- Dungeon active interaction has a visible next-step/path guide in world presentation.
- Editor exposes direct guided fields for event/NPC placement work, not only quick presets.
- Godot headless boot, validation, editor smoke, visual smoke, and diff check pass.
- Each completed large unit is committed and pushed.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds.
- Result: Passed.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: validation passes.
- Result: Passed. `VALIDATION definitions_ok=true map_ok=true`.
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor smoke passes.
- Result: Passed. `EDITOR_SMOKE ... placement_affordance_ok=true ... compiled_handoff=true authored_handoff=true`.
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: visual smoke captures playable town/dungeon/combat/editor screens.
- Result: Passed. Captured town, dungeon floor 1/2/3, combat, reward, defeat, and editor fallback screens.
- Command: `git diff --check`
- Expected: no whitespace errors.
- Result: Passed.

## Result
- Status: Done
- Listed the remaining Godot porting backlog by gameplay risk instead of only document categories.
- Added HUD objective guidance for quest targets, active quest seeds, and blocked gate requirements.
- Added dungeon world-space path markers from the player toward the active interaction target.
- Added editor guided authoring selectors for event/rest/trap event IDs and NPC service NPC IDs, plus label sync actions.

## Files Changed
- addons/connan_editor/docks/content_editor_dock.gd: added guided event/NPC placement authoring controls.
- docs/planning/next_implementation_priority.md: recorded completed playability pass and next tuning work.
- docs/tasks/2026-05-24-playability-port-backlog-pass.md:
- scripts/runtime/grid_scene.gd: added objective snapshots and dungeon focus path markers.
- scripts/ui/grid_hud.gd: added objective panel rendering.

## Follow-ups
- Remaining work: manual playtest path marker readability, deeper event graph/NPC service editing, validation fixture tests, direct combat domain tests, town runtime extraction cleanup.

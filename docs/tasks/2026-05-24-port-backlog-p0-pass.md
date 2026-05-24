# Task: Port Backlog P0 Pass

Date: 2026-05-24
Request: `godot-port-plan.md` 기준 남은 작업 전체를 진행한다.
Goal: 전체 잔여 milestone 중 현재 턴에서 안전하게 닫을 수 있는 P0 기반 개선을 구현하고, 남은 대형 항목을 다음 작업 단위로 남긴다.

## P0
- Required item: `grid_hud.gd` 안의 town 전용 HUD를 별도 `town_hud.gd`로 분리한다.
- Required item: dungeon interaction prompt를 door/stairs/event/trap/NPC/combat/loot 의도와 gate 상태를 더 잘 설명하도록 강화한다.
- Required item: floor 2/3 authored field AI와 alert group 적용 범위를 넓힌다.
- Required item: validation/import 계약에 event graph, effect target, quest seed reward, NPC service handoff 검증을 추가한다.
- Required item: 현재 GDScript-first 구현 방향과 C# 계획 차이를 문서에 명시한다.

## P1
- Important item: field monster 추적을 greedy step에서 route/funnel 기반 step 선택으로 개선한다.
- Important item: source JSON을 canonical source로 유지하고 imported cache는 build 산출물로 둔다는 계약을 문서화한다.

## P2
- Optional/follow-up item: editor full authoring parity, full test hierarchy, CI, packaging polish는 별도 milestone으로 이어간다.

## Scope
In:
- HUD script split
- Runtime affordance detail
- Field monster authored content and pathing
- Editor validation contract
- Planning docs
Out:
- Full C# migration
- Full editor workbench rebuild
- CI setup
- Complete combat/NPC/shop content expansion

## Files To Inspect
- scripts/runtime/grid_scene.gd
- scripts/runtime/town_scene.gd
- scripts/ui/grid_hud.gd
- scripts/editor/content_tools.gd
- data/source_json/maps/dungeon_floor_02.json
- data/source_json/maps/dungeon_floor_03.json
- docs/planning/next_implementation_priority.md
- docs/planning/engine-port/godot-port-status.md

## Acceptance
- Town HUD focus UI is owned by `scripts/ui/town_hud.gd`, while `grid_hud.gd` remains generic/dungeon-capable.
- Dungeon interaction snapshot contains richer target intent and concrete route/event/trap/combat/door/reward detail.
- Floor 2 and 3 have authored field AI coverage beyond the initial floor 1 slice.
- Editor validation catches broken event entry/step refs, effect item/quest seed refs, NPC service handoff refs, and quest reward item refs.
- Godot headless boot and validation smoke pass.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds.
- Result: passed
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/validation_probe.gd`
- Expected: definition and map validation pass.
- Result: passed, `definitions_ok=true map_ok=true`
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --script res://scripts/tests/editor_smoke.gd`
- Expected: editor validation/build/preview smoke passes.
- Result: passed

## Result
- Status: Done
- Split town-specific focus HUD out of `grid_hud.gd` into `town_hud.gd`; `TownScene` now builds the town HUD explicitly.
- Strengthened dungeon interaction detail for routes, gates, events, traps, doors, secrets, loot, and field monsters.
- Added route-based monster path stepping before the old greedy fallback.
- Added authored floor 2/3 field monsters with AI behavior, alert groups, factions, patrol/ambush settings, and imported cache updates.
- Added missing skill definitions used by the existing skill merchant catalog so stricter validation can pass.
- Expanded editor validation for event graph refs, event effect item/quest-seed refs, NPC service handoff refs, vendor skill/item refs, and quest reward refs.
- Updated planning docs to record the GDScript-first hardening decision and current remaining work.

## Files Changed
- addons/connan_editor/docks/content_editor_dock.gd: uses latest definition data for service catalog/stock previews.
- data/imported/content_build_manifest.json: regenerated build manifest.
- data/imported/maps/dungeon_floor_02.json: regenerated imported map with new authored field AI placements.
- data/imported/maps/dungeon_floor_03.json: regenerated imported map with new authored field AI placements.
- data/source_json/maps/dungeon_floor_02.json: added black-water patrol and ambush authored field monsters.
- data/source_json/maps/dungeon_floor_03.json: expanded blind priest AI and added sanctuary guard.
- data/source_json/npcs.json: fixed trainer opens-service catalog to a stable authored skill list.
- data/source_json/skills.json: added referenced skill definitions for the wider merchant catalog.
- docs/planning/engine-port/godot-port-status.md: updated current status and GDScript-first direction.
- docs/planning/next_implementation_priority.md: marked completed P0 pass items and next follow-ups.
- scripts/editor/content_tools.gd: expanded validation reference checks.
- scripts/runtime/grid_scene.gd: added dungeon affordance details and path-based monster stepping.
- scripts/runtime/town_scene.gd: builds `town_hud.gd`.
- scripts/tests/validation_probe.gd: adds a direct validation command.
- scripts/ui/grid_hud.gd: removed town focus HUD ownership.
- scripts/ui/town_hud.gd: owns town focus radial/strip/detail UI.

## Follow-ups
- Remaining work: Continue the editor parity, combat/NPC expansion, save/packaging, test hierarchy, and CI milestones as scoped tasks.

# Task: Town 3D Field Foundation

Date: 2026-05-24
Request: 스모크테스트가 아니라 실제 게임요소를 구현해야지 엔진에서 뭐하는거야
Goal: Godot town runtime을 던전 재사용 화면이 아니라 실제 3D hub field처럼 보이고 읽히는 상태로 올린다.

## P0
- town 전용 월드 빌드 분기 추가
- 주요 town placement를 실제 3D 구조물과 상호작용 지점으로 표현

## P1
- town route/서비스가 시각적으로 구분되도록 표지/하이라이트 추가
- 기존 이동/상호작용 루프와 호환되게 유지
- 정면 상호작용 prompt와 highlight 추가

## P2
- smoke 시각 산출물에서 town 변화 확인

## Scope
In:
- `town_square` 런타임 3D 월드 구성
- town placement 전용 prop/landmark
- 관련 시각 smoke 검증

Out:
- 새로운 town quest/service 규칙 추가
- full town-specific control scheme 분리

## Files To Inspect
- scripts/runtime/grid_scene.gd
- scenes/town/TownScene.tscn
- data/source_json/maps/town_square.json
- scripts/ui/main_root.gd

## Acceptance
- town scene가 dungeon과 다른 3D 허브 공간으로 렌더된다.
- quest board, healer, skill shop, trade, NPC, gate, rest가 개별 시각 landmark를 가진다.
- 기존 town 상호작용 루프가 유지된다.

## Verification
- Command: `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path /home/inri/문서/conan_dot/conan --quit`
- Expected: headless boot succeeds
- Result: passed
- Command: `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path /home/inri/문서/conan_dot/conan --smoke`
- Expected: town screenshot updates with town-specific field rendering
- Result: passed, `03_town.png`, `02_gatekeeper.png`, `02_quest_board.png` regenerated

## Result
- Status: Done

## Files Changed
- scenes/town/TownScene.tscn:
  - `grid_scene.gd` 직결에서 `town_scene.gd` 전용 스크립트로 전환
- scripts/runtime/grid_scene.gd:
  - town 전용 월드 빌드 분기 추가
  - town ground, boundary, gate, stall, tent, board, campfire, landmark prop 추가
  - placement beacon/runtime route color 분리
  - town service/NPC placement에 actor silhouette mesh 추가
  - town 전용 카메라 프로필 추가
  - town ambient animation registry 추가
  - actor idle bob, tent/banner sway, campfire/gate light flicker 추가
  - campfire ember와 plaza mote dressing 추가
  - town proximity interaction fallback 추가
  - 정면이 아니어도 nearby hub prompt와 alignment hint를 표시
  - town prompt에 quest board/shop/NPC service preview 추가
- scripts/runtime/town_hub_controller.gd:
  - town 전용 입력/허브 focus controller helper 추가
- scripts/runtime/town_scene.gd:
  - town scene 전용 runtime wrapper 추가
  - town hub controller를 scene 레벨에서 연결하고 town input routing을 위임
  - town-only `_process`와 `hud_snapshot` 확장 payload를 담당
- scripts/ui/grid_hud.gd:
  - 정면 상호작용 대상과 action/detail을 보여주는 prompt panel 추가
  - town일 때 더 좁은 HUD 레이아웃 적용
- docs/tasks/2026-05-24-town-3d-field-foundation.md:
  - 작업 결과 및 검증 기록

## Follow-ups
- Remaining work:
  - town hub focus를 radial affordance까지 확장
  - town 전용 ambient FX를 더 눈에 띄게 만드는 장식물/입자 계층
  - 필요 시 town 전용 scene/controller 분리
- Camera update:
  - town camera now uses a pulled-back profile so actors, tents, and stalls are actually visible in `03_town.png`.
- Ambient update:
  - town runtime now animates actor idle staging, tent/banner sway, and campfire/gate light flicker during play.
  - visible ember and dust-mote meshes were added so the static town frame is less empty even in screenshots.
- Interaction update:
  - in town, nearby board/service/rest surfaces are now surfaced by prompt even when not perfectly front-aligned.
  - `Space` can fall back to a nearby hub surface at distance 1 instead of failing on strict forward alignment.
  - prompt now exposes service previews such as board offer count, skill stock rows, and NPC service rows before opening the overlay.
- Controller update:
  - town now maintains a nearby hub selection list within range 2 and lets the player cycle it with `Q` / `E`.
  - when nothing is directly in front, the selected hub becomes the active prompt/focus target and `Space` interacts with that selected hub.
  - prompt detail now shows the current selection strip so the active hub is explicit instead of relying on nearest-target fallback.
  - cycling a hub now also soft-locks facing toward that hub, so town interaction is not tied to strict dungeon-style forward alignment.
  - HUD now renders a dedicated `Hub Focus` bar with nearby targets, selected state, distance, and the `Q/E + Space` control contract.
  - pressing `Space` on a distant selected hub now advances one tile toward its interaction anchor instead of trying to open the service immediately.
  - smoke report now captures `source = "selected"` and `action = "Space로 접근"` states in town snapshots.
  - `Hub Focus` bar now renders segmented hub chips instead of text-only rows, and the currently selected target stays visually distinct from the active front interaction highlight in the 3D world.
  - selected hubs now expose their resolved interaction anchor in runtime snapshots, and the anchor is rendered as a pulsing floor marker in the 3D town scene.
  - town auto-approach now uses a shortest-step BFS toward that anchor instead of a purely greedy distance step.
  - `Hub Focus` chips are now type-colored (`의뢰/치료/기술/상점/NPC/휴식`) so selected services are distinguishable without reading the long prompt text.
  - the world anchor marker now inherits service-type color and scale so the selected destination is readable both in HUD and in the 3D scene.
  - town HUD now also renders a small radial-style focus row (`< / ● / >`) around the currently selected hub, so the town interaction surface is less tied to a flat dungeon-status strip.
  - the selected hub now renders a dotted world path from the player to the resolved interaction anchor, so town movement intent is visible on the field instead of only in HUD text.
  - world anchor markers now also vary by mesh shape across service types, so board/heal/shop/trade/NPC targets are distinguishable even without relying on text color alone.
  - in town, `W` now prefers advancing along the selected hub path, and runtime snapshots expose `nextStep` / `pathLength` so this controller contract is visible in smoke artifacts.
  - in town, `A/D` now default to hub focus cycling while manual facing rotates on `Left/Right`, pushing the controller further away from dungeon-style `A/D turn` semantics.
  - town-specific input routing now lives in `town_hub_controller.gd`, so the controller contract is no longer embedded only in `grid_scene.gd`.
  - `TownScene.tscn` now owns a dedicated `town_scene.gd` wrapper, so the town route no longer points directly at the generic grid runtime script.
  - town HUD payload (`hudMode = town`, `townFocus`) and town-only update loop now resolve through `town_scene.gd`, reducing the amount of town-specific presentation state owned by the generic grid runtime.

## Additional Result
- Added front-facing interaction prompt and beacon focus for town/runtime readability.
- `03_town.png` now shows the active quest-board prompt, and focused landmarks scale/lighten when faced.
- Added role-colored town actor silhouettes for board, healer, merchant, apothecary, scholar, scout, trainer, and gatekeeper surfaces.
- Verified headless boot and full smoke after replacing invalid CapsuleMesh usage with CylinderMesh body meshes.

# Task: Godot M0-M3 Bootstrap

Date: 2026-05-23
Request: `godot-port-plan.md`를 기준으로 Godot 프로젝트를 실제 구현한다. 작업 중 스모크와 시각 테스트를 수행한다.
Goal: 빈 Godot 프로젝트에 M0-M2 중심 vertical slice를 만들고, title/town/dungeon/combat/editor fallback route와 content/save skeleton을 동작시킨다.

## P0
- Required item: autoload service, scene routing, title shell을 만든다.
- Required item: manifest 기반 town/dungeon authored map 로드와 grid movement를 만든다.
- Required item: 3-slot save skeleton과 runtime save delta를 연결한다.
- Required item: smoke/screenshot runner를 만들어 시각 테스트를 남긴다.

## P1
- Important item: field monster blocker와 combat round-trip을 최소한으로 연결한다.
- Important item: editor fallback route를 분리한다.

## P2
- Optional/follow-up item: 이후 C# 전환 또는 full editor plugin 구현은 다음 task로 둔다.

## Scope
In:
- Godot project bootstrap, scenes, scripts, source JSON maps, smoke runner
Out:
- full editor plugin
- full data import from all web JSON families
- production packaging

## Acceptance
- Godot project opens into title shell and can route to town/dungeon/combat/editor.
- authored/compiled style map JSON loads and drives movement/collision/interaction.
- save slot JSON is written to `user://saves`.
- smoke run produces screenshots.

## Result
- Status: Completed
- Implemented a GDScript-first bootstrap because Godot 4.6 binary was available but
  `.NET` was not installed in the target machine.
- Added autoload services for `GameApp`, `ContentRegistry`, `SaveService`,
  `SceneRouter`.
- Added title shell, town route, dungeon route, combat route, and editor fallback
  route.
- Added authored source JSON content manifest and two minimal maps:
  `town_square`, `dungeon_floor_01`.
- Added grid movement, facing, interaction, field-monster blocker handling, combat
  round-trip, and slot save JSON updates.
- Extended runtime with first-pass M4 service loop:
  quest board accept -> dungeon field monster defeat -> town reward claim, plus
  healer and skill shop overlays.
- Added first-pass M5 editor tooling:
  `ConnanEditor` plugin dock, JSON definition editing for monsters/skills/items/quests,
  validation, and manifest report export.
- Added `data/imported/content_build_manifest.json` and compiled map export flow.
- Runtime now prefers imported build manifest when present, and smoke verification
  confirms the project is loading `res://data/imported/content_build_manifest.json`.
- Added map validation and build bundle export buttons to the editor dock, plus
  editor-side town/dungeon test-play launch buttons.
- Added new game setup fields for player name, class, background, start supply,
  and target slot in the title shell.
- Added save-slot metadata presentation plus rename/delete actions in the title
  shell.
- Added inventory overlay in runtime and first-pass item persistence.
- Added dungeon interaction state for secret cache, locked door, loot pickup, trap
  penalty, and rest point handling.
- Added combat-side healing tonic usage.
- Imported additional web data families into the Godot project:
  `encounters`, `events`, `loot_tables`, `map_chunks`, `map_profiles`,
  `materials`, `npcs`, `object_themes`, `tile_substitutions`.
- Expanded content loaders so manifest definitions can be sourced from either
  array JSON or keyed-object JSON without changing runtime/editor callers.
- Extended editor validation and manifest reporting to cover all definition kinds,
  plus cross-checks for map `npcId` / `eventId` / `lootTableId`.
- Bound runtime town and dungeon placements more directly to content data through
  `npcId`, `vendorId`, `eventId`, and `lootTableId`.
- Added first-pass dungeon world metadata consumption:
  authored map now carries `mapProfileId`, `themeId`, `objectThemeId`,
  `wallMaterialId`, `ceilingMaterialId`, `defaultFloorMaterialId`, and
  `sourceChunkIds`.
- Runtime dungeon scene now resolves `map_profiles`, `materials`,
  `tile_substitutions`, and `object_themes` to enrich HUD metadata and generate
  theme-aware floor/wall/ceiling/decor state.
- Editor fallback workspace now surfaces dungeon profile/theme/chunk information
  from imported content, instead of only reporting definition counts.
- Added first-pass compiled dungeon preview export from `mapProfileId` and
  `sourceChunkIds`, so the editor/build flow emits a concrete preview artifact
  before full generator parity exists.
- Expanded compiled preview from a token list into a layout artifact:
  chunk grid size, chunk cell rects, and anchor absolute positions are now
  exported and embedded into imported compiled maps.
- Runtime dungeon HUD now resolves the active chunk from compiled preview data and
  reads the imported chunk layout rather than only raw authored metadata.
- Build pipeline now emits coarse `generatedCells`, `generatedPlacements`, and
  `generatedStart` from the compiled chunk layout, giving the imported map a first
  assembled floor candidate beyond the authored placeholder grid.
- Dungeon runtime now promotes the imported compiled preview into the active
  runtime map for dungeon routes, while merging authored placements so the current
  combat/quest smoke loop still survives on top of generated grid data.
- Generated placement coverage is now broader than a single loot cache:
  chunk role tags emit generated guard encounters and shrine/rest points, reducing
  reliance on authored-only dungeon placements.
- Runtime/editor/test-play now surface dungeon source explicitly so authored vs
  compiled dungeon routes can be distinguished during iteration.
- Compiled dungeon progression loop now owns more of the smoke path directly:
  generated placements include quest-target combat and return stairs, and compiled
  mode prioritizes those placements ahead of authored supplements.
- Runtime save/continue now persists `dungeonSource`, and compiled-mode placement
  merge suppresses authored stairs/rest/loot or duplicate authored field monsters
  when generated replacements already exist.
- Combat/runtime bookkeeping now separates generated monster instance ids from
  logical monster ids, so compiled dungeon fights correctly mark blocker defeat
  by placement instance while quest completion resolves against the target
  monster definition.
- Save schema is now versioned at `2`, and legacy save-slot data is migrated
  forward on read instead of assuming current-field completeness.
- Save migration now preserves and backfills the broader web-era concept fields:
  `party`, `companion`, `npcState`, `flags`, `runtimeMaps`, `floorState`,
  `visitedMapIds`, and `runtime.visitedCells`.
- Continue flow now blocks slots whose `contentVersion` is newer than the loaded
  content bundle, instead of silently opening potentially incompatible saves.
- Title shell now surfaces save/content version metadata plus slot-level blocked
  diagnostics so migration failures are visible before test-play.
- Added a dedicated save-migration smoke path in `Main.tscn` boot flow, and
  verified both legacy-save migration and future-content blocking behavior.
- Added first-pass Linux desktop export wiring:
  `export_presets.cfg`, local export template installation, and debug export boot
  smoke through the exported launcher script.
- Fixed editor-plugin export blockers by normalizing `plugin.cfg` script path and
  resolving GDScript parse issues in the content editor dock so editor-time export
  initialization no longer fails.
- Added first-pass domain smoke coverage for `quest accept -> skill shop stock ->
  reroll -> buy skill -> target defeat -> reward claim`, with a persisted
  `shopState` save surface and explicit smoke artifact.
- Replaced fixed skill-shop purchase behavior with slot-bound rotating stock from
  vendor skill pools, so the shop path now behaves as a real content-driven
  service instead of a hard-coded `power_slash` button.
- Added first-pass trade service runtime for vendor item purchase, and extended
  domain smoke to verify `trade -> inventory/gold delta` alongside quest/shop
  progression.
- Added first-pass content-driven event/effect interpreter through
  `EventService`, so trap/rest/shrine/altar/cache interactions no longer require
  ad hoc runtime branches for every outcome.
- Expanded save/runtime state to carry `food`, `water`, `torch`, and
  `partyState.front` (`hp`, `maxHp`, `statuses`), with migration backfill for
  older slots.
- Extended domain smoke to verify event-effect execution for poison trap,
  guarded rest, healing shrine, blood altar flag mutation, and scholar cache
  reward grant.
- Added first-pass `NpcService` runtime for engine-native `talk`, `identify`,
  and `recruit` service execution outside the web-style DOM/editor flow.
- Added scholar/scout town access points and a generic `npc_service` overlay
  menu so one NPC can expose multiple service rows with dialogue branching.
- Extended domain smoke to verify scholar dialogue traversal, relic identify
  persistence, and scout recruit persistence.
- Added first-pass quest-seed runtime state, reward claiming, and event-driven
  completion hooks so authored `questSeeds` can move through
  `active -> completed -> rewarded`.
- Extended `EventService` from flat effect playback to a minimal
  `entryStepId/choices/branches` resolver so authored event steps can pick
  condition-matching effects instead of only top-level fallback effects.
- Added first-pass `fight/avoid` NPC service outcomes: encounter handoff context
  build, gold-paid avoid branch, avoid/victory flags, and a dungeon captain
  placement that can exercise the same service surface as authored NPC data.
- Extended NPC fight handling from context generation to actual combat victory
  persistence: combat entry now syncs the target slot, victory writes NPC fight
  flags/state, and slot-aware NPC service menus hide recruit/fight actions once
  their state is already consumed.
- Extended domain smoke to drive the deserter captain through a real
  `enter combat -> smoke win -> return route` path, while keeping a separate
  avoid-branch save check.
- Added first-pass equipment state and identified-relic equip flow so inventory
  is no longer just a passive item list.
- Added cursed equipment behavior for identified relics: the sample black
  dagger equips into a weapon slot, applies a curse status, and blocks
  unequip as a real gameplay state instead of only a dialogue note.
- Extended inventory overlay from read-only text into a selectable item/equip
  surface with equipment summary and identify-sensitive item naming.
- Combat runtime now consumes `knownSkills` and monster definitions directly:
  purchased skills are assigned onto dice faces, attack/buff resolution writes
  to a local combat log, monster armor/attack ranges affect outcomes, and
  front-line HP now writes back into save state during combat.
- Domain smoke now verifies that the purchased skill appears on combat dice
  before the scripted NPC fight victory completes.
- Combat skill resolution is now data-driven beyond plain attack/buff:
  `skills.json` defines `effectKind`, armor break, guard gain, heal bonus, and
  lifesteal ratio, and combat applies those rules without hard-coding the skill
  id path.
- The skill shop pool now includes healing and lifesteal entries, and smoke
  reports persist per-roll combat metadata so purchased-skill handoff is visible
  in artifacts, not only inferred from final known-skill state.
- Combat item command now has real authored item behavior:
  `items.json` carries `combatUse` metadata, self-target consumables resolve
  immediately, enemy-target consumables create a pending item command, and the
  combat HUD now exposes front/enemy statuses plus pending item state.
- Domain smoke now drives combat item usage directly by applying poison before
  the NPC fight, then verifying `firebomb` burn application and `antivenom`
  poison cure inside the combat scene before victory.
- Combat HUD/state now exposes first-pass `target-required` and `cooldown`
  behavior: selected enemy-target skills enter a pending target confirm state,
  authored skills can define `cooldownKey`/`cooldownTurns`, and smoke captures
  the resulting target-pending and cooldown dictionaries from the live combat
  scene.
- Combat command surface now also covers `ClearSelection` and `Swap`: selected
  roll order is tracked in roll DTOs, two selected faces can swap authored
  skill payloads, clear resets pending target state, and smoke records that
  swap changed roll rows before clear emptied the selection.
- Added first-pass runtime/view-model separation for combat:
  `CombatRuntime` now owns mutable combat state, roll DTO creation, command
  resolution, and smoke probes, while `combat_scene.gd` is reduced to UI
  rendering and command forwarding.
- Extended `CombatViewModel` coverage toward the plan contract:
  active hero, selected roll ids, select limit, pending item state, enemy max HP,
  and enemy guard are now exposed through the runtime view model instead of being
  inferred inside the scene script.
- Added first-pass enemy AI/status formula behavior to combat runtime:
  guardian/defensive enemies build enemy guard, ambusher/caster enemies can
  inflict authored front-line statuses, poison ticks are processed in combat, and
  equipped resistance metadata can block status application.
- Extended domain smoke with direct combat runtime probes so enemy guard gain,
  poison resistance from equipped relics, and the widened combat view model are
  verified without depending only on the routed NPC fight path.
- Extended combat command API toward the plan contract:
  `PickItem`, `UseItem`, and `SelectTarget` are now explicit runtime commands
  instead of being implied only by repeated confirm presses.
- Combat view model now exposes `pendingTargetState` in addition to
  `pendingItemState`, so the HUD can reflect whether the current pending action
  came from a skill or an item command.
- Domain smoke now verifies the explicit item-command flow
  (`PickItem -> pending target state -> SelectTarget/UseItem -> clear pending state`)
  through a dedicated combat probe.
- Combat skill definitions now carry first-pass `effectOps`, and the runtime
  resolves those operation arrays before falling back to legacy `effectKind`.
- Roll debug rows now include serialized `effectOps`, so domain smoke artifacts
  show the actual definition-driven combat payload instead of only the selected
  skill ids and derived effect kind.
- Item `combatUse` now also supports first-pass `effectOps`, and the combat
  runtime resolves those operations through the same interpreter used for skill
  effects before falling back to legacy item effect fields.
- Enemy turn rules now support first-pass definition-driven `combatProfile` data
  on monster records, and the combat runtime resolves `turnOps` before falling
  back to generated defaults from the legacy `ai` label.
- Extracted combat view-model assembly into a dedicated helper so `CombatRuntime`
  keeps state ownership while `CombatViewModel`/roll-row serialization is built
  outside the state owner.
- Extracted combat HUD string/button presentation into a dedicated presenter so
  `combat_scene.gd` now mainly wires Controls to commands and consumes prepared
  presentation strings instead of formatting the HUD inline.
- Added first-pass benchmark smoke/report for the M6 latency targets:
  dungeon route build time, one-cell movement responsiveness, and scripted
  combat-loop latency are now measured into a JSON artifact.
- Added dedicated content bundle import smoke/report for the M6 import gate:
  imported manifest priority, compiled map bundle presence, generated cell
  payload, and required definition families are now asserted in a separate JSON
  artifact.
- Closed the editor/runtime handoff gap:
  editor save/export/build now reload the runtime content registry, editor dock
  test-play can target the selected map instead of only hard-coded town/dungeon
  defaults, and grid scenes can consume editor-provided play payloads when
  launched directly through `play_custom_scene`.
- Improved the editor dock into a more reliable typed authoring surface:
  array/object fields now edit as JSON blocks, bool fields use toggles, numeric
  fields use spin boxes, malformed JSON is blocked before save, and preview/status
  output now follows the currently selected map instead of only the dungeon
  default.
- Expanded `editor_smoke` from passive export checks into an actual edit-cycle
  verifier: it now proves invalid quest edits are blocked without touching source
  JSON, applies a valid skill edit, rebuilds/imports content, confirms runtime
  registry sees the new skill value, verifies authored/compiled dungeon handoff,
  and then restores the source files before exit.
- Added first-pass minimap HUD for town/dungeon runtime:
  visited cells are now persisted into runtime save state, the HUD renders a
  live minimap texture with player position and key placement markers, and the
  M2 `minimap/HUD` acceptance surface is now visible in smoke screenshots rather
  than being only implied by text status.
- Extended smoke artifacts so minimap progress state is not only visual:
  benchmark snapshots now include minimap quest markers/visited keys, and the
  main smoke report now records town/dungeon/town-again HUD snapshots with their
  minimap payloads for regression diffing.
- Added generic event placement support and first quest-seed objective marker flow:
  `event` placements can now execute authored event definitions in the dungeon,
  the first floor includes a real `blood_altar` placement for
  `event_blood_altar_unlock`, and domain smoke now proves quest-seed minimap
  markers move from dungeon objective -> town turn-in.
- Extended the main scene smoke to actually traverse the new quest-seed path:
  the smoke route now accepts the scholar quest seed in town, triggers the
  dungeon blood altar event placement, returns to town, and claims the quest-seed
  reward before the normal quest-board reward snapshot is written.
- Added smoke runner and visual screenshot capture using `xvfb-run`.
- Installed `xvfb` with sudo to enable visual rendering in CI-like terminal
  conditions.

## Verification
- `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path . --quit`
- `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path . -s res://scripts/tests/editor_smoke.gd`
- `CONAN_DOT_DOMAIN_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path .`
- `CONAN_DOT_SAVE_MIGRATION_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path .`
- `"/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --headless --path . --export-debug "Linux Desktop" build/linux/conan.x86_64`
- `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output" xvfb-run -a "/home/inri/다운로드/Godot_v4.6.3-stable_linux.x86_64" --path . --smoke`
- `CONAN_DOT_SMOKE=1 CONAN_DOT_OUTPUT_DIR="/home/inri/문서/conan_dot/conan/output/export_smoke" xvfb-run -a ./build/linux/conan.sh --smoke`

## Files Changed
- `data/source_json/content_manifest.json`: definition families expanded for imported web catalogs.
- `data/source_json/items.json`: local runtime items merged with source-catalog references.
- `data/source_json/monsters.json`: local field monster retained while source encounter monsters were added.
- `data/source_json/vendors.json`: first-pass vendor records added for engine-native service overlays.
- `data/source_json/encounters.json`, `events.json`, `loot_tables.json`, `map_chunks.json`, `map_profiles.json`, `materials.json`, `npcs.json`, `object_themes.json`, `tile_substitutions.json`: imported source catalog files.
- `data/source_json/maps/town_square.json`, `data/source_json/maps/dungeon_floor_01.json`: placements now bind to `npcId`, `eventId`, and `lootTableId`.
- `scripts/autoload/content_registry.gd`: array/keyed-object normalization and loot table resolution added.
- `scripts/editor/content_tools.gd`: all-definition loading, normalization, cross-reference validation, and reporting expanded.
- `scripts/ui/service_overlay.gd`: runtime service copy now reads `npc`/`vendor` definitions.
- `scripts/runtime/grid_scene.gd`: event-driven trap/rest logs and loot-table rewards added.
- `scripts/runtime/editor_workspace.gd`: fallback editor summary now shows manifest path and full definition counts.
- `scripts/runtime/grid_scene.gd`: dungeon runtime now reads profile/theme/material
  metadata and generates themed surface/decor state.
- `data/source_json/maps/dungeon_floor_01.json`: authored dungeon map now carries
  first-pass profile/theme/material/chunk metadata.
- `scripts/editor/content_tools.gd`: build preview/export for dungeon chunks and
  stronger map validation for profile/chunk/material/object-theme references.
- `scripts/runtime/grid_scene.gd`: runtime now reads `compiledPreview.chunkLayout`
  and `anchorLayout` to expose active chunk context and overlay markers.
- `scripts/runtime/grid_scene.gd`: runtime HUD now also reflects generated assembly
  counts from imported compiled preview data.
- `scripts/runtime/grid_scene.gd`: dungeon runtime now promotes
  `generatedCells/generatedPlacements/generatedStart` into the active map data.
- `scripts/autoload/game_app.gd`: dungeon runtime source mode (`authored` /
  `compiled`) is now tracked explicitly.
- `scripts/autoload/save_service.gd`: slot summary/runtime save now preserve
  `dungeonSource`, schema/content version, blocked diagnostics, legacy-field
  migration, and first-pass `equipment` state.
- `scripts/autoload/event_service.gd`: content-driven event effect interpreter
  added for resource, status, HP, flag, inventory mutation, and first-pass
  step/branch/choice effect resolution.
- `scripts/autoload/npc_service.gd`: first-pass NPC service runtime added for
  dialogue stepping, relic identify, companion recruit flow, and fight/avoid
  service outcomes, plus slot-aware service availability filtering.
- `scripts/ui/inventory_overlay.gd`: inventory now exposes selected item detail,
  equipment summary, equip/unequip actions, and unidentified-vs-identified
  display names.
- `scripts/runtime/combat_scene.gd`: combat now reads `knownSkills`,
  widened `CombatViewModel` fields, and forwards enemy-turn smoke probes without
  re-owning combat state.
- `scripts/runtime/combat_runtime.gd`: combat state/view-model owner now includes
  enemy guard, enemy AI retaliation rules, front-line status resist handling,
  explicit target/item commands, first-pass `effectOps` interpretation, and
  direct enemy-turn/item-command smoke probes.
- `data/source_json/skills.json`: combat skills now declare `effectOps` for
  attack, guard, heal, armor-break, status apply, and lifesteal behavior.
- `data/source_json/items.json`: combat consumables now declare `effectOps` for
  heal, cure, direct-damage, and burn application behavior.
- `data/source_json/monsters.json`: monsters now declare first-pass
  `combatProfile` turn operations for aggressive / guardian / ambusher /
  defensive / caster / coward behavior.
- `scripts/runtime/combat_view_model_builder.gd`: dedicated helper for
  `CombatViewModel` and roll DTO serialization.
- `scripts/runtime/combat_hud_presenter.gd`: dedicated helper for combat HUD
  info text and roll-button label formatting.
- `scripts/ui/main_root.gd`: benchmark smoke/report path added for dungeon build,
  movement, and combat-loop latency measurement.
- `scripts/ui/main_root.gd`: content import smoke/report path added for imported
  manifest priority and compiled bundle validation.
- `scripts/runtime/grid_scene.gd`: benchmark snapshot helper added for dungeon
  route movement/build timing checks.
- `scripts/ui/main_root.gd`: domain smoke now verifies enemy guard generation,
  poison resistance, explicit item-command state transitions, and widened combat
  view-model fields through direct runtime probes in addition to the routed
  combat loop.
  front-line state, and monster stats from save/content data, resolves
  attack/buff skills with a combat log, and persists front-line HP back into
  save state.
- `scripts/runtime/combat_scene.gd`: combat now also reads definition-driven
  `effectKind` metadata for heal / guard / armor-break / lifesteal handling and
  exposes roll debug rows for smoke verification.
- `scripts/runtime/combat_scene.gd`: combat now also consumes authored item
  `combatUse` definitions for heal / cure / direct damage / burning item
  commands, tracks pending item targeting state, and surfaces enemy statuses.
- `scripts/runtime/combat_scene.gd`: combat now also reads authored
  `targetMode`, `cooldownKey`, and `cooldownTurns`, enforces cooldown selection
  blocking, and separates pending skill target confirmation from immediate
  action resolution.
- `scripts/runtime/combat_scene.gd`: combat now also exposes first-pass HUD
  commands for `ClearSelection` and `Swap`, plus roll `selectedOrder` metadata
  and selection-command smoke probes.
- `scripts/runtime/combat_runtime.gd`: first-pass extracted combat domain/state
  owner providing serializable view-model snapshots and command outcomes for the
  scene wrapper.
- `scripts/autoload/scene_router.gd`: route handoff keeps the existing
  add-child-then-setup order, while combat scene now self-recovers payload
  during `_ready()` so route boot remains compatible with other scenes.
- `scripts/autoload/quest_service.gd`: quest-seed state accept/complete/reward
  flow added alongside the original simple quest loop.
- `scripts/autoload/shop_service.gd`: slot-bound skill shop stock generation,
  reroll, skill purchase, and vendor item purchase flow added.
- `scripts/autoload/game_app.gd`, `scripts/runtime/grid_scene.gd`,
  `scripts/runtime/combat_scene.gd`, `scripts/ui/main_root.gd`: combat exit and
  smoke reporting now distinguish generated monster instance ids from logical
  monster ids so compiled quest completion survives the generated placement
  path, and NPC fight combat writes back to the correct save slot.
- `scripts/ui/main_root.gd`: domain smoke path now writes
  `output/domain_smoke_report.json`, now covering runtime event/effect
  application in addition to quest/shop/trade progression.
- `scripts/ui/title_menu.gd`: title shell now disables blocked saves and shows
  save/content version diagnostics in slot summary.
- `scripts/ui/main_root.gd`: dedicated save-migration smoke entry now writes
  `output/save_migration_report.json`.
- `scripts/ui/service_overlay.gd`: healer/quest board remain, but skill shop now
  renders rotating stock entries and refresh behavior from `ShopService`, and
  trade vendors now expose item purchase buttons.
- `scripts/ui/service_overlay.gd`: generic `npc_service` overlays now render
  multi-service NPC menus, branching dialogue choices, identify, recruit,
  quest-seed accept/reward, and fight/avoid actions.
- `scripts/runtime/grid_scene.gd`: `trade` placements now open the service overlay
  like other runtime town services.
- `scripts/runtime/grid_scene.gd`: `npc_service` placements now open the same
  modal flow, so town NPCs no longer need one-off placement types for every
  service surface.
- `data/source_json/skills.json`: first-pass purchasable skill pool expanded
  beyond `power_slash`, with definition-driven combat effect metadata plus
  authored target/cooldown rules.
- `data/source_json/items.json`: artifact items now carry first-pass
  `equipSlot`, `unknownName`, description, curse/effect metadata for
  identify/equip behavior, plus authored combat-use metadata for consumables.
- `data/source_json/vendors.json`: town skill vendor now carries a stock pool and
  stock size metadata for rotation tests and richer combat-skill rotation.
- `data/source_json/maps/town_square.json`: apothecary trade placement plus
  scholar/scout `npc_service` placements added to the authored town map.
- `data/source_json/maps/dungeon_floor_01.json`: deserter captain
  `npc_service` placement added for dungeon-side fight/avoid coverage.
- `export_presets.cfg`: Linux desktop debug export preset added.
- `addons/connan_editor/plugin.cfg`: plugin script path changed to relative path
  for editor/export compatibility.
- `addons/connan_editor/docks/content_editor_dock.gd`: export-time parse issues
  fixed for stricter editor initialization path.
- `scripts/runtime/editor_workspace.gd`: authored/compiled dungeon test-play entry
  points are now split.
- `addons/connan_editor/docks/content_editor_dock.gd`, `addons/connan_editor/plugin.gd`:
  editor-side dungeon test play now exposes authored vs compiled mode.
- `addons/connan_editor/docks/content_editor_dock.gd`: dungeon build preview action
  added to the plugin dock.
- `scripts/tests/editor_smoke.gd`: preview export is now part of editor smoke.
- `output/dungeon_floor_01_chunk_preview.json`: exported compiled preview artifact.
- `output/domain_smoke_report.json`: domain smoke artifact for quest/shop/save
  loop verification, including trade, event/effect execution, dialogue,
  identify, recruit persistence, quest-seed rewards, fight/avoid outcomes,
  cursed equipment persistence, purchased-skill combat dice assignment, and
  per-roll effect metadata plus combat item command, pending target, cooldown,
  and selection-command state.
- `output/save_migration_report.json`: legacy-save migration and future-content
  block smoke artifact.
- `build/linux/conan.x86_64`, `build/linux/conan.pck`, `build/linux/conan.sh`:
  first exported Linux desktop build artifacts.
- `output/export_smoke/smoke_report.json`: exported-build boot smoke artifact.
- `data/source_json/content_manifest.json`: map manifest now includes
  `dungeon_floor_02`, so import/build/export paths cover a second authored
  dungeon floor.
- `data/source_json/maps/dungeon_floor_01.json`: floor 1 now carries a gated
  `stairs_down_floor_02` placement that stays blocked until the blood altar
  flag is set.
- `data/source_json/maps/dungeon_floor_02.json`: added an authored second
  dungeon floor with wounded mystic NPC service, black-water rite event,
  rest/trap/loot points, and return stairs to floor 1.
- `scripts/runtime/grid_scene.gd`: route interaction now supports placement
  `requiredFlag` gates and preserves authored dungeon-to-dungeon stairs in
  compiled mode instead of dropping every authored `stairs` placement when a
  generated return stair exists.
- `scripts/runtime/grid_scene.gd`: added smoke helpers for routing to a target
  map, triggering arbitrary authored events, and accepting quest seeds from a
  specific NPC so multi-floor progression can be exercised in smoke paths.
- `scripts/autoload/quest_service.gd`: added quest-seed offer inspection so UI
  can distinguish available, claimable, and still-locked seed offers from the
  current save state.
- `scripts/ui/service_overlay.gd`: NPC quest surfaces now disable unavailable
  seed accept/claim buttons and show gate reasons in quest notes instead of
  always exposing every seed action blindly.
- `scripts/ui/main_root.gd`: domain smoke now verifies a second quest-seed
  progression chain (`quest_seed_black_water_vow`) with
  `requiredFlag -> floor 2 objective -> event completion -> same-floor turn-in`
  state transitions.
- `scripts/ui/main_root.gd`: visual smoke now captures `04_floor2.png` and
  records a compiled floor-2 route snapshot after floor-1 unlock.
- `scripts/ui/main_root.gd`: content import smoke now asserts all three current
  authored/compiled maps (`town_square`, `dungeon_floor_01`, `dungeon_floor_02`)
  are present in the imported bundle and that both dungeon floors carry
  generated preview payloads.
- `output/04_floor2.png`, `output/export_smoke/04_floor2.png`: new visual smoke
  artifacts for second-floor compiled route coverage.
- `data/source_json/content_manifest.json`: map manifest now also includes
  `dungeon_floor_03`, extending authored/imported coverage to a third dungeon
  floor.
- `data/source_json/maps/dungeon_floor_02.json`: floor 2 now carries a gated
  `stairs_down_floor_03` placement that opens only after `black_water_rite`
  completion.
- `data/source_json/maps/dungeon_floor_03.json`: added an authored third floor
  with a blind-priest boss blocker, authored return stairs to floor 2, and a
  final town-return stair gated behind boss clearance.
- `scripts/autoload/quest_service.gd`: progression now has a reusable
  `bossesDefeatedAtLeast` evaluator derived from rewarded quest seeds and boss
  runtime defeat state, and quest-seed offer inspection now respects those
  progression gates.
- `scripts/autoload/game_app.gd`, `scripts/autoload/save_service.gd`: boss
  combat victories now persist logical monster ids and `*_cleared` flags so
  authored progression gates can key off final-boss defeat.
- `scripts/ui/service_overlay.gd`: quest notes now show current progression
  count and hide future hook/seed rows until their `bossesDefeatedAtLeast`
  threshold is met.
- `scripts/runtime/grid_scene.gd`: added route-gate probe helpers used by smoke
  to verify authored stair unlock/blocked behavior without relying on router
  side effects.
- `scripts/ui/main_root.gd`: domain smoke now verifies floor-3 gate blocking
  before `black_water_rite`, successful floor-3 unlock after the rite, and a
  compiled floor-3 route snapshot once the second quest seed is rewarded.
- `scripts/ui/main_root.gd`: local visual smoke now reaches and captures
  `04_floor3.png` from a real post-reward route into floor 3.
- `scripts/runtime/grid_scene.gd`: added a targeted smoke helper for boss combat
  entry by `monsterId`, so floor-3 authored boss progression can be exercised
  without depending on incidental generated encounters.
- `scripts/ui/main_root.gd`: local/export smoke now also clears the authored
  `blind_priest` boss on floor 3 and returns to town through the final gated
  exit, leaving both pre-boss and post-boss floor-3 snapshots in the smoke
  report.
- `output/smoke_report.json`, `output/export_smoke/smoke_report.json`: floor-3
  route evidence now includes `floor03SnapshotAfterUnlock`,
  `floor03SnapshotAfterBoss`, and persisted boss defeat state for
  `blind_priest`.
- `scripts/ui/main_root.gd`: visual/export smoke now also closes the second
  quest-seed loop (`quest_seed_black_water_vow`) through same-floor reward
  claim before the final floor-3 route, so smoke reports no longer stop at
  `completed`.
- `output/smoke_report.json`, `output/export_smoke/smoke_report.json`: both
  reports now end with `quest_seed_black_mural = rewarded` and
  `quest_seed_black_water_vow = rewarded`, alongside the floor-3 boss-clear
  evidence and town return.
- `data/source_json/npcs.json`, `data/source_json/maps/town_square.json`:
  town now exposes a trainer NPC service surface, and the trainer skill-shop
  handoff requires progression level 1 instead of always being open.
- `scripts/autoload/npc_service.gd`: NPC services now support generic
  `requiredFlag`, `bossesDefeatedAtLeast`, and quest-seed status gates, and the
  helper can describe locked services with user-visible reasons instead of only
  hiding them.
- `scripts/ui/service_overlay.gd`: NPC service menus now render disabled entries
  with lock reasons, so progression-gated services are visible but not usable
  until their conditions are met.
- `output/domain_smoke_report.json`: smoke now proves trainer service
  progression gating by showing `available=false` with reason before the first
  major progression step and `available=true` afterward.
- `scripts/ui/main_root.gd`: content import smoke now asserts all four current
  authored/compiled maps (`town_square`, `dungeon_floor_01`, `dungeon_floor_02`,
  `dungeon_floor_03`) and generated preview payloads for all dungeon floors.
- `output/04_floor3.png`: third-floor compiled route visual smoke artifact.
- `data/source_json/maps/town_square.json`: `town_gate` now carries an actual
  route gate contract, requiring quest-board acceptance before the dungeon gate
  opens and surfacing a Korean blocked message that matches the authored town
  fiction.
- `scripts/runtime/grid_scene.gd`: route gating is no longer limited to
  `requiredFlag`; route probes and live interaction now also understand
  `requiredQuestStatuses`, `bossesDefeatedAtLeast`, and quest-seed status
  requirements. HUD snapshots now expose `routeStates`, and the top status text
  reports route open/locked state directly.
- `scripts/ui/grid_hud.gd`: minimap route rendering now distinguishes locked
  gates/stairs from open ones, and the legend shows a separate `Locked` route
  state instead of coloring all route affordances the same.
- `scripts/ui/main_root.gd`, `output/domain_smoke_report.json`: domain smoke
  now verifies town-gate gating explicitly (`blocked before quest accept`, then
  `open after accept`) in addition to the deeper floor gates.
- `output/smoke_report.json`, `output/export_smoke/smoke_report.json`: local
  and exported smoke reports now carry structured route-state snapshots, so
  floor-1/floor-2 locked stairs and town-gate open state are visible in JSON as
  well as in the captured HUD.
- `data/source_json/maps/town_square.json`, `data/source_json/npcs.json`: town
  now also has an authored `npc_gatekeeper` placement beside the dungeon gate,
  with a dedicated `route_info` service that explains the exact open/locked
  state of `town_gate` instead of leaving the route logic only in HUD text.
- `scripts/autoload/npc_service.gd`: added route-inspection support for NPC
  services. `inspect_route(...)` resolves a target route placement from map
  data, evaluates the same gate conditions used by runtime routes, and returns
  an explanation payload suitable for UI and smoke verification.
- `scripts/ui/service_overlay.gd`: NPC overlays can now execute a
  `route_info` service and expose it to smoke helpers, so route explanations
  are proven through the actual overlay path rather than only direct JSON
  inspection.
- `scripts/runtime/grid_scene.gd`, `scripts/ui/main_root.gd`: smoke can now open
  a service overlay by NPC id; visual smoke captures the gatekeeper overlay as
  `02_gatekeeper.png` before quest acceptance, and domain smoke records both
  pre-accept and post-accept gatekeeper route explanations.
- `output/02_gatekeeper.png`, `output/export_smoke/02_gatekeeper.png`: visual
  proof that the gatekeeper overlay shows the locked route explanation before
  the quest board unlocks the dungeon gate.
- `data/source_json/maps/dungeon_floor_03.json`: the authored final town-return
  stair now carries explicit ending metadata (`campaignCleared`,
  `Blind Priest Defeated`) instead of acting only as a gated route.
- `data/source_json/npcs.json`: `npc_scholar` now exposes a post-clear
  `ending_report` service gated by `blind_priest_cleared`, so the expedition
  ending is available as an actual town interaction surface.
- `scripts/autoload/save_service.gd`: save metadata now persists
  `campaignCleared`, `endingTitle`, `clearedAt`, and `clearMapId`, and title
  slot summaries can surface that clear state.
- `scripts/runtime/grid_scene.gd`: floor-3 town returns now mark campaign clear
  even when the compiled route uses a generated return stair instead of the
  authored `final_stairs_town`, keeping ending metadata aligned with the actual
  runtime route the player takes.
- `scripts/autoload/npc_service.gd`, `scripts/ui/service_overlay.gd`: added an
  `ending_report` inspection path that summarizes final clear title, rewarded
  quest seeds, front-line condition, currency, XP, and companion state from the
  live save slot.
- `scripts/ui/main_root.gd`: domain smoke now probes the scholar ending report
  directly, and local/export smoke now capture a post-clear scholar overlay as
  `06_epilogue.png` after the blind-priest clear and town return.
- `output/smoke_report.json`, `output/export_smoke/smoke_report.json`: both
  reports now carry `meta.campaignCleared = true`,
  `meta.endingTitle = "Blind Priest Defeated"`, and a `townSnapshotAfterClear`
  snapshot, proving the ending state survives the full clear loop in local and
  exported builds.
- `scripts/autoload/save_service.gd`: save writes now go through an atomic
  temp/backup promotion path instead of writing JSON directly to the final slot
  file. Slot reads also fall back to `.tmp`/`.bak` candidates, reducing the
  chance that HUD/runtime reads see partially-written JSON.
- Regression note: after a previous manual parallel smoke run exposed partial
  save JSON reads, local and exported smoke were re-run sequentially against the
  new atomic save path. Both completed without the earlier JSON parse errors,
  while retaining the same `06_epilogue.png` and campaign-clear report evidence.
- `scripts/autoload/save_service.gd`: smoke/save runs now support namespace-
  scoped save roots under `user://saves/<namespace>`. The runtime auto-selects
  namespaces for domain, visual, export, benchmark, migration, and content-
  import smoke modes so those harnesses no longer contend for the same slot
  JSON by default.
- Filesystem verification: the active Godot userdata root under the current
  editor/smoke environment is `~/snap/code/240/.local/share/godot/app_userdata/
  conan/saves`, and smoke runs now create isolated directories such as
  `smoke_output/slot_1.json` and `smoke_export_smoke/slot_1.json` alongside the
  base `slot_1.json` instead of overwriting it.
- Regression note: after enabling namespace-scoped save roots, headless boot,
  domain smoke, local visual smoke, and exported visual smoke were re-run and
  all completed without the earlier cross-run parse failures or slot-path
  collisions.
- `scripts/ui/inventory_overlay.gd`: inventory overlay is no longer a plain
  item list. It now supports search, kind/equippable filtering, name/quantity/
  kind/price sorting, and same-slot equipment comparison so the preserved
  inventory surface is closer to the web prototype contract.
- `scripts/autoload/save_service.gd`: save metadata now tracks a bounded
  `recentRewards` list, which the inventory overlay can present without needing
  a separate reward log scene.
- `scripts/autoload/quest_service.gd`, `scripts/autoload/event_service.gd`,
  `scripts/runtime/grid_scene.gd`: quest rewards, quest-seed rewards, event item
  grants, and dungeon loot pickups now append structured recent-reward entries
  instead of leaving rewards only in transient log strings.
- `scripts/ui/main_root.gd`: local/export smoke now re-open inventory after the
  clear sequence and capture `06_inventory_rewards.png`; smoke reports also
  include top-level `recentRewards` arrays so reward visibility regresses in
  JSON as well as screenshots.
- `scripts/runtime/combat_runtime.gd`, `scripts/runtime/combat_scene.gd`:
  combat defeat now has a real ending path instead of silently behaving like a
  non-victory exit. Defeat produces a summary payload, a visible defeat overlay,
  and explicit `Recover In Town` / `Return To Title` actions.
- `scripts/autoload/save_service.gd`, `scripts/autoload/game_app.gd`:
  defeat resolution now persists `meta.defeatCount` and `meta.lastDefeat`,
  applies a bounded gold penalty, restores the party to 1 HP, and relocates the
  save back to town/title so defeat is visible beyond the transient combat scene.
- `scripts/ui/title_menu.gd`: slot summary now exposes defeat history, including
  defeat count and the latest enemy/penalty, so the title shell reflects failed
  expeditions as well as clear-state metadata.
- `scripts/ui/main_root.gd`: local/export smoke now capture `05_defeat.png`
  through a direct defeat probe, and smoke reports include a structured
  `defeatProbe` entry proving the recorded enemy, penalty, and town return path.
- `data/source_json/quests.json`: quest catalog now has multiple authored board
  candidates instead of a single fixed `slime_cleanup` row, covering slime,
  grave robber, serpent guard, and blind priest targets.
- `scripts/autoload/quest_service.gd`: quest board now maintains slot-scoped
  rotating offers (`questBoardState`) and can refresh a three-offer board from
  the authored quest catalog instead of behaving like a single hard-wired accept
  button.
- `scripts/ui/service_overlay.gd`: `quest_board` overlays now render multiple
  offer rows with target monster/reward information plus a board refresh action,
  while still supporting reward claim for the active quest.
- `scripts/ui/main_root.gd`, `output/domain_smoke_report.json`: domain smoke now
  verifies both the initial board offer set and a changed offer set after board
  refresh, proving the quest board is no longer static.
- `output/02_quest_board.png`, `output/export_smoke/02_quest_board.png`: local
  and exported visual smoke now capture the multi-offer quest board overlay as
  direct UI evidence.
- `scripts/runtime/grid_scene.gd`: field monsters are no longer static blockers
  only. Runtime save state now tracks `startCell`, `currentCell`, and `aiState`,
  and dungeon movement ticks can move monsters through a minimal
  `approaching -> chasing -> returning -> idle` loop.
- Field-monster blocker checks, combat interaction, minimap placement export,
  marker rendering, and HUD state summary now resolve runtime monster positions
  instead of always trusting authored placement coordinates.
- `scripts/ui/main_root.gd`, `output/domain_smoke_report.json`: domain smoke now
  includes a `fieldMonsterAiProbe` entry proving `slime_alpha` starts idle at
  its authored cell, moves into chase state near the player, and transitions
  into a return path after the player backs off.
- `data/source_json/maps/dungeon_floor_01.json`,
  `data/source_json/maps/dungeon_floor_03.json`: authored dungeon placements now
  carry explicit `fieldAi` tuning (`approachRange`, `chaseRange`,
  `leashRange`) instead of relying only on runtime hard-coded distances.
- `scripts/editor/content_tools.gd`: map validation now rejects incomplete or
  negative `fieldAi` dictionaries, and compiled generated field-monster
  placements also emit default `fieldAi` payloads so authored and generated
  monsters share the same contract through the build pipeline.
- `scripts/runtime/grid_scene.gd`: field-monster ticking now reads authored
  `fieldAi` values for approach/chase/leash decisions, minimap placement export
  reports runtime monster cells rather than stale authored coordinates, and
  field-monster smoke snapshots include the resolved `fieldAi` config.
- Regression note: after the `fieldAi` contract was wired through validation,
  runtime, and compiled-map export, headless boot, editor smoke, domain smoke,
  local visual smoke, export rebuild, and exported visual smoke were all rerun.
  Imported maps plus both local/export smoke reports now include `fieldAi`
  payloads in compiled placements and `fieldMonsterStates`.
- `scripts/editor/content_tools.gd`: added map-side authoring helpers
  (`load_map_data`, `list_map_placements`, `save_map_placement`) so the editor
  can now round-trip authored placement rows through validation instead of only
  editing definition-family JSON files.
- `addons/connan_editor/docks/content_editor_dock.gd`: the dock now exposes a
  selected-map placement editor alongside definition editing. A chosen map can
  list its placements, open one placement row in the same typed/JSON editor
  surface, and save it back through validation before bundle rebuild/test-play.
- `scripts/tests/editor_smoke.gd`: editor smoke now verifies map placement
  authoring as well as definition editing. It attempts an invalid `fieldAi`
  edit on `slime_alpha` and confirms the source JSON stays unchanged, then
  applies a valid placement edit, rebuilds the bundle, and confirms the
  imported compiled map sees `fieldAi.approachRange = 6` before restoring the
  source file.
- Regression note: after the placement editor path was added, headless boot,
  editor smoke, domain smoke, local visual smoke, export rebuild, and exported
  visual smoke were rerun. `EDITOR_SMOKE` now reports
  `map_invalid_blocked=true`, `map_edit_ok=true`, and `field_ai=6` while the
  restored runtime/export smoke loop still completes end-to-end.
- `scripts/editor/content_tools.gd`: added `save_map_data(...)` and stronger map
  validation for row-width consistency, allowed cell tokens, and blocked-cell
  start rejection. Selected map structure edits can now be saved through the
  same validation gate as placement edits.
- `addons/connan_editor/docks/content_editor_dock.gd`: the dock now exposes a
  `Selected Map Structure` editor next to the placement editor. It can edit map
  fields such as `start` and `cells`, then save them through validation before
  build/test-play.
- `scripts/tests/editor_smoke.gd`: editor smoke now also verifies structural map
  authoring. It attempts an invalid `cells` edit with inconsistent row widths
  and confirms the source JSON stays unchanged, then applies a valid `start`
  edit, rebuilds the bundle, and confirms the imported compiled map sees
  `start[0] = 3` before restoring the authored file.
- Regression note: after the structure editor path was added, headless boot,
  editor smoke, domain smoke, local visual smoke, export rebuild, and exported
  visual smoke were rerun. `EDITOR_SMOKE` now reports
  `map_structure_invalid_blocked=true`, `map_structure_ok=true`, and
  `imported_start_x=3`, while the restored local/export smoke loop still
  completes with the same screenshot set.
- `addons/connan_editor/docks/content_editor_dock.gd`: added a first-pass direct
  grid authoring surface for the selected map. The dock now exposes a
  `floor/wall/start` paint mode and clickable cell buttons, so `cells` and
  `start` are no longer editable only as raw JSON text.
- The map structure form now excludes raw `cells`/`start` fields from the
  generic typed editor and routes those edits through the dedicated grid editor,
  while `save_current_map` merges both metadata-field edits and current grid
  state before validation/write.
- `scripts/tests/editor_smoke.gd`: editor smoke now instantiates the real dock,
  selects `dungeon_floor_01`, switches the grid editor to `start` mode, edits
  cell `(3,5)`, and commits through the dock path. `EDITOR_SMOKE` now reports
  `grid_editor_ok=true` in addition to the existing map-structure validation and
  imported-bundle checks.
- Regression note: after the clickable grid editor path was added, headless
  boot, editor smoke, domain smoke, local visual smoke, export rebuild, and
  exported visual smoke were rerun. The dock path compiles cleanly in headless
  test mode and the end-to-end smoke screenshot set remains unchanged.
- `addons/connan_editor/docks/content_editor_dock.gd`: the grid editor now also
  exposes a `placement` mode. The selected placement is highlighted on the map
  grid, non-selected placements are marked by id initials, and clicking a cell
  in placement mode moves the selected placement there while keeping the
  placement inspector's `position` field in sync.
- `scripts/tests/editor_smoke.gd`: editor smoke now drives the placement-grid
  path through the real dock. It selects `slime_alpha`, switches to placement
  mode, moves it to `(4,4)`, commits the placement through the dock helper, and
  confirms the imported compiled map sees `slime_alpha.position[1] = 4` in
  addition to the existing `fieldAi` checks.
- Regression note: after placement overlay/move support was added, headless
  boot, editor smoke, domain smoke, local visual smoke, export rebuild, and
  exported visual smoke were rerun. `EDITOR_SMOKE` now reports
  `placement_grid_ok=true` and `imported_slime_y=4`, while the restored
  local/export runtime loop still completes with the same smoke captures.
- `addons/connan_editor/docks/content_editor_dock.gd`: added first-pass
  placement lifecycle controls on the grid surface. The dock now has a placement
  type picker plus `Add Placement` / `Delete Placement` actions, can generate a
  valid default row for several placement families (`loot`, `rest`,
  `field_monster`, `event`, `npc_service`, `stairs`), and persists those rows
  through the same map-save validation path.
- The dock now tracks a grid cursor, so add/delete actions are tied to the same
  visible map surface instead of requiring raw JSON row insertion/removal.
- `scripts/tests/editor_smoke.gd`: editor smoke now verifies placement
  add/delete as well as move/edit. It creates a temporary `loot` placement on
  the grid, commits and confirms the authored map file contains the generated id,
  then deletes that placement and confirms the authored file no longer contains
  it before the final bundle rebuild.
- Regression note: after placement add/delete support was added, headless boot,
  editor smoke, domain smoke, local visual smoke, export rebuild, and exported
  visual smoke were rerun. `EDITOR_SMOKE` now reports
  `placement_create_ok=true` and `placement_delete_ok=true`, while the restored
  runtime/export smoke loop still completes end-to-end.
- `addons/connan_editor/docks/content_editor_dock.gd`: common placement
  reference fields now use engine-native id pickers instead of raw string-only
  editing. `targetMapId`, `eventId`, `npcId`, `lootTableId`, `monsterId`,
  `encounterId`, `itemId`, and `vendorId` resolve against the current manifest
  or loaded definition families and save back through the same placement commit
  path.
- `scripts/tests/editor_smoke.gd`: editor smoke now drives the reference-picker
  path through the real dock. It rebinds `rest_altar.eventId` to
  `event_rest_guard_post`, rebinds `deserter_captain.npcId` to
  `npc_wounded_mystic`, creates a temporary `stairs` placement, changes its
  `targetMapId` through the picker, and confirms authored/imported data reflect
  those changes before restore.
- Regression note: after placement reference pickers were added, headless boot,
  editor smoke, and local visual smoke were rerun. `EDITOR_SMOKE` now reports
  `placement_reference_ok=true`, `rest_event=event_rest_guard_post`, and
  `deserter_npc=npc_wounded_mystic`, while the standard smoke capture set still
  completes end-to-end.
- `addons/connan_editor/docks/content_editor_dock.gd`: added first-pass
  placement-type affordance previews. `stairs`/`gate` placements now expose a
  route summary plus filtered target-map candidates by route, while `event` and
  `npc_service` placements show live preview text derived from the selected
  event/NPC definitions instead of leaving that context hidden behind raw ids.
- The placement editor now keeps newly created placements bound to the active
  inspector immediately, so type-specific fields can be edited before the first
  map save. Route picker changes also refresh the in-memory row and the filtered
  `targetMapId` picker without requiring a full placement reselection.
- `scripts/tests/editor_smoke.gd`: editor smoke now verifies those affordance
  paths too. It snapshots the rest/event preview, the NPC service preview, and
  the stairs route-target candidate list, switches a temporary stairs placement
  from `town` to `dungeon`, and confirms the affordance snapshot updates before
  the final commit/delete cycle.
- Regression note: after placement affordance previews were added, editor smoke
  and local visual smoke were rerun. `EDITOR_SMOKE` now reports
  `placement_affordance_ok=true` in addition to the existing create/move/delete
  checks, and the standard runtime smoke capture set still completes.
- `addons/connan_editor/docks/content_editor_dock.gd`: expanded those placement
  previews into richer contract reads. Route placements now display explicit
  gate requirements (`requiredFlag`, `requiredQuestStatuses`,
  `requiredQuestSeed*`, boss gates, and blocked message), event placements show
  step/choice information from the entry step, and NPC service placements show
  service type plus label instead of only a type list.
- `scripts/tests/editor_smoke.gd`: editor smoke now asserts the richer preview
  payload too. It verifies an event preview exposes `steps=` and entry-choice
  text, an NPC preview exposes the deserter captain fight service label, and the
  town gate preview exposes both the required quest-status contract and its
  blocked message.
- Regression note: after richer route/event/NPC previews were added, headless
  boot, editor smoke, and local visual smoke were rerun. `EDITOR_SMOKE` remains
  green with `placement_affordance_ok=true`, and the standard visual smoke
  capture set still completes end-to-end.
- `addons/connan_editor/docks/content_editor_dock.gd`: expanded the preview
  payload again so placement authors can inspect more than labels. Route
  previews now include the selected target map summary (`kind`, `size`, and
  `start`), event previews now expose entry-step effect/branch summaries, and
  NPC previews now expose full service-row detail including `opensService`
  hints and notes when present.
- `scripts/tests/editor_smoke.gd`: editor smoke now checks those deeper payloads
  directly. It verifies route previews for both a temporary stairs placement and
  the town gate, verifies the black-water rite preview includes entry-step
  effect kinds such as `set_flag`, and verifies the wounded mystic preview
  includes concrete service rows such as `trade` and `identify`.
- Regression note: after target-map/event-effect/NPC-service previews were
  added, editor smoke and local visual smoke were rerun. `EDITOR_SMOKE` remains
  green with `placement_affordance_ok=true`, and the usual runtime smoke
  screenshot set still completes.
- `addons/connan_editor/docks/content_editor_dock.gd`: turned those previews
  into first-pass drill-downs. Route placements now expose a start-centered
  target-map mini-grid, event placements expose a simple step graph summary, and
  NPC service placements expose detailed service rows including `opensService`
  and dialogue entry-step hints when present.
- `scripts/tests/editor_smoke.gd`: editor smoke now verifies the drill-down
  payloads too. It checks that route previews expose a mini-grid with the `S`
  start marker, that the black-water rite preview exposes `rite_start ->
  rite_end` in the event graph, and that the trainer preview exposes
  `opens(skill_shop/town_trainer_skill_shop)` in service detail.
- Regression note: after route mini-grid / event graph / NPC drill-down details
  were added, editor smoke and local visual smoke were rerun. `EDITOR_SMOKE`
  remains green with `placement_affordance_ok=true`, and the usual runtime smoke
  screenshot set still completes.
- `addons/connan_editor/docks/content_editor_dock.gd`: made those drill-downs
  interactive. Event placements now expose a step selector, NPC service
  placements now expose a service-row selector, and route mini-grids now overlay
  target-map placement initials instead of only raw floor/wall cells.
- `scripts/tests/editor_smoke.gd`: editor smoke now drives those interactive
  selectors directly. It switches the black-water rite preview to `rite_end`,
  confirms the selected-step payload updates, switches the trainer preview row
  selector, and confirms the selected-service payload carries the `opens
  skill_shop/town_trainer_skill_shop` contract. It also verifies the mini-grid
  overlay shows authored placement initials in both town and dungeon previews.
- Regression note: after interactive drill-down selectors and mini-grid overlay
  markers were added, editor smoke and local visual smoke were rerun. The editor
  path still reports `placement_affordance_ok=true`, and the end-to-end runtime
  smoke capture set still completes.
- The event step selector now preserves a selected-step payload, so the preview
  can be used to inspect non-entry steps such as `rite_end` without leaving the
  placement editor. NPC service row selection likewise preserves a concrete
  selected-service summary instead of only a static list.
- The route target mini-grid now behaves as a true authored-surface preview: it
  shows a start-centered window, overlays placement initials from the target
  map, and keeps the `S` start marker visible inside that same preview.
- `scripts/tests/editor_smoke.gd`: regression coverage now checks those exact
  contracts. It asserts that direct-effect events report `Selected step:
  unavailable`, that selectable events can switch to a later step and surface
  that step's title/text, and that both town/dungeon target-map mini-grids show
  authored placement initials alongside the start marker.
- The placement preview surface now carries stronger internal invariants in
  smoke coverage instead of only broad “preview exists” checks. The editor
  smoke path now decomposes route/event/NPC preview assertions into a
  per-feature contract set before rebuilding/import verification continues.
- Regression note: after tightening the interactive preview assertions, editor
  smoke and local visual smoke were rerun again. `EDITOR_SMOKE` remains green
  with `placement_affordance_ok=true`, and the runtime smoke capture set still
  completes with the standard title/town/dungeon/combat/reward screenshots.
- `addons/connan_editor/docks/content_editor_dock.gd`: extended placement
  drill-downs with three missing authoring aids. Route previews now support a
  target-placement picker plus highlighted `@` overlay inside the target-map
  mini-grid, event previews now support a choice/branch picker tied to the
  selected step, and NPC previews now expose a dedicated `opensService` target
  preview with catalog/currency/note detail.
- `scripts/tests/editor_smoke.gd`: editor smoke now drives those new selectors
  directly. It highlights `slime_alpha` inside the town-gate target map
  preview, inspects the black-water rite choice payload, creates a temporary
  event placement bound to `event_scholar_cache_reward` to verify branch
  previews, and confirms the trainer's `opensService` payload exposes
  `catalogId=trainer_skill_rotation` and `currency=gold`.
- Regression note: after target-placement highlight / event choice-branch
  selection / opens-service preview were added, `--headless --quit`,
  `EDITOR_SMOKE`, and the local visual smoke loop were rerun. The editor path
  remains green with `placement_affordance_ok=true`, and the standard runtime
  smoke capture set still completes.
- `addons/connan_editor/docks/content_editor_dock.gd`: deepened the same
  preview surface instead of widening into a new editor. Route previews now
  expose a highlighted-target detail block so the selected target placement can
  surface type-specific authoring facts such as field-monster AI or linked
  event/NPC summaries. NPC `opensService` previews now also expose a surface
  summary that describes the downstream UI contract (`Buy Skill`, `Refresh
  Stock`, currency, catalog) rather than only raw metadata.
- `scripts/tests/editor_smoke.gd`: smoke coverage now pins those new detail
  contracts too. It verifies that the town-gate target preview can highlight
  `slime_alpha` and surface the edited `fieldAi=6/3/7` payload, can switch to
  `blood_altar` and surface the linked event summary, and that the trainer's
  `opensService` surface preview exposes `ui=Buy Skill, Refresh Stock` plus the
  `trainer_skill_rotation` catalog reference.
- Regression note: after adding highlighted-target detail and opens-service
  surface summaries, `--headless --quit` and `EDITOR_SMOKE` were rerun again.
  The editor path remains green with `placement_affordance_ok=true` before the
  normal visual smoke loop continues.
- `addons/connan_editor/docks/content_editor_dock.gd`: extended the
  `opensService` drill-down one more step so skill-shop targets now expose a
  first-pass catalog preview instead of only metadata. The selected NPC service
  can now surface the resolved catalog count plus representative skill
  name/kind pairs, and the preview remains editor-local by resolving the
  catalog from current `skills` definitions at runtime.
- `scripts/tests/editor_smoke.gd`: smoke coverage now checks that trainer
  `opensService` drill-down exposes a concrete catalog contract, including
  `count=5` and named sample entries such as `Power Slash+Smoke` and
  `Guard Break`, on top of the existing `Buy Skill / Refresh Stock` surface
  summary.
- Regression note: after the skill-shop catalog preview was added,
  `--headless --quit` and `EDITOR_SMOKE` were rerun again. The editor path
  remains green with `placement_affordance_ok=true` before visual smoke is run.
- `addons/connan_editor/docks/content_editor_dock.gd`: extended the same
  `opensService` drill-down with stock-rule detail. Skill-shop previews now
  expose `stockSize` plus representative per-skill prices, so the editor can
  surface the actual runtime stock contract instead of only catalog membership.
- `scripts/tests/editor_smoke.gd`: smoke coverage now pins that stock contract
  too. The trainer preview must now expose `stockSize=3` and sample prices such
  as `Power Slash+Smoke=42g` and `Guard Break=24g` while the temporary edited
  skill definition is active inside the smoke scenario.
- Regression note: after adding the stock/price preview, `--headless --quit`
  and `EDITOR_SMOKE` were rerun again. The editor path remains green with
  `placement_affordance_ok=true` before the visual smoke loop continues.
- `addons/connan_editor/docks/content_editor_dock.gd`: extended route target
  drill-downs with a first-pass interaction/gating contract summary. Highlighted
  target placements now expose the contract that runtime cares about, such as
  `encounter blocker` for field monsters, event `choices/effects` summaries for
  interactive events, and route requirement / blocked-message text for target
  stairs and gates.
- `scripts/tests/editor_smoke.gd`: editor smoke now locks those route-target
  contracts directly. It checks that the town-gate target preview can switch
  between `slime_alpha`, `blood_altar`, and `stairs_down_floor_02`, and that
  the highlighted contract text surfaces the expected blocker, event
  choice/effect, and route gate requirement details.
- Regression note: after the route target contract preview was added,
  `--headless --quit` and `EDITOR_SMOKE` were rerun again. The editor path
  remains green with `placement_affordance_ok=true` before the visual smoke
  loop continues.
- `addons/connan_editor/docks/content_editor_dock.gd`: extended route target
  drill-downs one step further with downstream-surface preview. When the
  highlighted target placement is an `npc_service`, the route preview now
  surfaces the selected service summary plus any `opensService` surface/catalog
  chain; when it is an event placement, the preview surfaces the selected
  step/choice payload; and when it is a route placement, the preview surfaces
  the next route target.
- `scripts/tests/editor_smoke.gd`: editor smoke now verifies that the temporary
  stairs preview can highlight `town_trainer_tent` on the town target map and
  surface the downstream service chain, including `opens
  skill_shop/town_trainer_skill_shop`, `Buy Skill / Refresh Stock`, and the
  catalog preview payload.
- Regression note: after adding downstream route-target preview, `EDITOR_SMOKE`
  was rerun and remains green with `placement_affordance_ok=true` before the
  visual smoke loop continues.
- `addons/connan_editor/docks/content_editor_dock.gd`: added route-target
  specific preview selectors and smoke setters. Route drill-down can now drive
  target-event step/choice selection and target-NPC service-row selection
  without leaving the route preview surface, rather than only inheriting the
  root placement's preview state.
- `scripts/tests/editor_smoke.gd`: editor smoke now verifies that a temporary
  stairs preview can highlight `town_gatekeeper`, switch the highlighted target
  NPC to its second service row through the route-target specific selector, and
  reflect that downstream payload in the route preview.
- Regression note: after adding route-target specific preview selectors,
  `EDITOR_SMOKE` was rerun and remains green with
  `placement_affordance_ok=true` before the visual smoke loop continues.
- `addons/connan_editor/docks/content_editor_dock.gd`: route-target preview
  snapshots now expose structured selected-state fields for highlighted target
  event/NPC drill-downs. The snapshot now carries
  `routeTargetSelectedEventStep`, `routeTargetSelectedEventChoice`, and
  `routeTargetSelectedNpcService` so smoke does not have to infer selected
  state only from free-form downstream text.
- `scripts/tests/editor_smoke.gd`: editor smoke now asserts those structured
  route-target selected-state fields directly. The temporary stairs preview must
  expose the trainer's selected NPC service contract, the gatekeeper's switched
  talk row, and the blood-altar event's selected step/choice payload through
  the route-target snapshot keys.
- Regression note: after adding structured route-target selected-state payloads,
  `EDITOR_SMOKE` was rerun and remains green with
  `placement_affordance_ok=true` before the visual smoke loop continues.
- `scripts/tests/editor_smoke.gd`: editor smoke now emits a structured route
  preview artifact at [output/editor_route_preview_report.json](res://output/editor_route_preview_report.json).
  That report captures the temporary town-route and dungeon-route drill-down
  snapshots so route-target preview behavior is preserved as data instead of
  only console assertions.
- The route preview artifact now includes structured selected-state keys such as
  `routeTargetSelectedNpcService`, `routeTargetSelectedEventStep`, and
  `routeTargetSelectedEventChoice`, alongside the human-facing downstream text.
  This makes the town trainer, gatekeeper, blood altar, and floor-02 stair
  target states inspectable without replaying the editor smoke run manually.
- Regression note: after adding the route preview JSON artifact, `EDITOR_SMOKE`
  was rerun and stayed green with `placement_affordance_ok=true` before the
  visual smoke loop continues.
- `scripts/runtime/editor_workspace.gd`: the fallback workspace now reads the
  structured route-preview artifact instead of ignoring editor-only evidence.
  For the currently selected map it surfaces matching route drill-down entries,
  including highlighted target placement, selected target NPC/event state, and
  downstream surface text, so the fallback route now mirrors the same authoring
  contracts captured by the editor dock.
- `scripts/tests/editor_smoke.gd`: editor smoke now instantiates the fallback
  workspace after writing
  [output/editor_route_preview_report.json](res://output/editor_route_preview_report.json)
  and asserts that both the default dungeon summary and a switched town summary
  expose the route-preview block plus concrete artifact content such as
  `townGateToDungeonFieldMonster`, `blood_altar`, `tempTownRouteTrainer`, and
  `opens skill_shop/town_trainer_skill_shop`.
- Regression note: after wiring the fallback workspace to the route-preview
  artifact, `--headless --quit`, `EDITOR_SMOKE`, and the local visual smoke
  loop were rerun. The editor path stayed green with
  `fallback_workspace_ok=true` and `placement_affordance_ok=true`, and the
  standard runtime capture set still completed.
- `scripts/runtime/editor_workspace.gd`: the fallback workspace no longer stops
  at a flat route-preview summary. It now exposes a route-preview entry picker
  plus a dedicated detail panel so the same trainer / gatekeeper / field monster
  / blood-altar / stair drill-downs can be selected and inspected without
  opening the editor dock.
- `scripts/tests/editor_smoke.gd`: editor smoke now drives that fallback route
  preview picker directly. It selects `townGateToDungeonFieldMonster` and
  `townGateToDungeonEvent` on the dungeon map, then `tempTownRouteTrainer` and
  `tempTownRouteGatekeeper` on the town map, and checks that the detail panel
  surfaces the expected contracts like `fieldAi=6/3/7`, the blood-altar choice
  payload, and `opens skill_shop/town_trainer_skill_shop`.
- Regression note: after adding fallback route-preview selection/detail,
  `--headless --quit`, `EDITOR_SMOKE`, and the local visual smoke loop were
  rerun again. The editor path stayed green with
  `fallback_workspace_ok=true` and `fallback_workspace_detail_ok=true`, and the
  standard runtime capture set still completed.
- `scripts/ui/main_root.gd`: the ordinary smoke path now also instantiates the
  fallback editor workspace, selects a dungeon route-preview entry
  (`townGateToDungeonEvent`) and a town route-preview entry
  (`tempTownRouteTrainer`), captures those surfaces, and writes their summary /
  detail text back into [output/smoke_report.json](res://output/smoke_report.json).
- New runtime-facing smoke artifacts:
  [output/07_editor_fallback_dungeon.png](res://output/07_editor_fallback_dungeon.png),
  [output/07_editor_fallback_town.png](res://output/07_editor_fallback_town.png),
  plus `editorFallbackDungeon` / `editorFallbackTown` payloads inside
  [output/smoke_report.json](res://output/smoke_report.json).
- Regression note: after wiring fallback-workspace evidence into the normal
  smoke route, `--headless --quit`, `EDITOR_SMOKE`, and the local visual smoke
  loop were rerun again. The editor path stayed green, the runtime smoke
  captured both new fallback PNGs, and `smoke_report.json` now contains the
  selected fallback summary/detail strings for both dungeon and town previews.
- `scripts/editor/content_tools.gd`: editor export helpers now tolerate
  no-output mode. `export_manifest_report("")` and
  `export_compiled_map_preview(..., "")` return in-memory data without trying to
  write into read-only `res://output`, which matters for fallback surfaces inside
  exported builds.
- `scripts/tests/editor_smoke.gd`: route preview artifact generation now writes
  both the transient debug copy
  [output/editor_route_preview_report.json](res://output/editor_route_preview_report.json)
  and an export-safe bundled copy at
  [data/imported/editor_route_preview_report.json](res://data/imported/editor_route_preview_report.json).
- `scripts/runtime/editor_workspace.gd`: fallback route-preview loading now
  probes `res://output/editor_route_preview_report.json` first and falls back to
  `res://data/imported/editor_route_preview_report.json`, so the same route
  drill-down artifact survives into packaged builds.
- Exported smoke artifacts are now aligned with local smoke:
  [output/export_smoke/07_editor_fallback_dungeon.png](res://output/export_smoke/07_editor_fallback_dungeon.png),
  [output/export_smoke/07_editor_fallback_town.png](res://output/export_smoke/07_editor_fallback_town.png),
  and `editorFallbackDungeon` / `editorFallbackTown` payloads inside
  [output/export_smoke/smoke_report.json](res://output/export_smoke/smoke_report.json).
- Regression note: after packaging the route-preview artifact into
  `data/imported/` and switching fallback runtime to no-write editor summaries,
  `--headless --quit`, `EDITOR_SMOKE`, `--export-debug "Linux Desktop"`, and the
  exported build smoke were rerun again. The packaged smoke no longer emits
  `store_string` errors, and `output/export_smoke/smoke_report.json` now points
  to `artifact=res://data/imported/editor_route_preview_report.json` with the
  same trainer/blood-altar fallback detail payloads as the local smoke.
- `scripts/ui/main_root.gd`: benchmark smoke now also captures structured
  fallback-workspace evidence. `benchmark_report.json` now carries
  `editorFallbackDungeon` and `editorFallbackTown` payloads through the same
  helper used by the local/export smoke paths, so benchmark/debug artifacts and
  runtime smoke artifacts now speak the same route-preview shape.
- The benchmark harness itself was updated for current runtime rules: it now
  accepts `slime_cleanup` before attempting the town -> dungeon route, matching
  the quest-gated `town_gate` behavior that had made the benchmark path stale.
- Regression note: after adding fallback payloads to benchmark smoke and fixing
  the quest-gated route precondition, `--headless --quit`, `EDITOR_SMOKE`, and
  `CONAN_DOT_BENCHMARK_SMOKE=1` were rerun. `output/benchmark_report.json` is
  green again with `ok=true`, `routeAfterCombat="dungeon"`, quest-target
  minimap data on the dungeon snapshots, and both `editorFallbackDungeon` /
  `editorFallbackTown` payloads populated.
- `scripts/ui/main_root.gd`: content-import smoke now also verifies that the
  imported bundle carries the fallback route-preview artifact. The report now
  includes `importedRoutePreviewExists`, `importedRoutePreviewPath`, and the
  same `editorFallbackDungeon` / `editorFallbackTown` payloads used by the
  smoke and benchmark paths.
- Regression note: after extending `CONAN_DOT_CONTENT_IMPORT_SMOKE=1`, headless
  boot and content-import smoke were rerun. `output/content_import_report.json`
  now stays green with `importedRoutePreviewExists=true` and both fallback
  payloads populated alongside the imported manifest / compiled-map counts.
- `scripts/ui/main_root.gd`: save-migration smoke now also proves that the
  imported fallback route-preview artifact is still readable while migration
  checks run. `output/save_migration_report.json` now carries
  `importedRoutePreviewExists`, `importedRoutePreviewPath`, and the same
  `editorFallbackDungeon` / `editorFallbackTown` payload pair.
- Regression note: after extending `CONAN_DOT_SAVE_MIGRATION_SMOKE=1`, headless
  boot and save-migration smoke were rerun. `output/save_migration_report.json`
  now stays green with `legacyOk=true`, `futureOk=true`,
  `importedRoutePreviewExists=true`, and both fallback payloads populated.
- `scripts/runtime/editor_workspace.gd`: fallback route-preview detail is no
  longer fixed to the artifact's stored strings. The workspace now exposes
  route-target selectors for highlighted NPC services and event step/choice
  state, resolves the live target placement from the selected map, and renders
  the selected target service / step / choice / downstream text from current
  content data.
- New fallback smoke helpers:
  `smoke_set_route_target_service_index(...)`,
  `smoke_set_route_target_event_step_id(...)`, and
  `smoke_set_route_target_event_choice_index(...)`.
- `scripts/tests/editor_smoke.gd`: fallback workspace smoke now drives those
  live selectors directly. It verifies that `townGateToDungeonEvent` can switch
  from the default blood-altar choice to `피를 바친다`, then move to
  `altar_end`, and that `tempTownRouteGatekeeper` can switch between
  `route_info:문 상태를 확인한다` and `talk:청동 문에 대해 묻는다`.
- Regression note: after adding live fallback selectors, `--headless --quit`,
  `EDITOR_SMOKE`, and the local visual smoke loop were rerun. The editor path
  is green again with `fallback_workspace_ok=true` and
  `fallback_workspace_detail_ok=true`, and the standard visual smoke capture set
  still completes through
  [output/07_editor_fallback_dungeon.png](res://output/07_editor_fallback_dungeon.png)
  and
  [output/07_editor_fallback_town.png](res://output/07_editor_fallback_town.png).
- `scripts/ui/main_root.gd`: fallback capture helper now accepts selector-drive
  options and records switched detail variants into the returned artifact. The
  smoke/benchmark/import/migration reports now keep:
  - dungeon event variants for `eventChoice:1` and `eventStep:altar_end`
  - town gatekeeper service variants for `npcService:1` and `npcService:0`
- Runtime/debug reports gained a dedicated gatekeeper payload:
  `editorFallbackTownGatekeeper`. The existing `editorFallbackTown` trainer
  payload remains for `opensService` evidence, while gatekeeper variants cover
  live `route_info <-> talk` row switching.
- Regression note: after widening fallback artifact capture, the following were
  rerun and stayed green:
  - `CONAN_DOT_CONTENT_IMPORT_SMOKE=1`
  - `CONAN_DOT_SAVE_MIGRATION_SMOKE=1`
  - `CONAN_DOT_BENCHMARK_SMOKE=1`
  - `CONAN_DOT_SMOKE=1 ... --smoke`
- Verified report outputs now include structured variant keys in all four
  artifacts:
  [output/smoke_report.json](res://output/smoke_report.json),
  [output/benchmark_report.json](res://output/benchmark_report.json),
  [output/content_import_report.json](res://output/content_import_report.json),
  [output/save_migration_report.json](res://output/save_migration_report.json).
- `scripts/ui/main_root.gd`: fallback workspace capture is now packaged safely.
  `EditorWorkspace.tscn` is referenced through a preload constant instead of a
  string-only `load(...)`, so exported builds include the fallback scene and can
  execute the same route-preview capture path as the editor/local runtime.
- Export/runtime regression note: exported smoke initially failed because
  `res://scenes/editor_tools/EditorWorkspace.tscn` was omitted from the package.
  After switching to the preload reference, export was rebuilt and
  [output/export_smoke/smoke_report.json](res://output/export_smoke/smoke_report.json)
  now includes:
  - `editorFallbackDungeon.variants.eventChoice:1`
  - `editorFallbackDungeon.variants.eventStep:altar_end`
  - `editorFallbackTownGatekeeper.variants.npcService:1`
  - `editorFallbackTownGatekeeper.variants.npcService:0`
- Regression note: after the export inclusion fix, `--export-debug "Linux Desktop"`
  and exported build smoke were rerun successfully. Visual evidence remains at
  [output/export_smoke/07_editor_fallback_dungeon.png](res://output/export_smoke/07_editor_fallback_dungeon.png)
  and
  [output/export_smoke/07_editor_fallback_town.png](res://output/export_smoke/07_editor_fallback_town.png).
- `scripts/runtime/grid_scene.gd`: field monster runtime is no longer only a
  static blocker with `idle/approaching/chasing/returning`. It now supports a
  first gameplay-facing extension:
  - `behavior=patrol`
  - `warningTurns`
  - `patrolPoints`
  - auto-engage when a pursuing blocker reaches player adjacency
- Runtime state now persists `patrolIndex` and `warningCounter` inside
  `runtime.fieldMonsters`, and marker color reflects live AI state so
  `warning/patrolling/chasing/returning` are visible in the 3D scene.
- `scripts/editor/content_tools.gd`: map validation now understands the richer
  `fieldAi` contract and blocks unsupported `behavior`, negative
  `warningTurns`, and invalid `patrolPoints` coordinates.
- `data/source_json/maps/dungeon_floor_01.json`: authored `slime_alpha`
  received a patrol/warning configuration, and generated compiled-map field
  monster creation now mirrors that style for `slime_alpha` guards so the
  compiled dungeon route actually plays the new behavior instead of keeping the
  old guard-only defaults.
- Verification note: after rebuilding the imported bundle through
  `EDITOR_SMOKE`, `DOMAIN_SMOKE` now reports:
  - `before.aiState = patrolling`
  - `afterPatrol.aiState = warning`
  - `afterApproach.aiState = chasing`
  for the `slime_alpha` probe in
  [output/domain_smoke_report.json](res://output/domain_smoke_report.json).
- Regression note: `--headless --quit`, `EDITOR_SMOKE`, `DOMAIN_SMOKE`, and the
  local visual smoke loop were rerun after the gameplay change. The runtime
  stayed green and the standard capture set still completed.
- `scripts/runtime/grid_scene.gd`: field monster runtime now supports
  `behavior=ambush` as a real gameplay state instead of a passive placeholder.
  Ambush monsters:
  - start in `aiState=ambushing`
  - remain hidden from 3D markers and minimap until the player enters
    `wakeRange`
  - transition into `warning/approaching/chasing`
  - return to hidden ambush state after disengaging and returning home
- Runtime state for field monsters now persists `revealed` alongside
  `patrolIndex` and `warningCounter`, so save/load preserves whether an ambush
  blocker has already exposed itself.
- `scripts/editor/content_tools.gd`: `fieldAi` validation now accepts
  `behavior=ambush`, validates non-negative `wakeRange`, and generated
  `grave_robber` compiled placements now receive `wakeRange=2` and
  `warningTurns=1`.
- `scripts/ui/main_root.gd`: domain smoke now probes both the patrol-style
  `slime_alpha` and the ambush-style `grave_robber`.
- Verification note: after rerunning `EDITOR_SMOKE`, `DOMAIN_SMOKE`, and local
  visual smoke, [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  records:
  - `fieldMonsterAmbushProbe.before.aiState = ambushing`
  - `fieldMonsterAmbushProbe.before.revealed = false`
  - `fieldMonsterAmbushProbe.afterApproach.aiState = warning`
  - `fieldMonsterAmbushProbe.afterApproach.revealed = true`
  while the existing `slime_alpha` patrol/warning/chase probe remained green.
- `scripts/runtime/grid_scene.gd`: field monster pursuit now remembers a
  `lastKnownPlayerCell` and has an explicit give-up path instead of perfect
  omniscient chasing. Active monsters now:
  - persist `lostSightCounter`
  - move toward the last known player cell after losing detection
  - transition into `returning`
  - finally restore `patrolling`/`idle`/`ambushing` depending on behavior
- `scripts/editor/content_tools.gd`: `fieldAi` validation now accepts
  `loseSightTurns` and blocks negative values. Generated field AI defaults now
  include `loseSightTurns=1`.
- `scripts/ui/main_root.gd`: domain smoke now asserts the extra
  `afterGiveUp` state for both patrol and ambush probes.
- Verification note: [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  now shows:
  - `fieldMonsterAiProbe.afterGiveUp.aiState = returning`
  - `fieldMonsterAmbushProbe.afterGiveUp.aiState = returning`
  - `fieldMonsterAmbushProbe.afterReturn.aiState = ambushing`
  - `fieldMonsterAmbushProbe.afterReturn.revealed = false`
  which confirms hidden ambushers reveal, pursue, abandon, and hide again.
- `scripts/runtime/grid_scene.gd`: field monsters now propagate alert state to
  allies that share the same encounter-driven alert group. The current runtime
  uses:
  - `fieldAi.alertGroup` if authored
  - otherwise `encounterId`
  as the grouping key.
- When one monster enters `warning`/`approaching`/`chasing` from a passive
  state, other passive monsters in the same alert group now:
  - inherit the current player cell as `lastKnownPlayerCell`
  - reveal if they were ambushing
  - enter `warning` or `approaching`
- `scripts/ui/main_root.gd`: domain smoke now records
  `fieldMonsterGroupProbe` and asserts that a triggered monster can wake an
  allied blocker in the same alert group.
- Verification note: [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  now records:
  - `fieldMonsterGroupProbe.groupId = encounter_grave_robber`
  - `fieldMonsterGroupProbe.sourceBefore.aiState = ambushing`
  - `fieldMonsterGroupProbe.sourceAfter.aiState = chasing`
  - `fieldMonsterGroupProbe.allyBefore.aiState = patrolling`
  - `fieldMonsterGroupProbe.allyAfter.aiState = warning`
  proving encounter-group alert propagation in the compiled dungeon runtime.
- `scripts/runtime/grid_scene.gd`: group alert is no longer fully global per
  encounter. `fieldAi.alertRadius` now limits which allies in the same alert
  group wake up. Radius `0` keeps the old unlimited behavior; positive values
  use Manhattan distance between the source monster and the ally.
- `scripts/editor/content_tools.gd`: generated dungeon guards no longer only
  prove encounter-based grouping. They now export:
  - different `encounterId`
  - shared `fieldAi.alertGroup = generated_floor_guard_pair`
  so authored group ids can override encounter grouping in the compiled bundle.
- `scripts/editor/content_tools.gd`: `fieldAi.alertRadius` is now part of map
  validation and must be non-negative.
- `data/source_json/maps/dungeon_floor_01.json`: authored `slime_alpha`
  received `alertRadius = 8`, and compiled generated `slime_alpha` /
  `grave_robber` guards now also export `alertRadius = 8`.
- Verification note: after `EDITOR_SMOKE`, the imported compiled map at
  [data/imported/maps/dungeon_floor_01.json](res://data/imported/maps/dungeon_floor_01.json)
  now contains:
  - authored `slime_alpha.fieldAi.alertRadius = 8`
  - generated `generated_rect_hall_ns_guard.fieldAi.alertRadius = 8`
  - generated `generated_cross_block_junction_guard.fieldAi.alertRadius = 8`
  while [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  still shows the ally `warning` wake-up path for the nearby grave-robber
  encounter group.
- Verification note: the same imported compiled map now also contains:
  - `generated_rect_hall_ns_guard.encounterId = encounter_serpent_guard`
  - `generated_cross_block_junction_guard.encounterId = encounter_grave_robber`
  - both with `fieldAi.alertGroup = generated_floor_guard_pair`
  and [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  records:
  - `sourceEncounterId = encounter_grave_robber`
  - `allyEncounterId = encounter_serpent_guard`
  - `sourceAlertGroup = generated_floor_guard_pair`
  - `allyAlertGroup = generated_floor_guard_pair`
  - `allyAfter.aiState = warning`
  which proves alert propagation is now driven by `alertGroup`, not only by
  shared encounter id.
- `data/source_json/maps/dungeon_floor_01.json`: the authored floor now carries
  a real cross-encounter alert-group pair:
  - `slime_alpha` now declares `monsterId = slime_alpha`,
    `encounterId = encounter_serpent_guard`, `fieldAi.alertGroup = altar_watch`
  - new authored `grave_robber_scout` declares
    `encounterId = encounter_grave_robber`, `fieldAi.alertGroup = altar_watch`
- `scripts/runtime/grid_scene.gd`: undiscovered `secret_door` placements now
  block movement as well as vision. This affects both player pathing and
  monster movement/path probes until the secret is discovered.
- `scripts/ui/main_root.gd`: domain smoke now records
  `fieldMonsterAuthoredGroupProbe` and `secretDoorProbe`.
- Verification note: [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  now records:
  - `fieldMonsterAuthoredGroupProbe.sourceAlertGroup = altar_watch`
  - `fieldMonsterAuthoredGroupProbe.allyAlertGroup = altar_watch`
  - `fieldMonsterAuthoredGroupProbe.sourceEncounterId = encounter_grave_robber`
  - `fieldMonsterAuthoredGroupProbe.allyEncounterId = encounter_serpent_guard`
  - `fieldMonsterAuthoredGroupProbe.allyAfter.aiState = warning`
  proving authored cross-encounter alert-group propagation on the source map.
- The same report also records:
  - `secretDoorProbe.blockedBefore = true`
  - `secretDoorProbe.blockedAfter = false`
  proving that the secret door is now a real movement blocker until discovered.
- `data/source_json/maps/dungeon_floor_01.json`: added authored
  `ruin_husk_sentry` behind the secret cache route. It patrols with route points
  that cross the secret-door cell and uses `fieldAi.alertGroup = cache_watch`.
- `scripts/runtime/grid_scene.gd`: secret-door-aware movement is now exercised by
  a dedicated authored patrol probe, not only by a player block/unblock check.
- `scripts/ui/main_root.gd`: domain smoke now records
  `secretDoorPatrolProbe`.
- Verification note: [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  now records:
  - `secretDoorPatrolProbe.blockedState.currentCell = [1, 5]`
  - `secretDoorPatrolProbe.discoveredState.currentCell = [1, 4]`
  proving that an authored patrol monster stays put while the secret door is
  hidden and advances through the newly opened route once the secret is
  discovered.
- `scripts/runtime/grid_scene.gd`: detection is no longer pure Manhattan range.
  Field monsters now use:
  - cardinal line-of-sight for vision-based detection
  - `fieldAi.hearingRange` for very short-range non-visual detection
  This keeps wall-separated targets from triggering sight-based alert while
  still allowing adjacent/noisy proximity to wake a monster.
- `scripts/editor/content_tools.gd`: `fieldAi.hearingRange` is now validated and
  must be non-negative. Generated field AI defaults now include
  `hearingRange = 1`.
- `data/source_json/maps/dungeon_floor_01.json`: authored `slime_alpha`
  received `hearingRange = 1`, and the generated compiled guards inherit the
  same default.
- `scripts/ui/main_root.gd`: domain smoke now records
  `fieldMonsterLosProbe`.
- Verification note: [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  now records:
  - `blockedCell = [3, 7]` with `blockedState.aiState = patrolling`
  - `heardCell = [3, 4]` with `heardState.aiState = chasing`
  - `visibleCell = [3, 5]` with `visibleState.aiState = chasing`
  proving that the same monster ignores a wall-blocked target, reacts to
  adjacent hearing, and reacts to clear-line vision.
- `scripts/runtime/grid_scene.gd`: cardinal line-of-sight is now door-aware.
  Vision uses `_cell_blocks_vision(...)` instead of pure wall collision, so:
  - locked doors block sight until unlocked
  - undiscovered secret doors block sight until revealed
  - normal floor cells do not block
- `scripts/ui/main_root.gd`: domain smoke now records
  `fieldMonsterDoorLosProbe` using the authored `sealed_gate` setup.
- Verification note: [output/domain_smoke_report.json](res://output/domain_smoke_report.json)
  now records:
  - `doorId = sealed_gate`
  - `lockedState.aiState = patrolling`
  - `unlockedState.aiState = chasing`
  proving that the same monster cannot see through the locked gate, but can see
  and react once the door is opened.

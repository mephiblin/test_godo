# Next Implementation Priority

Date: 2026-05-24

This document is the active execution backlog for the Godot project. It is based
on the current GDScript-first vertical slice, the completed task notes, and the
original web-repo `godot-port-plan.md`.

## Current Baseline

- Title shell, New Game, Continue, Editor route, save slots, and migration smoke exist.
- Town, dungeon, combat, inventory, NPC service, quest, shop, event, and reward
  loops have working vertical-slice coverage.
- `TownScene.tscn`, `town_scene.gd`, and `town_hub_controller.gd` now own part of
  the town route.
- Field monsters have patrol/warning/chase/return, ambush, give-up/resume, group
  alert, LOS/hearing, authored alert groups, and door/secret-door awareness in
  the current runtime.
- Editor plugin/fallback tools can validate/import/build/export and support
  first-pass definition editing.
- The project is currently GDScript-first, even though the original plan listed
  C# as the preferred domain/runtime/editor tooling language.
- 2026-05-24 P0 pass split town focus HUD into `town_hud.gd`, improved dungeon
  interaction details, widened floor 2/3 field AI content, added route-based
  monster path stepping, and tightened event/NPC/quest validation references.
- 2026-05-24 gameplay pass added dungeon type-specific 3D placement markers,
  animated interaction/focus intent markers, a clearer combat enemy stage, and
  additional floor 3 trap/cache gameplay beats.
- 2026-05-24 UX/authoring pass added dungeon HUD intent chips/next-step guides,
  combat victory/defeat outcome overlays, and placement quick-author actions in
  the editor preview panel.
- 2026-05-24 playability pass listed the remaining porting backlog by gameplay
  risk, added objective/gate guidance to HUD snapshots, added dungeon world
  path markers for active interactions, and added guided event/NPC placement
  selectors in the editor preview panel.
- 2026-05-24 combat domain pass expanded the project domain smoke with direct
  victory/defeat summary assertions for combat outcome data, reward rows, and
  defeat party HP.
- 2026-05-24 objective marker pass promoted quest targets, quest seed
  objectives, and reward turn-in locations into world marker colors and
  always-visible intent nodes.
- 2026-05-24 validation fixture pass added a negative fixture probe that
  intentionally breaks definition and map references to prove the validator
  catches the authored contract failures before import/build.
- 2026-05-24 imported manifest authority pass made runtime registry reject stale
  imported manifests by falling back to source JSON when imported
  `contentVersion` is behind source `contentVersion`.
- 2026-05-24 editor guided contract pass let placement authors apply selected
  event step/choice and NPC service preview rows into authored placement
  metadata, with editor smoke proving source/imported round-trip.
- 2026-05-24 imported map hash contract pass made build bundles record source
  path/hash metadata per compiled map and made runtime fall back to source JSON
  when imported map hashes no longer match.
- 2026-05-24 editor direct definition pass exposed `events` and `npcs` as
  editable definition families and added guided event/NPC row authoring actions.
- 2026-05-24 town focus runtime separation pass moved town focus ranking,
  selected/nearby hub lookup, approach pathing, direction hints, HUD snapshots,
  and service previews into `town_focus_runtime.gd`.
- 2026-05-24 combat domain probe pass added direct headless assertions for skill
  effectOps, item combatUse, enemy combatProfile turns, and equipment resistance.
- 2026-05-24 definition hash contract pass made imported build manifests record
  source hashes for every definition family and made runtime fall back to source
  JSON when those hashes are stale.
- 2026-05-24 town world presenter separation pass moved town ambient presentation
  state/animation and the town build entrypoint into `town_world_presenter.gd`.
- 2026-05-24 dungeon route breadcrumb tuning pass sampled long interaction
  paths, lifted/pulsed breadcrumbs above the floor, and color-coded blocked,
  danger, reward, rest/service, and route targets.
- 2026-05-24 town world ground builder pass moved town cell build looping,
  lighting, ground/path tiles, and boundary meshes into `town_world_presenter.gd`.
- 2026-05-24 play-view HUD occlusion pass reduced the in-game grid/town HUD
  footprint so actual 3D play view, markers, and authored props remain visible
  during smoke-tested town and dungeon routes.
- 2026-05-24 editor/game file-boundary validation pass added editor smoke
  assertions for the dock root name and build/imported manifest metadata after
  dock cleanup.
- 2026-05-24 editor dock engineizing pass renamed the content editor dock root
  and split the monolithic generated `VBoxContainer` stack into Definition,
  Map/Placement, Grid, and Build/Status tabs.
- 2026-05-24 imported runtime boundary probe added a direct headless contract
  that new-game runtime state uses the imported manifest and compiled dungeon
  source without editor-only payload.
- 2026-05-24 town world presenter mesh pass moved town landmark, actor,
  campfire, gate, stall, table, crate, and ambient dressing mesh construction
  out of `grid_scene.gd` into `town_world_presenter.gd`.
- 2026-05-24 editor playtest scene boundary pass made real town/dungeon runtime
  scenes ignore editor test payload by default and moved editor custom play into
  explicit `scenes/editor_tools/Playtest*.tscn` scenes.
- 2026-05-24 dungeon affordance presenter pass moved dungeon placement marker,
  intent marker, focus marker, shape sizing, and affordance animation
  presentation into `dungeon_affordance_presenter.gd`.
- 2026-05-24 dungeon focus path presenter pass moved focus path marker sampling,
  color, mesh, height, scale, and node creation into
  `dungeon_affordance_presenter.gd`.
- 2026-05-24 town focus visual presenter pass moved town focus anchor/path
  visual node construction and anchor animation into `town_world_presenter.gd`.
- 2026-05-24 editor dock scene pass moved the content editor dock root into a
  named `.tscn` scene loaded by both the plugin and editor smoke.
- 2026-05-24 runtime smoke driver pass moved simple visual/benchmark smoke
  actions out of `grid_scene.gd` into a test-only driver loaded only by smoke.
- 2026-05-24 runtime benchmark driver pass moved the benchmark snapshot helper
  out of `grid_scene.gd` into the same test-only smoke driver.
- 2026-05-24 runtime route probe driver pass moved route transition probe
  checks out of `grid_scene.gd` into the test-only smoke driver.
- 2026-05-24 runtime field probe driver pass moved field monster and
  secret-door domain probes out of `grid_scene.gd` into the test-only smoke
  driver.
- 2026-05-24 combat scene smoke driver pass moved combat scene public
  smoke/debug wrappers into a test-only driver used by smoke flows.
- 2026-05-24 combat runtime probe driver pass moved combat runtime smoke/debug
  probe methods into `combat_smoke_driver.gd`.
- 2026-05-24 service overlay smoke driver pass moved the remaining NPC service
  smoke selector out of the production service overlay into a test-only driver.
- 2026-05-24 main root route smoke driver pass moved domain-smoke route
  snapshot/transition scene probes out of `main_root.gd` into a test-only
  driver.
- 2026-05-24 editor fallback smoke driver pass moved editor fallback workspace
  smoke manipulation and variant checks out of `main_root.gd` into a test-only
  driver while preserving visual capture.
- 2026-05-24 editor workspace script boundary pass moved the fallback editor
  workspace script out of `scripts/runtime` into `scripts/editor_tools`.
- 2026-05-24 editor playtest payload boundary pass moved custom play payload
  storage out of `GameApp` into `EditorPlaytestBridge`.
- 2026-05-24 town hub interaction controller pass moved selected/nearby town hub
  Space/Enter interaction decisions out of `grid_scene.gd` into
  `town_hub_controller.gd`.
- 2026-05-24 town presenter wrapper cleanup pass removed trivial town world
  presenter pass-through wrappers from `grid_scene.gd`.
- 2026-05-24 town focus wrapper prune pass removed unused town focus
  pass-through wrappers from `grid_scene.gd`.
- 2026-05-24 town focus controller direct pass moved town focus keyboard,
  approach, and smoke cycling callers onto `town_focus_runtime` instead of
  `grid_scene.gd` private wrapper methods, then removed the now-unused advance,
  approach, and cycle wrappers.
- 2026-05-24 town focus wrapper direct pass routed town HUD focus snapshots and
  focus anchor/path presentation through `town_focus_runtime` directly and
  removed remaining pass-through focus wrapper methods from `grid_scene.gd`.
- 2026-05-24 interaction snapshot builder pass moved HUD interaction snapshot,
  prompt, intent, next-step, and guide text construction out of `grid_scene.gd`
  into `interaction_snapshot_builder.gd`.
- 2026-05-24 field monster runtime helper pass moved field AI config,
  behavior, alert group, patrol route/target, marker color, and state-cell
  helper contracts into `field_monster_runtime.gd`.
- 2026-05-24 field monster tick runtime pass moved field monster runtime
  initialization, tick/update, pathing, LOS, alert propagation, and auto-engage
  checks into `field_monster_runtime.gd`.
- 2026-05-24 dungeon world presenter pass moved dungeon floor/wall/ceiling,
  decor, surface material, and compiled chunk overlay construction out of
  `grid_scene.gd` into `dungeon_world_presenter.gd`.
- 2026-05-24 runtime snapshot builder pass moved HUD/minimap route state,
  field monster snapshot summaries, visited map cells, and quest marker key
  construction out of `grid_scene.gd` into `runtime_snapshot_builder.gd`.
- 2026-05-24 runtime HUD snapshot builder pass moved the complete
  `hud_snapshot()` dictionary assembly out of `grid_scene.gd` into
  `runtime_snapshot_builder.gd`, leaving the scene method as the stable UI
  entrypoint.

## P0

1. `town-runtime-separation`
   - Done: move town-only focus HUD out of `grid_hud.gd` into `town_hud.gd`.
   - Done: move town focus ranking, proximity lookup, anchor/path stepping,
     direction hints, focus snapshots, and service preview summaries out of the
     generic dungeon runtime surface into `town_focus_runtime.gd`.
   - Done: move town ambient presentation state/animation and town world build
     entrypoint into `town_world_presenter.gd`.
   - Done: move town world cell looping, lighting, ground/path tile meshes, and
     boundary meshes into `town_world_presenter.gd`.
   - Done: move town landmark, actor, service prop, campfire, gate, and ambient
     dressing mesh construction helpers out of `grid_scene.gd` into
     `town_world_presenter.gd`.
   - Done: move town focus anchor/path visual node construction and anchor
     animation out of `grid_scene.gd` into `town_world_presenter.gd`.
   - Done: remove simple town visual-smoke action wrappers from `grid_scene.gd`;
     visual/benchmark smoke now uses a test driver for quest, focus, service,
     route, inventory, and reward actions.
   - Done: remove the remaining NPC service selector smoke helper from
     `service_overlay.gd`; visual smoke now selects gatekeeper/scholar services
     through `service_overlay_smoke_driver.gd`.
   - Done: move domain-smoke route snapshot/transition helpers out of
     `main_root.gd`; domain smoke now uses `route_smoke_driver.gd` for those
     temporary probe scenes.
   - Done: move editor fallback route-preview workspace smoke manipulation and
     variant text checks out of `main_root.gd`; save/content/benchmark/visual
     smoke now uses `editor_fallback_smoke_driver.gd`.
   - Done: move `EditorWorkspace.tscn` script from `scripts/runtime` to
     `scripts/editor_tools`, so fallback editor tooling no longer lives in the
     game runtime script tree.
   - Done: remove editor custom-play payload storage/accessors from `GameApp`;
     explicit playtest scenes now consume `EditorPlaytestBridge` only when their
     `allow_editor_test_payload` flag is enabled.
   - Done: move selected/nearby town hub interaction handling out of
     `grid_scene.gd`; `town_hub_controller.gd` now owns town Space/Enter
     approach and fallback service interaction behavior.
   - Done: remove trivial town world presenter pass-through wrappers from
     `grid_scene.gd`; town scene/presenter code now calls the presenter directly
     for world build, ambient animation, and focus visuals.
   - Done: prune unused town focus wrappers from `grid_scene.gd` after their
     callers moved into town-specific runtime/controller code.
   - Done: route town focus keyboard handling and smoke focus cycling through
     `town_focus_runtime` directly, reducing external dependence on
     `grid_scene.gd` private town-focus methods and removing unused focus
     advance/approach/cycle wrappers.
   - Done: route town HUD focus snapshots and town focus anchor/path visuals
     through `town_focus_runtime` directly, removing the remaining focus
     snapshot/anchor/path/service-preview pass-through wrappers from
     `grid_scene.gd`.
   - Done: move mixed town/dungeon interaction HUD snapshot and prompt
     construction out of `grid_scene.gd` into a dedicated runtime helper while
     preserving the current interaction dictionary contract.
   - Done: move field monster AI helper contracts into
     `field_monster_runtime.gd`, keeping the current scene/test call surface as
     thin delegates ahead of a future full tick-loop split.
   - Done: move the field monster initialization and tick/update loop into
     `field_monster_runtime.gd`; `grid_scene.gd` now keeps compatibility
     delegates for existing scene and smoke-driver callers.
   - Done: move dungeon world mesh/decor/material/chunk overlay construction
     into `dungeon_world_presenter.gd`, leaving `grid_scene.gd` to orchestrate
     route setup and runtime state.
   - Done: move runtime HUD/minimap route, field monster, visited-cell, and
     quest marker snapshot helpers into `runtime_snapshot_builder.gd`, keeping
     existing scene/test methods as delegates.
   - Done: move the full runtime HUD snapshot dictionary construction into
     `runtime_snapshot_builder.gd`, with `grid_scene.gd` retaining only the
     public `hud_snapshot()` delegate used by `grid_hud.gd`.
   - Reduce remaining town route dependency on generic dungeon world dressing
     assumptions.

2. `dungeon-interaction-affordance`
   - Done: interaction snapshots now include stronger door, route, event, trap,
     loot, and combat detail plus intent labels.
   - Done: dungeon placements now render with type-specific 3D marker shapes,
     rings, animated intent nodes, and a focused target marker.
   - Done: dungeon HUD now renders active intent chips and next-step guidance.
   - Done: active dungeon interactions now draw short world-space path markers
     from the player to the focused object where a route can be found.
   - Done: HUD snapshots now expose current objective, quest seed, and blocked
     gate guidance as an in-game objective panel.
   - Done: quest target, quest seed objective, and reward turn-in placements now
     get distinct world marker colors and stay visible as intent affordances.
   - Done: active dungeon path markers now sample long routes, lift/pulse above
     the floor, and use intent-specific colors/shapes for blocked, danger,
     reward, rest/service, and route targets.
   - Done: actual visual-smoke captures now use a compact HUD presentation that
     no longer covers most of the town/dungeon 3D play view.
   - Done: dungeon marker/intent/focus shape construction and affordance
     animation moved out of `grid_scene.gd` into
     `dungeon_affordance_presenter.gd`.
   - Done: dungeon focus path marker sampling and node construction moved out
     of `grid_scene.gd` into `dungeon_affordance_presenter.gd`; the grid scene
     now computes the path and delegates rendering.
   - Done: remove simple dungeon visual-smoke action wrappers from
     `grid_scene.gd`; visual/benchmark smoke now uses a test driver for route,
     event, movement, combat entry, and return-town actions.
   - Done: remove `debug_benchmark_snapshot()` from `grid_scene.gd`;
     benchmark smoke now collects that state through the test driver.
   - Done: remove `smoke_probe_route_to_map()` from `grid_scene.gd`;
     domain smoke now evaluates route gate state through the test driver.
   - Done: remove remaining public `smoke_probe_*` field monster and
     secret-door helpers from `grid_scene.gd`; domain smoke now runs them
     through the test driver.
   - Next: do manual play tuning for marker size in narrow halls and crowded
     authored encounters.
   - Re-split dungeon HUD and town HUD responsibilities after the town HUD move.

3. `editor-authoring-parity`
   - Expand `ConnanEditorPlugin` from a dock/import tool into stronger engine
     authoring workflows.
   - Prioritize Map/Build, Generator, Event Graph, NPC/Quest, Material, and Light
     authoring surfaces.
   - Keep preview/import/validation/build working while adding real editing UX.
   - Done: content editor dock no longer appears as an anonymous
     `@VBoxContainer@...` tab and no longer exposes all authoring surfaces in one
     unbounded vertical stack.
   - Done: content editor dock is now instantiated from a named
     `ContentEditorDock.tscn` scene instead of a script-only anonymous container.
   - Done: editor smoke now directly guards the content editor dock root name
     while checking build/import handoff metadata.
   - Done: editor Play Selected now launches explicit editor playtest scenes
     instead of making production town/dungeon scenes consume editor payload.

4. `validation-import-contract`
   - Done: stricter checks now cover missing material, broken `entryStepId`, step
     target, choice next-step ref, effect item target, quest seed state ref, NPC
     service handoff ref, and quest/quest-seed reward item refs.
   - Done: fixture probe now intentionally breaks quest reward item, event
     entry/choice/effect refs, quest seed state refs, NPC handoff refs, vendor
     skill refs, map material/placement refs, and fieldAi values, then asserts
     validator errors.
   - Done: runtime registry now treats source JSON as authority when imported
     cache contentVersion is stale, and exposes warnings in content validation.
   - Done: imported build bundles now record compiled map `sourcePath` and
     `sourceHash`, and runtime falls back to source JSON if a compiled map hash
     is stale.
   - Done: imported build bundles now record definition-family source hashes,
     and runtime falls back to source JSON if any definition hash is stale.
   - Done: editor smoke now asserts the imported build manifest path,
     validation report, definition hashes, and compiled map source hash metadata
     remain intact across the editor/game file boundary.
   - Done: imported runtime probe now asserts normal new-game state uses the
     imported manifest, compiled map metadata, and compiled dungeon source while
     keeping editor-only keys out of save data.
   - Done: imported runtime probe now asserts real `DungeonScene.tscn` does not
     consume pending editor test payload.
   - Broaden stale bundle and content-version mismatch handling to exported
     build metadata and CI artifact reports.

5. `technology-direction-sync`
   - Current decision: stay GDScript-first for the vertical-slice hardening pass.
   - Revisit C# only after registry/save/validator contracts stop moving.
   - If C# is reintroduced, migrate in this order: validators -> registry -> save
     -> combat -> quest.

## P1

1. `field-monster-content-expansion`
   - Done: floor 2 and 3 now include authored AI, alert groups, factions, and
     multiple behavior profiles.
   - Done: monster chase uses a path step before falling back to greedy movement,
     so door/secret-door-aware blocking participates in route choice.
   - Next: apply faction alert rules in runtime if content proves it needs them.
   - Apply a wider set of authored `fieldAi` combinations to real content.
   - Add faction-level alert rules only if content needs them.

2. `combat-system-hardening`
   - Done: combat screen now has a readable enemy stage with HP/guard/status and
     action intent presentation instead of only a text block.
   - Done: combat victory/defeat outcomes now have clearer overlay summaries and
     explicit continuation choices.
   - Done: domain smoke now directly asserts victory/defeat summary data,
     reward rows, monster instance IDs, and defeat HP state.
   - Done: dedicated combat domain probe now directly checks armor break,
     lifesteal, healing, party guard, item damage/status/cure, guardian/coward
     combatProfile behavior, and poison resistance.
   - Done: `combat_scene.gd` no longer exposes public smoke/debug wrappers;
     smoke flows drive its runtime through `combat_smoke_driver.gd`.
   - Done: `combat_runtime.gd` no longer exposes public smoke/debug probe
     methods; direct combat domain probes now use `combat_smoke_driver.gd`.
   - Move additional combat tests beyond smoke-only coverage into smaller direct
     domain probes as multi-enemy and party-role systems expand.
   - Expand skill/item/effect authoring coverage.
   - Use enemy `combatProfile` more broadly.
   - Polish defeat, reward, and end-state UX further.

3. `npc-quest-shop-expansion`
   - Apply NPC/service patterns to a broader content family.
   - Expand authored quest seed and progression hooks.
   - Strengthen service handoff and downstream surface contracts.
   - Clarify objective and gating descriptions across town and dungeon.

4. `editor-authoring-ux`
   - Done: placement preview includes quick-author actions for traps, rest points,
     field monsters, NPC services, route links, and loot caches.
   - Done: event/rest/trap/NPC placements now include guided event/NPC selectors
     and label-sync actions in the preview authoring panel.
   - Done: selected event step/choice and selected NPC service can now be applied
     as placement authoring contract fields and survive source/imported round-trip.
   - Done: `events` and `npcs` are now editable definition families in the dock,
     with guided event entry-step/choice authoring and NPC talk-service authoring
     backed by editor smoke assertions.
   - Done: selected event steps, event choices, and NPC services now have
     row-level field editors that mutate the authored arrays without hand-editing
     the whole JSON block.
   - Next: replace the remaining raw JSON array fallback with visual event graph
     node/edge editing and a dedicated NPC service list editor.

5. `save-migration-packaging`
   - Expand regression coverage around save robustness.
   - Collect more exported-build play evidence.
   - Finish packaging cleanup and connect CI if the repo workflow needs it.

## P2

1. `test-stack-structure`
   - Separate validator, domain test, scene smoke, export smoke, and benchmark layers.
   - Done: validation fixtures now have a dedicated headless probe command.
   - Done: editor smoke has direct assertions for dock root naming and
     build/imported manifest boundary metadata.
   - Done: imported runtime probe directly checks imported-only startup
     contracts without relying on screenshots.
   - Reduce reliance on screenshot artifacts where direct assertions are possible.
   - Standardize headless commands for future CI.

2. `data-authority-contract`
   - Make `source_json`, `imported`, and `user://editor_projects` authority
     boundaries stricter.
   - Done: stale imported manifest fallback now prevents runtime from silently
     loading an older cache over newer source JSON.
   - Done: stale imported map-hash fallback now prevents runtime from silently
     loading compiled maps generated from older source JSON.
   - Done: stale imported definition-hash fallback now prevents runtime from
     silently loading definition families generated from older source JSON.
   - Document data paths runtime must never mutate.
   - Clarify fallback editor versus real plugin authoring contracts.
   - Define canonical JSON write-back behavior for inspector edits.

3. `planning-doc-sync`
   - Keep completed items and remaining items separated in planning docs.
   - Mark where implementation is ahead of or behind the original port plan.
   - Update this priority file at the end of each scoped implementation task.

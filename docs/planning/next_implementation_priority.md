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

## P0

1. `town-runtime-separation`
   - Done: move town-only focus HUD out of `grid_hud.gd` into `town_hud.gd`.
   - Next: remove remaining town focus, anchor/path marker, proximity, and service
     preview helpers from the generic dungeon runtime surface.
   - Reduce town route dependency on generic dungeon interaction assumptions.

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
   - Next: tune path marker density/occlusion after manual play sessions.
   - Re-split dungeon HUD and town HUD responsibilities after the town HUD move.

3. `editor-authoring-parity`
   - Expand `ConnanEditorPlugin` from a dock/import tool into stronger engine
     authoring workflows.
   - Prioritize Map/Build, Generator, Event Graph, NPC/Quest, Material, and Light
     authoring surfaces.
   - Keep preview/import/validation/build working while adding real editing UX.

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
   - Broaden stale bundle and content-version mismatch handling to definition
     families and exported build metadata.

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
   - Move remaining combat tests beyond smoke-only coverage into smaller direct
     domain probes where autoload context is available.
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
   - Next: convert event graph and NPC service definition rows themselves from
     preview-only into direct guided editors.

5. `save-migration-packaging`
   - Expand regression coverage around save robustness.
   - Collect more exported-build play evidence.
   - Finish packaging cleanup and connect CI if the repo workflow needs it.

## P2

1. `test-stack-structure`
   - Separate validator, domain test, scene smoke, export smoke, and benchmark layers.
   - Done: validation fixtures now have a dedicated headless probe command.
   - Reduce reliance on screenshot artifacts where direct assertions are possible.
   - Standardize headless commands for future CI.

2. `data-authority-contract`
   - Make `source_json`, `imported`, and `user://editor_projects` authority
     boundaries stricter.
   - Done: stale imported manifest fallback now prevents runtime from silently
     loading an older cache over newer source JSON.
   - Done: stale imported map-hash fallback now prevents runtime from silently
     loading compiled maps generated from older source JSON.
   - Document data paths runtime must never mutate.
   - Clarify fallback editor versus real plugin authoring contracts.
   - Define canonical JSON write-back behavior for inspector edits.

3. `planning-doc-sync`
   - Keep completed items and remaining items separated in planning docs.
   - Mark where implementation is ahead of or behind the original port plan.
   - Update this priority file at the end of each scoped implementation task.

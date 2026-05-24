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
   - Next: add dedicated dungeon HUD visual treatment for intent labels and
     optional path-to-object guidance where useful.
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
   - Next: add fixture tests that intentionally break each contract and assert the
     validator error.
   - Tighten the source JSON -> imported cache -> manifest export contract.
   - Broaden stale bundle and content-version mismatch handling.

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
   - Move combat tests beyond smoke-only coverage into direct domain assertions.
   - Expand skill/item/effect authoring coverage.
   - Use enemy `combatProfile` more broadly.
   - Polish defeat, reward, and end-state UX further.

3. `npc-quest-shop-expansion`
   - Apply NPC/service patterns to a broader content family.
   - Expand authored quest seed and progression hooks.
   - Strengthen service handoff and downstream surface contracts.
   - Clarify objective and gating descriptions across town and dungeon.

4. `save-migration-packaging`
   - Expand regression coverage around save robustness.
   - Collect more exported-build play evidence.
   - Finish packaging cleanup and connect CI if the repo workflow needs it.

## P2

1. `test-stack-structure`
   - Separate validator, domain test, scene smoke, export smoke, and benchmark layers.
   - Reduce reliance on screenshot artifacts where direct assertions are possible.
   - Standardize headless commands for future CI.

2. `data-authority-contract`
   - Make `source_json`, `imported`, and `user://editor_projects` authority
     boundaries stricter.
   - Document data paths runtime must never mutate.
   - Clarify fallback editor versus real plugin authoring contracts.
   - Define canonical JSON write-back behavior for inspector edits.

3. `planning-doc-sync`
   - Keep completed items and remaining items separated in planning docs.
   - Mark where implementation is ahead of or behind the original port plan.
   - Update this priority file at the end of each scoped implementation task.

# Godot Port Status

Date: 2026-05-24
Status: implementation snapshot and plan delta.

## Summary

The Godot port has moved beyond bootstrap into a broad vertical slice. The
project currently runs with GDScript-first services, scenes, and editor tooling.
This is different from the original `godot-port-plan.md`, which expected C# to
own most domain/runtime/editor tooling and GDScript to remain glue.

The active question is no longer whether the vertical slice exists. It does.
The remaining work is to separate town/dungeon responsibilities, raise dungeon
interaction readability, close editor parity gaps, tighten validation/import
contracts, and decide whether the C# plan still applies.

As of the 2026-05-24 P0 pass, the implementation direction is explicitly
GDScript-first for the hardening phase. C# migration is deferred until registry,
save, validator, combat, and quest contracts stop changing enough to justify a
typed rewrite.

## Implemented Baseline

- Godot project bootstrap with autoload services and scene routing.
- Title, New Game, Continue, Town, Dungeon, Combat, Inventory, and Editor routes.
- 3-slot save skeleton, schema migration, content-version blocking, and save smoke.
- Source JSON loading, imported content manifest, definition registry, and build
  manifest export.
- Authored/compiled map runtime path with town and dungeon routes.
- Town-specific scene wrapper and hub controller foundation.
- Town focus HUD moved into a dedicated `town_hud.gd` layer, leaving
  `grid_hud.gd` as the generic/dungeon-capable HUD.
- Town landmark, focus, anchor marker, path preview, service preview, and hub HUD
  payload foundation.
- Dungeon grid movement, collision, doors, stairs, traps, events, loot, rest,
  NPC placement, and combat handoff.
- Dungeon interaction prompts now expose concrete intent/detail for routes,
  gates, combat entries, events, traps, doors, secrets, and loot.
- Field monster FSM foundation with patrol, warning, chase, return, ambush,
  give-up/resume, group alert, LOS/hearing, door and secret-door effects, and
  authored alert groups.
- Floor 2 and floor 3 now include authored field AI, alert groups, factions, and
  additional monster placements.
- Field monster chase first tries path-based stepping, then falls back to greedy
  movement.
- Combat runtime/view-model split, skill/item/effect handling, cooldowns,
  target confirmation, status behavior, reward/defeat flow, and smoke probes.
- NPC services for talk, quest, shop/trade, heal, identify, recruit, fight, and
  avoid branches.
- Quest seed runtime state, event-driven completion hooks, and reward claiming.
- Editor plugin/fallback tooling for content lists, definition editing,
  validation, import/build/export, and test-play launch.
- Editor validation now checks broken event entry/step refs, choice next-step
  refs, event effect item/quest-seed targets, NPC service handoff refs, and
  quest/quest-seed reward item refs.
- Desktop export preset and export smoke baseline.

## Ahead Of The Original Plan

- The runtime has playable town/dungeon/combat/NPC/quest/shop loops beyond the
  initial M0-M3 bootstrap target.
- Town now has stronger hub readability than the original early plan required.
- Field monster behavior is already broader than a minimal blocker/chase slice.
- Save/content/export smoke coverage exists earlier than a strict milestone
  reading would require.

## Behind Or Divergent From The Original Plan

- The implementation is GDScript-first, while older planning still states C# first.
- Some town focus, anchor/path marker, proximity, and service preview helpers
  still live in generic grid runtime code.
- Dungeon affordance has improved, but still lacks dedicated world-space path and
  next-step markers comparable to town focus anchors.
- Editor tooling is still short of full authoring parity for map/generator/event
  graph/NPC/material/light workflows.
- Validation/import contracts need stricter cross-definition reference checks.
- Data authority boundaries between source JSON, imported cache, runtime save,
  and fallback editor projects need clearer enforcement.
- Tests are strong as smoke coverage, but not yet structured enough as direct
  domain/validator/scene/export layers.

## Near-Term Decision

For the next implementation phase, continue GDScript-first. Keep data structures
JSON-serializable, keep runtime from mutating `res://data/source_json`, and treat
`res://data/imported` as regenerated build/cache output. Reconsider C# only as a
staged migration after validators, registry, save, combat, and quest contracts
stabilize. If migration resumes, use this order: validators, registry, save,
combat, quest.

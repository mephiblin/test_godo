extends Node3D

@export var default_map_id := ""
@export var route_name := ""
@export var allow_editor_test_payload := false

const DIRS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
const TOWN_FOCUS_RUNTIME_SCRIPT := preload("res://scripts/runtime/town_focus_runtime.gd")
const TOWN_WORLD_PRESENTER_SCRIPT := preload("res://scripts/runtime/town_world_presenter.gd")
const DUNGEON_AFFORDANCE_PRESENTER_SCRIPT := preload("res://scripts/runtime/dungeon_affordance_presenter.gd")

var map_data: Dictionary = {}
var current_slot := 1
var player_cell := Vector2i.ZERO
var facing := 0
var log_lines: Array[String] = []
var placement_nodes: Dictionary = {}
var placement_rings: Dictionary = {}
var placement_intent_nodes: Dictionary = {}
var dungeon_focus_node: MeshInstance3D
var dungeon_focus_path_nodes: Array[MeshInstance3D] = []
var active_overlay: Control
var cached_materials: Dictionary = {}
var map_profile: Dictionary = {}
var object_theme: Dictionary = {}
var decor_cells: Dictionary = {}
var compiled_preview: Dictionary = {}
var chunk_overlay_nodes: Array[Node3D] = []
var compiled_runtime_active := false
var dungeon_source_mode := GameApp.DUNGEON_SOURCE_COMPILED
var town_focus_runtime: RefCounted
var town_world_presenter: RefCounted
var dungeon_affordance_presenter: RefCounted

@onready var world_root: Node3D = $WorldRoot
@onready var player_rig: Node3D = $PlayerRig3D
@onready var sun: DirectionalLight3D = $Sun

func setup(payload: Dictionary) -> void:
	if payload.is_empty() and allow_editor_test_payload:
		payload = GameApp.consume_editor_test_payload(route_name)
	current_slot = int(payload.get("slot", GameApp.current_slot))
	var save_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = save_data.get("runtime", {})
	var map_id := String(payload.get("map_id", runtime.get("mapId", default_map_id)))
	dungeon_source_mode = String(payload.get("dungeon_source", GameApp.dungeon_runtime_source))
	map_data = ContentRegistry.get_map(map_id)
	if map_data.is_empty():
		push_error("Missing map: %s" % map_id)
		return
	GameApp.current_mode = route_name
	map_profile = ContentRegistry.find_map_profile(String(map_data.get("mapProfileId", "")), map_id)
	object_theme = ContentRegistry.find_object_theme(String(map_data.get("objectThemeId", "")), String(map_data.get("themeId", "")))
	compiled_preview = map_data.get("compiledPreview", {})
	map_data = _promote_compiled_runtime_map(map_data)
	var start: Array = map_data.get("start", [1, 1])
	player_cell = Vector2i(start[0], start[1])
	facing = int(map_data.get("facing", 0))
	if String(runtime.get("mapId", "")) == map_id:
		var saved_cell: Array = runtime.get("playerCell", start)
		player_cell = Vector2i(saved_cell[0], saved_cell[1])
		facing = int(runtime.get("facing", facing))
	log_lines = []
	_ensure_field_monster_runtime()
	town_focus_runtime = TOWN_FOCUS_RUNTIME_SCRIPT.new().configure(self)
	town_world_presenter = TOWN_WORLD_PRESENTER_SCRIPT.new().configure(self)
	dungeon_affordance_presenter = DUNGEON_AFFORDANCE_PRESENTER_SCRIPT.new().configure(self)
	_build_world()
	_refresh_town_focus_targets()
	_apply_player_transform()
	_refresh_interaction_focus()
	_log("%s loaded." % map_id)

func _ready() -> void:
	if map_data.is_empty():
		setup({})

func _process(_delta: float) -> void:
	if not _is_town_map():
		_animate_dungeon_affordances()

func build_hud() -> Control:
	return preload("res://scripts/ui/grid_hud.gd").new().configure(self)

func hud_snapshot() -> Dictionary:
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var party_state: Dictionary = slot_data.get("partyState", {})
	var front: Dictionary = party_state.get("front", {})
	var runtime: Dictionary = slot_data.get("runtime", {})
	var route_summary := _route_summary()
	return {
		"title": "%s Scene" % route_name.capitalize(),
		"hudMode": "dungeon",
		"state": "[b]Cell[/b] %s  [b]Facing[/b] %d\n[b]Map[/b] %s\n[b]Profile[/b] %s\n[b]Theme[/b] %s / props %s\n[b]Chunk[/b] %s\n[b]Dungeon Source[/b] %s\n[b]Generated[/b] active=%s cells=%d placements=%d\n[b]Routes[/b] %s\n[b]Field AI[/b] %s\n[b]Gold[/b] %d\n[b]Supplies[/b] food %d / water %d / torch %d\n[b]Front[/b] HP %d/%d  status %s\n[b]Quest[/b] %s\n[b]Items[/b] %s\n[b]Prompt[/b] %s\n[b]Controls[/b] %s" % [
			player_cell,
			facing,
			map_data.get("id", ""),
			String(map_profile.get("name", map_data.get("mapProfileId", "-"))),
			String(map_data.get("themeId", map_profile.get("theme", "-"))),
			String(object_theme.get("id", "-")),
			_active_chunk_label(),
			dungeon_source_mode,
			str(compiled_runtime_active),
			compiled_preview.get("generatedCells", []).size(),
			compiled_preview.get("generatedPlacements", []).size(),
			route_summary,
			_field_monster_state_summary(runtime),
			int(slot_data.get("resources", {}).get("gold", 0)),
			int(slot_data.get("resources", {}).get("food", 0)),
			int(slot_data.get("resources", {}).get("water", 0)),
			int(slot_data.get("resources", {}).get("torch", 0)),
			int(front.get("hp", 20)),
			int(front.get("maxHp", 20)),
			str(front.get("statuses", [])),
			String(QuestService.current_quest(current_slot).get("status", "none")),
			str(SaveService.inventory(current_slot)),
			_interaction_prompt_text(),
			_controls_summary()
		],
		"log": "\n".join(log_lines.slice(max(log_lines.size() - 5, 0), log_lines.size())),
		"objective": _objective_guide_snapshot(),
		"interaction": _interaction_snapshot(),
		"minimap": {
			"mapId": String(map_data.get("id", "")),
			"cells": map_data.get("cells", []),
			"currentCell": [player_cell.x, player_cell.y],
			"visitedKeys": _visited_keys_for_map(runtime),
			"placements": _visible_minimap_placements(runtime),
			"routeStates": _route_state_entries(),
			"fieldMonsterStates": _field_monster_snapshot(runtime),
			"questStatus": String(QuestService.current_quest(current_slot).get("status", "none")),
			"questTargetKeys": _quest_target_keys(),
			"rewardTurnInKeys": _quest_turn_in_keys(),
			"questSeedObjectiveKeys": _quest_seed_objective_keys()
		}
	}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				_try_move(DIRS[facing])
			KEY_S:
				_try_move(-DIRS[facing])
			KEY_A:
				_turn_player(-1)
			KEY_D:
				_turn_player(1)
			KEY_SPACE, KEY_ENTER:
				_interact_forward()
			KEY_I:
				_toggle_inventory_overlay()
			KEY_R:
				_try_rest()
			KEY_T:
				GameApp.return_to_title()

func _turn_player(step: int) -> void:
	facing = posmod(facing + step, 4)
	_apply_player_transform()
	_refresh_town_focus_targets()
	_refresh_interaction_focus()
	_persist_runtime()

func _controls_summary() -> String:
	return "W move, A/D turn, Space interact, I inventory, R rest, T title"

func _try_forward_move() -> void:
	_try_move(DIRS[facing])

func _try_backward_move() -> void:
	_try_move(-DIRS[facing])

func smoke_probe_route_to_map(target_map_id: String) -> Dictionary:
	for placement in map_data.get("placements", []):
		if String(placement.get("targetMapId", "")) != target_map_id:
			continue
		if String(placement.get("type", "")) not in ["gate", "stairs"]:
			continue
		var blocked_message := _route_block_message(placement)
		if blocked_message != "":
			return {
				"ok": false,
				"blockedMessage": blocked_message,
				"targetMapId": target_map_id
			}
		return {
			"ok": true,
			"blockedMessage": "",
			"targetMapId": target_map_id
		}
	return {"ok": false, "blockedMessage": "Missing route placement.", "targetMapId": target_map_id}

func smoke_probe_field_monster_ai(monster_id: String) -> Dictionary:
	var slot_before: Dictionary = SaveService.load_slot(current_slot).duplicate(true)
	var matches: Array[Dictionary] = []
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("monsterId", placement.get("id", ""))) != monster_id:
			continue
		matches.append(placement)
	var target_placement: Dictionary = {}
	for placement in matches:
		if _field_ai_behavior(placement) == "ambush":
			target_placement = placement
			break
	if target_placement.is_empty() and not matches.is_empty():
		target_placement = matches[0]
	if target_placement.is_empty():
		return {"ok": false}
	var before_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var placement_id := String(target_placement.get("id", ""))
	var before_state: Dictionary = before_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	var ai_config := _field_ai_config(target_placement)
	var before_cell := player_cell
	_tick_field_monsters()
	var after_patrol_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var after_patrol: Dictionary = after_patrol_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	var target_cell := _placement_runtime_cell(target_placement, before_runtime)
	player_cell = target_cell + Vector2i(0, 2)
	_tick_field_monsters()
	var after_approach_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var after_approach: Dictionary = after_approach_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	player_cell = target_cell + Vector2i(0, 6)
	_tick_field_monsters()
	var after_give_up_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var after_give_up: Dictionary = after_give_up_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	for _i in range(4):
		_tick_field_monsters()
	var after_return_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var after_return: Dictionary = after_return_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	player_cell = before_cell
	SaveService.save_slot(current_slot, slot_before)
	_persist_runtime()
	return {
		"ok": true,
		"fieldAi": ai_config,
		"before": before_state,
		"afterPatrol": after_patrol,
		"afterApproach": after_approach,
		"afterGiveUp": after_give_up,
		"afterReturn": after_return
	}

func smoke_probe_field_monster_group_alert(monster_id: String) -> Dictionary:
	var slot_before: Dictionary = SaveService.load_slot(current_slot).duplicate(true)
	var source_matches: Array[Dictionary] = []
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("monsterId", placement.get("id", ""))) != monster_id:
			continue
		source_matches.append(placement)
	var source_placement: Dictionary = {}
	for placement in source_matches:
		if _field_ai_behavior(placement) == "ambush":
			source_placement = placement
			break
	if source_placement.is_empty() and not source_matches.is_empty():
		source_placement = source_matches[0]
	if source_placement.is_empty():
		return {"ok": false, "reason": "no_source"}
	var group_id := _field_alert_group_id(source_placement)
	if group_id == "":
		return {"ok": false, "reason": "no_group"}
	var ally_placement: Dictionary = {}
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("id", "")) == String(source_placement.get("id", "")):
			continue
		if _field_alert_group_id(placement) == group_id:
			ally_placement = placement
			break
	if ally_placement.is_empty():
		return {"ok": false, "reason": "no_ally"}
	var before_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var source_id := String(source_placement.get("id", ""))
	var ally_id := String(ally_placement.get("id", ""))
	var source_before: Dictionary = before_runtime.get("fieldMonsters", {}).get(source_id, {}).duplicate(true)
	var ally_before: Dictionary = before_runtime.get("fieldMonsters", {}).get(ally_id, {}).duplicate(true)
	var before_cell := player_cell
	var source_cell := _placement_runtime_cell(source_placement, before_runtime)
	player_cell = _smoke_probe_cell_near(source_cell, 2)
	_tick_field_monsters()
	var after_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var source_after: Dictionary = after_runtime.get("fieldMonsters", {}).get(source_id, {}).duplicate(true)
	var ally_after: Dictionary = after_runtime.get("fieldMonsters", {}).get(ally_id, {}).duplicate(true)
	player_cell = before_cell
	SaveService.save_slot(current_slot, slot_before)
	_persist_runtime()
	return {
		"ok": true,
		"groupId": group_id,
		"sourceId": source_id,
		"allyId": ally_id,
		"sourceEncounterId": String(source_placement.get("encounterId", "")),
		"allyEncounterId": String(ally_placement.get("encounterId", "")),
		"sourceAlertGroup": String(_field_ai_config(source_placement).get("alertGroup", "")),
		"allyAlertGroup": String(_field_ai_config(ally_placement).get("alertGroup", "")),
		"sourceBefore": source_before,
		"sourceAfter": source_after,
		"allyBefore": ally_before,
		"allyAfter": ally_after
	}

func smoke_probe_field_monster_los(monster_id: String) -> Dictionary:
	var slot_before: Dictionary = SaveService.load_slot(current_slot).duplicate(true)
	var target_placement: Dictionary = {}
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("monsterId", placement.get("id", ""))) != monster_id:
			continue
		target_placement = placement
		break
	if target_placement.is_empty():
		return {"ok": false}
	var before_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var placement_id := String(target_placement.get("id", ""))
	var target_cell := _placement_runtime_cell(target_placement, before_runtime)
	var before_cell := player_cell
	player_cell = target_cell + Vector2i(0, 4)
	_tick_field_monsters()
	var blocked_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var blocked_state: Dictionary = blocked_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	player_cell = target_cell + Vector2i(0, 1)
	_tick_field_monsters()
	var heard_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var heard_state: Dictionary = heard_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	player_cell = target_cell + Vector2i(0, 2)
	_tick_field_monsters()
	var visible_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var visible_state: Dictionary = visible_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	player_cell = before_cell
	SaveService.save_slot(current_slot, slot_before)
	_persist_runtime()
	return {
		"ok": true,
		"fieldAi": _field_ai_config(target_placement),
		"blockedCell": [target_cell.x, target_cell.y + 4],
		"heardCell": [target_cell.x, target_cell.y + 1],
		"visibleCell": [target_cell.x, target_cell.y + 2],
		"blockedState": blocked_state,
		"heardState": heard_state,
		"visibleState": visible_state
	}

func _smoke_probe_cell_near(origin: Vector2i, preferred_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = [
		origin + Vector2i(0, preferred_distance),
		origin + Vector2i(0, -preferred_distance),
		origin + Vector2i(preferred_distance, 0),
		origin + Vector2i(-preferred_distance, 0),
		origin + Vector2i(0, 1),
		origin + Vector2i(0, -1),
		origin + Vector2i(1, 0),
		origin + Vector2i(-1, 0)
	]
	for cell in candidates:
		if not _cell_hard_blocked(cell):
			return cell
	return origin

func smoke_probe_field_monster_door_los(monster_id: String, door_id: String) -> Dictionary:
	var slot_before: Dictionary = SaveService.load_slot(current_slot).duplicate(true)
	var target_placement: Dictionary = {}
	var door_placement: Dictionary = {}
	for placement in map_data.get("placements", []):
		var placement_id := String(placement.get("id", ""))
		if placement_id == door_id:
			door_placement = placement
		if String(placement.get("type", "")) == "field_monster" and String(placement.get("monsterId", placement.get("id", ""))) == monster_id:
			target_placement = placement
	if target_placement.is_empty() or door_placement.is_empty():
		return {"ok": false}
	var target_cell := _placement_runtime_cell(target_placement)
	var before_cell := player_cell
	var locked_slot := SaveService.load_slot(current_slot)
	var locked_runtime: Dictionary = locked_slot.get("runtime", {})
	var reset_state := {
		"startCell": [target_cell.x, target_cell.y],
		"currentCell": [target_cell.x, target_cell.y],
		"monsterId": String(target_placement.get("monsterId", target_placement.get("id", ""))),
		"patrolIndex": 0,
		"warningCounter": 0,
		"lostSightCounter": 0,
		"lastKnownPlayerCell": [target_cell.x, target_cell.y],
		"revealed": _field_ai_behavior(target_placement) != "ambush",
		"aiState": "patrolling" if _field_ai_behavior(target_placement) == "patrol" else ("ambushing" if _field_ai_behavior(target_placement) == "ambush" else "idle")
	}
	var locked_field_monsters: Dictionary = locked_runtime.get("fieldMonsters", {})
	locked_field_monsters[String(target_placement.get("id", ""))] = reset_state
	locked_runtime["fieldMonsters"] = locked_field_monsters
	var locked_unlocked_doors: Dictionary = locked_runtime.get("unlockedDoors", {})
	locked_unlocked_doors[door_id] = false
	locked_runtime["unlockedDoors"] = locked_unlocked_doors
	locked_slot["runtime"] = locked_runtime
	SaveService.save_slot(current_slot, locked_slot)
	player_cell = target_cell + Vector2i(-2, 0)
	_tick_field_monsters()
	var locked_runtime_after: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var locked_state: Dictionary = locked_runtime_after.get("fieldMonsters", {}).get(String(target_placement.get("id", "")), {}).duplicate(true)
	var unlocked_slot := SaveService.load_slot(current_slot)
	var unlocked_runtime: Dictionary = unlocked_slot.get("runtime", {})
	var unlocked_doors: Dictionary = unlocked_runtime.get("unlockedDoors", {})
	unlocked_doors[door_id] = true
	unlocked_runtime["unlockedDoors"] = unlocked_doors
	unlocked_slot["runtime"] = unlocked_runtime
	SaveService.save_slot(current_slot, unlocked_slot)
	_tick_field_monsters()
	var unlocked_runtime_after: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var unlocked_state: Dictionary = unlocked_runtime_after.get("fieldMonsters", {}).get(String(target_placement.get("id", "")), {}).duplicate(true)
	player_cell = before_cell
	SaveService.save_slot(current_slot, slot_before)
	_persist_runtime()
	return {
		"ok": true,
		"doorId": door_id,
		"blockedCell": [target_cell.x - 2, target_cell.y],
		"lockedState": locked_state,
		"unlockedState": unlocked_state
	}

func smoke_probe_secret_door_blocking(secret_id: String) -> Dictionary:
	var slot_before: Dictionary = SaveService.load_slot(current_slot).duplicate(true)
	var secret_placement: Dictionary = {}
	for placement in map_data.get("placements", []):
		if String(placement.get("id", "")) == secret_id:
			secret_placement = placement
			break
	if secret_placement.is_empty():
		return {"ok": false}
	var secret_cell := _placement_runtime_cell(secret_placement)
	var before_cell := player_cell
	var before_facing := facing
	player_cell = secret_cell + Vector2i(0, 1)
	facing = 3
	var blocked_before := _is_blocked(secret_cell)
	_discover_secret(secret_placement)
	var blocked_after := _is_blocked(secret_cell)
	player_cell = before_cell
	facing = before_facing
	SaveService.save_slot(current_slot, slot_before)
	_persist_runtime()
	return {
		"ok": true,
		"secretId": secret_id,
		"cell": [secret_cell.x, secret_cell.y],
		"blockedBefore": blocked_before,
		"blockedAfter": blocked_after
	}

func smoke_probe_secret_door_patrol(monster_id: String, secret_id: String) -> Dictionary:
	var slot_before: Dictionary = SaveService.load_slot(current_slot).duplicate(true)
	var target_placement: Dictionary = {}
	var secret_placement: Dictionary = {}
	for placement in map_data.get("placements", []):
		if String(placement.get("id", "")) == secret_id:
			secret_placement = placement
		if String(placement.get("type", "")) == "field_monster" and String(placement.get("monsterId", placement.get("id", ""))) == monster_id:
			target_placement = placement
	if target_placement.is_empty() or secret_placement.is_empty():
		return {
			"ok": false,
			"reason": "missing_target_or_secret",
			"monsterId": monster_id,
			"secretId": secret_id
		}
	var start_cell := _placement_runtime_cell(target_placement)
	var before_cell := player_cell
	var slot_data := SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	field_monsters[String(target_placement.get("id", ""))] = {
		"startCell": [start_cell.x, start_cell.y],
		"currentCell": [start_cell.x, start_cell.y],
		"monsterId": String(target_placement.get("monsterId", target_placement.get("id", ""))),
		"patrolIndex": 1,
		"warningCounter": 0,
		"lostSightCounter": 0,
		"lastKnownPlayerCell": [start_cell.x, start_cell.y],
		"revealed": true,
		"aiState": "patrolling"
	}
	runtime["fieldMonsters"] = field_monsters
	var discovered: Dictionary = runtime.get("discoveredSecrets", {})
	discovered[String(secret_placement.get("id", ""))] = false
	runtime["discoveredSecrets"] = discovered
	slot_data["runtime"] = runtime
	SaveService.save_slot(current_slot, slot_data)
	player_cell = Vector2i(6, 1)
	_tick_field_monsters()
	var blocked_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var blocked_state: Dictionary = blocked_runtime.get("fieldMonsters", {}).get(String(target_placement.get("id", "")), {}).duplicate(true)
	_discover_secret(secret_placement)
	_tick_field_monsters()
	var discovered_runtime: Dictionary = SaveService.load_slot(current_slot).get("runtime", {})
	var discovered_state: Dictionary = discovered_runtime.get("fieldMonsters", {}).get(String(target_placement.get("id", "")), {}).duplicate(true)
	player_cell = before_cell
	SaveService.save_slot(current_slot, slot_before)
	_persist_runtime()
	return {
		"ok": true,
		"monsterId": monster_id,
		"secretId": secret_id,
		"blockedState": blocked_state,
		"discoveredState": discovered_state
	}

func _build_world() -> void:
	for child in world_root.get_children():
		child.queue_free()
	placement_nodes.clear()
	placement_rings.clear()
	placement_intent_nodes.clear()
	dungeon_focus_node = null
	chunk_overlay_nodes.clear()
	if town_world_presenter != null:
		town_world_presenter.call("clear")
	cached_materials.clear()
	decor_cells = _build_decor_cells()
	if _is_town_map():
		_build_town_world()
		_refresh_field_monsters()
		return
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(1.0, 0.12, 1.0)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1.0, 1.8, 1.0)
	var ceiling_mesh := BoxMesh.new()
	ceiling_mesh.size = Vector3(1.0, 0.1, 1.0)
	var wall_material := _resolve_surface_material(String(map_data.get("wallMaterialId", "")), Color("7a6a57"))
	var ceiling_material := _resolve_surface_material(String(map_data.get("ceilingMaterialId", "")), Color("42382d"))
	var cells: Array = map_data.get("cells", [])
	for y in range(cells.size()):
		var row := String(cells[y])
		for x in range(row.length()):
			var tile := row[x]
			if tile == "#":
				var wall := MeshInstance3D.new()
				wall.mesh = wall_mesh
				wall.material_override = wall_material
				wall.position = Vector3(x, 0.5, y)
				wall.scale = Vector3(1, 1, 1)
				world_root.add_child(wall)
			else:
				var tile_role := _tile_role_at(Vector2i(x, y))
				var floor := MeshInstance3D.new()
				floor.mesh = floor_mesh
				floor.material_override = _material_for_tile_role(tile_role)
				floor.position = Vector3(x, -0.06, y)
				world_root.add_child(floor)
				var ceiling := MeshInstance3D.new()
				ceiling.mesh = ceiling_mesh
				ceiling.material_override = ceiling_material
				ceiling.position = Vector3(x, 1.78, y)
				world_root.add_child(ceiling)
				_spawn_decor_for_cell(Vector2i(x, y), tile_role)
	for placement in map_data.get("placements", []):
		_spawn_dungeon_placement(placement)
	_spawn_dungeon_focus_marker()
	_spawn_chunk_overlay()
	_refresh_field_monsters()

func _spawn_dungeon_placement(placement: Dictionary) -> void:
	if dungeon_affordance_presenter != null:
		dungeon_affordance_presenter.call("spawn_placement", placement)

func _spawn_dungeon_focus_marker() -> void:
	if dungeon_affordance_presenter != null:
		dungeon_affordance_presenter.call("spawn_focus_marker")

func _dungeon_marker_mesh(kind: String) -> Mesh:
	return dungeon_affordance_presenter.call("marker_mesh", kind)

func _dungeon_intent_mesh(kind: String) -> Mesh:
	return dungeon_affordance_presenter.call("intent_mesh", kind)

func _dungeon_marker_height(kind: String) -> float:
	return float(dungeon_affordance_presenter.call("marker_height", kind))

func _dungeon_intent_height(kind: String) -> float:
	return float(dungeon_affordance_presenter.call("intent_height", kind))

func _dungeon_marker_scale(kind: String) -> Vector3:
	return dungeon_affordance_presenter.call("marker_scale", kind)

func _dungeon_intent_scale(kind: String) -> Vector3:
	return dungeon_affordance_presenter.call("intent_scale", kind)

func _dungeon_ring_radius(kind: String) -> float:
	return float(dungeon_affordance_presenter.call("ring_radius", kind))

func _is_town_map() -> bool:
	return String(map_data.get("kind", "")) == "town"

func _build_town_world() -> void:
	if town_world_presenter != null:
		town_world_presenter.call("build_world")

func _spawn_town_placement(placement: Dictionary) -> void:
	if town_world_presenter != null:
		town_world_presenter.call("spawn_placement", placement)
	var marker := _spawn_placement_beacon(placement, 0.2)
	placement_nodes[String(placement.get("id", ""))] = marker

func _spawn_placement_beacon(placement: Dictionary, height: float) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.28
	marker_mesh.height = 0.56
	marker.mesh = marker_mesh
	var pos: Array = placement.get("position", [0, 0])
	marker.position = Vector3(float(pos[0]), height, float(pos[1]))
	marker.scale = Vector3(0.35, 0.35, 0.35)
	marker.material_override = _marker_material(_placement_runtime_color(placement))
	world_root.add_child(marker)
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.42
	ring_mesh.bottom_radius = 0.54
	ring_mesh.height = 0.04
	ring.mesh = ring_mesh
	ring.material_override = _flat_color_material(_placement_runtime_color(placement).darkened(0.2))
	ring.position = Vector3(float(pos[0]), 0.03, float(pos[1]))
	world_root.add_child(ring)
	placement_rings[String(placement.get("id", ""))] = ring
	return marker

func _placement_runtime_color(placement: Dictionary) -> Color:
	var objective_color := _objective_marker_color(placement)
	if objective_color.a > 0.0:
		return objective_color
	if String(placement.get("type", "")) in ["gate", "stairs"] and _route_block_message(placement) != "":
		return Color("aa644d")
	return _placement_color(String(placement.get("type", "")))

func _objective_marker_color(placement: Dictionary) -> Color:
	var pos := _placement_runtime_cell(placement)
	var key := "%d,%d" % [pos.x, pos.y]
	if _quest_turn_in_keys().has(key):
		return Color("6fd2b3")
	if _quest_seed_objective_keys().has(key):
		return Color("d06fe8")
	if _quest_target_keys().has(key):
		return Color("f06c6c")
	return Color(0, 0, 0, 0)

func _register_town_ambient_node(node: Node3D, kind: String, data: Dictionary = {}) -> void:
	if town_world_presenter != null:
		town_world_presenter.call("register_ambient_node", node, kind, data)

func _animate_town_ambient() -> void:
	if town_world_presenter != null:
		town_world_presenter.call("animate_ambient")

func _flat_color_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _promote_compiled_runtime_map(source_map: Dictionary) -> Dictionary:
	compiled_runtime_active = false
	if route_name != GameApp.MODE_DUNGEON or dungeon_source_mode != GameApp.DUNGEON_SOURCE_COMPILED:
		return source_map
	var generated_cells: Array = compiled_preview.get("generatedCells", [])
	if generated_cells.is_empty():
		return source_map
	var promoted := source_map.duplicate(true)
	promoted["authoredCells"] = source_map.get("cells", [])
	promoted["authoredPlacements"] = source_map.get("placements", [])
	promoted["cells"] = generated_cells
	promoted["size"] = [String(generated_cells[0]).length(), generated_cells.size()]
	promoted["start"] = compiled_preview.get("generatedStart", source_map.get("start", [1, 1]))
	var merged_placements: Array = []
	var generated_types := {}
	var generated_monster_ids := {}
	for placement in compiled_preview.get("generatedPlacements", []):
		if typeof(placement) == TYPE_DICTIONARY:
			generated_types[String(placement.get("type", ""))] = true
			var monster_id := String(placement.get("monsterId", ""))
			if monster_id != "":
				generated_monster_ids[monster_id] = true
		merged_placements.append(placement)
	for placement in source_map.get("placements", []):
		if typeof(placement) == TYPE_DICTIONARY:
			var placement_type := String(placement.get("type", ""))
			if placement_type == "stairs" and generated_types.has(placement_type):
				if String(placement.get("targetRoute", "")) == GameApp.MODE_TOWN:
					continue
			elif placement_type in ["rest", "loot"] and generated_types.has(placement_type):
				continue
			if placement_type == "field_monster":
				var authored_monster_id := String(placement.get("monsterId", placement.get("id", "")))
				if generated_monster_ids.has(authored_monster_id):
					continue
		merged_placements.append(placement)
	promoted["placements"] = merged_placements
	compiled_runtime_active = true
	return promoted

func _spawn_chunk_overlay() -> void:
	var layout_entries: Array = compiled_preview.get("chunkLayout", [])
	if layout_entries.is_empty():
		return
	var grid_meta: Dictionary = compiled_preview.get("chunkGrid", {})
	var grid_width := maxi(int(grid_meta.get("width", 1)), 1)
	var grid_height := maxi(int(grid_meta.get("height", 1)), 1)
	var map_size: Array = map_data.get("size", [8, 8])
	var map_width := maxi(float(map_size[0]) - 2.0, 1.0)
	var map_height := maxi(float(map_size[1]) - 2.0, 1.0)
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.55, 0.18, 0.55)
	for entry in layout_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var layout_pos: Array = entry.get("layoutPos", [0, 0])
		var gx := float(layout_pos[0])
		var gy := float(layout_pos[1])
		var world_x := 1.0 + ((gx + 0.5) / float(grid_width)) * map_width
		var world_y := 1.0 + ((gy + 0.5) / float(grid_height)) * map_height
		var node := MeshInstance3D.new()
		node.mesh = box_mesh
		node.material_override = _chunk_overlay_material(entry)
		node.position = Vector3(world_x, 0.11, world_y)
		world_root.add_child(node)
		chunk_overlay_nodes.append(node)
	var anchor_mesh := SphereMesh.new()
	anchor_mesh.radius = 0.1
	anchor_mesh.height = 0.2
	for anchor in compiled_preview.get("anchorLayout", []):
		if typeof(anchor) != TYPE_DICTIONARY:
			continue
		var ax := float(anchor.get("x", 0))
		var ay := float(anchor.get("y", 0))
		var chunk_cell_width := maxi(float(grid_meta.get("cellWidth", 1)), 1.0)
		var chunk_cell_height := maxi(float(grid_meta.get("cellHeight", 1)), 1.0)
		var preview_width := maxi(float(grid_width) * chunk_cell_width, 1.0)
		var preview_height := maxi(float(grid_height) * chunk_cell_height, 1.0)
		var world_x := 1.0 + ((ax + 0.5) / preview_width) * map_width
		var world_y := 1.0 + ((ay + 0.5) / preview_height) * map_height
		var node := MeshInstance3D.new()
		node.mesh = anchor_mesh
		node.material_override = _anchor_overlay_material(String(anchor.get("kind", "")))
		node.position = Vector3(world_x, 0.3, world_y)
		world_root.add_child(node)
		chunk_overlay_nodes.append(node)
	for placement in compiled_preview.get("generatedPlacements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var pos: Array = placement.get("position", [0, 0])
		var node := MeshInstance3D.new()
		node.mesh = BoxMesh.new()
		node.material_override = _generated_overlay_material(String(placement.get("type", "")))
		node.position = Vector3(float(pos[0]), 0.52, float(pos[1]))
		node.scale = Vector3(0.22, 0.22, 0.22)
		world_root.add_child(node)
		chunk_overlay_nodes.append(node)

func _chunk_overlay_material(entry: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var role_tags: Array = entry.get("roleTags", [])
	var color := Color("4d7ea8")
	if role_tags.has("boss"):
		color = Color("9a4d4d")
	elif role_tags.has("reward"):
		color = Color("8f7a38")
	elif role_tags.has("combat"):
		color = Color("6b5aa8")
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _anchor_overlay_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var color := Color("d7d7d7")
	match kind:
		"loot":
			color = Color("d9bd5a")
		"boss_spawn":
			color = Color("c85f5f")
		"encounter":
			color = Color("9961c9")
		"junction":
			color = Color("59a7b5")
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _generated_overlay_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var color := Color("c2c2c2")
	match kind:
		"loot":
			color = Color("d8b74e")
		"field_monster":
			color = Color("b95c7a")
		"rest":
			color = Color("58a36b")
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _active_chunk_label() -> String:
	var layout_entries: Array = compiled_preview.get("chunkLayout", [])
	if layout_entries.is_empty():
		return "-"
	var map_size: Array = map_data.get("size", [8, 8])
	var normalized_x := clampf(float(player_cell.x) / maxi(float(map_size[0]) - 1.0, 1.0), 0.0, 0.9999)
	var normalized_y := clampf(float(player_cell.y) / maxi(float(map_size[1]) - 1.0, 1.0), 0.0, 0.9999)
	var grid_meta: Dictionary = compiled_preview.get("chunkGrid", {})
	var grid_width := maxi(int(grid_meta.get("width", 1)), 1)
	var grid_height := maxi(int(grid_meta.get("height", 1)), 1)
	var target_x := mini(int(floor(normalized_x * float(grid_width))), grid_width - 1)
	var target_y := mini(int(floor(normalized_y * float(grid_height))), grid_height - 1)
	for entry in layout_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var layout_pos: Array = entry.get("layoutPos", [0, 0])
		if int(layout_pos[0]) == target_x and int(layout_pos[1]) == target_y:
			return "%s (%s)" % [String(entry.get("id", "")), String(entry.get("presetId", ""))]
	return "-"

func _tile_role_at(cell: Vector2i) -> String:
	var openings: Array[String] = []
	for pair in [
		{"dir": Vector2i(0, -1), "name": "north"},
		{"dir": Vector2i(1, 0), "name": "east"},
		{"dir": Vector2i(0, 1), "name": "south"},
		{"dir": Vector2i(-1, 0), "name": "west"}
	]:
		if not _is_wall(cell + pair["dir"]):
			openings.append(String(pair["name"]))
	if openings.size() <= 1:
		return "end_cap"
	if openings.size() == 2:
		var straight := openings.has("north") and openings.has("south") or openings.has("east") and openings.has("west")
		return "corridor" if straight else "corner"
	if openings.size() == 3:
		return "junction"
	return "intersection"

func _is_wall(cell: Vector2i) -> bool:
	var cells: Array = map_data.get("cells", [])
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := String(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	return row[cell.x] == "#"

func _material_for_tile_role(tile_role: String) -> Material:
	var theme_id := String(map_data.get("themeId", map_profile.get("theme", "")))
	for substitution in ContentRegistry.find_tile_substitutions(theme_id, "floor"):
		var roles: Array = substitution.get("whenTileRoles", [])
		if roles.has(tile_role):
			var variants: Array = substitution.get("variants", [])
			if not variants.is_empty():
				var variant_index: int = int(abs(hash("%s:%s:%s" % [map_data.get("id", ""), tile_role, map_profile.get("id", "")])) % variants.size())
				var variant: Dictionary = variants[variant_index]
				return _resolve_surface_material(String(variant.get("materialId", "")), Color("443c34"))
	return _resolve_surface_material(String(map_data.get("defaultFloorMaterialId", "")), Color("443c34"))

func _resolve_surface_material(material_id: String, fallback_color: Color) -> StandardMaterial3D:
	if cached_materials.has(material_id):
		return cached_materials[material_id]
	var material := StandardMaterial3D.new()
	var definition := ContentRegistry.get_definition("materials", material_id)
	var color_string := String(definition.get("baseColor", definition.get("fallbackColor", "")))
	material.albedo_color = Color(color_string) if color_string != "" else fallback_color
	material.roughness = float(definition.get("roughness", 1.0))
	material.metallic = float(definition.get("metalness", 0.0))
	material.emission_enabled = float(definition.get("emissiveIntensity", 0.0)) > 0.0
	if material.emission_enabled:
		material.emission = Color(String(definition.get("emissive", "#000000")))
		material.emission_energy_multiplier = float(definition.get("emissiveIntensity", 0.0))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if material_id != "":
		cached_materials[material_id] = material
	return material

func _build_decor_cells() -> Dictionary:
	var result := {}
	var decor_list: Array = object_theme.get("decor", [])
	if decor_list.is_empty():
		return result
	var open_cells: Array[Vector2i] = []
	var start: Array = map_data.get("start", [0, 0])
	var start_cell := Vector2i(int(start[0]), int(start[1]))
	var cells: Array = map_data.get("cells", [])
	for y in range(cells.size()):
		var row := String(cells[y])
		for x in range(row.length()):
			if row[x] != "#":
				open_cells.append(Vector2i(x, y))
	open_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return abs(a.x - start_cell.x) + abs(a.y - start_cell.y) < abs(b.x - start_cell.x) + abs(b.y - start_cell.y)
	)
	for decor in decor_list:
		if typeof(decor) != TYPE_DICTIONARY:
			continue
		var max_per_map := maxi(int(decor.get("maxPerMap", 0)), 0)
		if max_per_map <= 0:
			continue
		var placed := 0
		for cell in open_cells:
			if placed >= max_per_map:
				break
			if cell == start_cell:
				continue
			if _cell_has_placement(cell):
				continue
			var tile_role := _tile_role_at(cell)
			if not decor.get("tileRoles", []).has(tile_role):
				continue
			if placed > 0:
				var pick: int = int(abs(hash("%s:%s:%s" % [decor.get("kind", ""), cell, map_data.get("id", "")])) % 100)
				if pick >= int(decor.get("weight", 1)) * 14:
					continue
			result["%d,%d" % [cell.x, cell.y]] = decor
			placed += 1
	return result

func _cell_has_placement(cell: Vector2i) -> bool:
	for placement in map_data.get("placements", []):
		var pos: Array = placement.get("position", [0, 0])
		if Vector2i(pos[0], pos[1]) == cell:
			return true
	return false

func _spawn_decor_for_cell(cell: Vector2i, tile_role: String) -> void:
	var decor: Dictionary = decor_cells.get("%d,%d" % [cell.x, cell.y], {})
	if decor.is_empty():
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _decor_mesh(String(decor.get("kind", "")))
	mesh_instance.material_override = _decor_material(String(decor.get("color", "#a98d68")))
	mesh_instance.position = Vector3(cell.x, 0.18, cell.y)
	mesh_instance.scale = _decor_scale(String(decor.get("kind", "")), tile_role)
	world_root.add_child(mesh_instance)

func _decor_mesh(kind: String) -> Mesh:
	match kind:
		"torch", "broken_pillar":
			return CylinderMesh.new()
		"bones", "ritual_bowl":
			return SphereMesh.new()
		_:
			return BoxMesh.new()

func _decor_material(color_code: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color_code)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _decor_scale(kind: String, tile_role: String) -> Vector3:
	match kind:
		"torch":
			return Vector3(0.16, 1.4, 0.16)
		"broken_pillar":
			return Vector3(0.3, 1.25, 0.3)
		"bones":
			return Vector3(0.18, 0.08, 0.28)
		"ritual_bowl":
			return Vector3(0.18, 0.08, 0.18)
		_:
			return Vector3(0.28, 0.24 if tile_role == "corridor" else 0.32, 0.28)

func _placement_color(kind: String) -> Color:
	match kind:
		"gate", "stairs":
			return Color("d7c27a")
		"field_monster":
			return Color("d04f4f")
		"rest":
			return Color("5fb77d")
		"event":
			return Color("cc6f9a")
		"trap":
			return Color("8e73c7")
		"locked_door":
			return Color("b18857")
		"secret_door":
			return Color("62a088")
		"loot":
			return Color("d29b4d")
		"npc_service":
			return Color("8db0d9")
		_:
			return Color("7ca3d8")

func _marker_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _refresh_field_monsters() -> void:
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
	var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
	for placement in map_data.get("placements", []):
		var node: MeshInstance3D = placement_nodes.get(String(placement.get("id", "")))
		match String(placement.get("type", "")):
			"field_monster":
				var state: Dictionary = field_monsters.get(String(placement.get("id", "")), {})
				var defeated := bool(state.get("defeated", false))
				var behavior := _field_ai_behavior(placement)
				var revealed := bool(state.get("revealed", behavior != "ambush"))
				if node:
					node.visible = not defeated and revealed
					var cell := _placement_runtime_cell(placement, runtime)
					node.position = Vector3(cell.x, _dungeon_marker_height("field_monster"), cell.y)
					node.material_override = _marker_material(_field_monster_marker_color(state))
			"secret_door":
				if node:
					node.visible = bool(discovered_secrets.get(String(placement.get("id", "")), false))
			"locked_door":
				if node:
					node.visible = not bool(unlocked_doors.get(String(placement.get("id", "")), false))
			"loot":
				var claimed_loot: Dictionary = runtime.get("claimedLoot", {})
				if node:
					node.visible = not bool(claimed_loot.get(String(placement.get("id", "")), false))
	_refresh_interaction_focus()

func _apply_player_transform() -> void:
	player_rig.call("apply_cell", player_cell, facing, _view_profile())

func _view_profile() -> Dictionary:
	if _is_town_map():
		return {
			"cameraPosition": Vector3(0.0, 1.55, 2.45),
			"cameraRotationDegrees": Vector3(-28, 0, 0)
		}
	return {
		"cameraPosition": Vector3(0.0, 0.9, 0.0),
		"cameraRotationDegrees": Vector3(-18, 180, 0)
	}

func _try_move(direction: Vector2i) -> void:
	var next := player_cell + direction
	if _is_blocked(next):
		_log("Blocked at %s." % next)
		return
	player_cell = next
	var combat_trigger: Dictionary = _tick_field_monsters()
	_apply_player_transform()
	_refresh_town_focus_targets()
	_refresh_interaction_focus()
	_persist_runtime()
	_log("Moved to %s." % next)
	if not combat_trigger.is_empty():
		_log("%s lunges from the dark." % String(combat_trigger.get("label", combat_trigger.get("id", "Monster"))))
		_enter_combat(combat_trigger)

func _is_blocked(cell: Vector2i) -> bool:
	var cells: Array = map_data.get("cells", [])
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := String(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	if row[cell.x] == "#":
		return true
	for placement in map_data.get("placements", []):
		var placement_cell := _placement_runtime_cell(placement)
		if placement_cell != cell:
			continue
		if String(placement.get("type", "")) == "locked_door" and bool(placement.get("blocking", false)):
			var slot_data: Dictionary = SaveService.load_slot(current_slot)
			var runtime: Dictionary = slot_data.get("runtime", {})
			var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
			if not bool(unlocked_doors.get(String(placement.get("id", "")), false)):
				return true
		if String(placement.get("type", "")) == "secret_door":
			var slot_data: Dictionary = SaveService.load_slot(current_slot)
			var runtime: Dictionary = slot_data.get("runtime", {})
			var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
			if not bool(discovered_secrets.get(String(placement.get("id", "")), false)):
				return true
		if String(placement.get("type", "")) == "field_monster" and bool(placement.get("blocking", false)):
			var slot_data: Dictionary = SaveService.load_slot(current_slot)
			var runtime: Dictionary = slot_data.get("runtime", {})
			var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
			var state: Dictionary = field_monsters.get(String(placement.get("id", "")), {})
			if not bool(state.get("defeated", false)):
				return true
	return false

func _interact_forward() -> void:
	var front_placement := _front_interaction_placement()
	if not front_placement.is_empty():
		_trigger_interaction_placement(front_placement)
		return
	if _is_town_map():
		var selected := _selected_town_focus_placement(2)
		if not selected.is_empty():
			if _try_approach_town_focus(selected):
				return
			_log("%s 쪽으로 손을 뻗었다." % String(selected.get("label", selected.get("id", "거점"))))
			_trigger_interaction_placement(selected)
			return
		var nearby := _town_nearby_interaction_placement(1)
		if not nearby.is_empty():
			_log("%s 쪽으로 손을 뻗었다." % String(nearby.get("label", nearby.get("id", "거점"))))
			_trigger_interaction_placement(nearby)
			return
	_log("Nothing to interact with.")

func _front_interaction_placement() -> Dictionary:
	var target_cell: Vector2i = player_cell + DIRS[facing]
	for placement in map_data.get("placements", []):
		if _placement_runtime_cell(placement) == target_cell:
			return placement
	return {}

func _trigger_interaction_placement(placement: Dictionary) -> void:
	match String(placement.get("type", "")):
		"gate", "stairs":
			_route_from_placement(placement)
		"field_monster":
			_enter_combat(placement)
		"quest_board", "healer", "skill_shop", "trade", "npc_service":
			_open_service_overlay(placement)
		"event":
			_trigger_event_placement(placement)
		"locked_door":
			_try_unlock_door(placement)
		"secret_door":
			_discover_secret(placement)
		"loot":
			_collect_loot(placement)
		"rest":
			_rest_at_placement(placement)
		"trap":
			_trigger_trap(placement)
		_:
			_log("Interacted with %s." % placement.get("label", "placement"))

func _town_nearby_interaction_placement(max_distance: int) -> Dictionary:
	if town_focus_runtime == null:
		return {}
	return town_focus_runtime.call("nearby_interaction_placement", max_distance)

func _selected_town_focus_placement(max_distance: int = -1) -> Dictionary:
	if town_focus_runtime == null:
		return {}
	return town_focus_runtime.call("selected_placement", max_distance)

func _placement_supports_town_proximity(placement: Dictionary) -> bool:
	if town_focus_runtime == null:
		return false
	return bool(town_focus_runtime.call("supports_proximity", placement))

func _try_approach_town_focus(placement: Dictionary) -> bool:
	if town_focus_runtime == null:
		return false
	return bool(town_focus_runtime.call("try_approach", placement))

func _try_advance_town_focus_path() -> bool:
	if town_focus_runtime == null:
		return false
	return bool(town_focus_runtime.call("try_advance_path"))

func _town_interaction_anchor_cell(placement: Dictionary) -> Vector2i:
	if town_focus_runtime == null:
		return player_cell
	return town_focus_runtime.call("interaction_anchor_cell", placement)

func _town_next_step_toward(anchor: Vector2i) -> Vector2i:
	if town_focus_runtime == null:
		return player_cell
	return town_focus_runtime.call("next_step_toward", anchor)

func _interaction_snapshot() -> Dictionary:
	var placement := _front_interaction_placement()
	var source := "front"
	var distance: int = 1
	if placement.is_empty() and _is_town_map():
		placement = _selected_town_focus_placement(2)
		if not placement.is_empty():
			source = "selected"
		else:
			placement = _town_nearby_interaction_placement(2)
			if not placement.is_empty():
				source = "nearby"
		if not placement.is_empty():
			var nearby_cell := _placement_runtime_cell(placement)
			distance = abs(nearby_cell.x - player_cell.x) + abs(nearby_cell.y - player_cell.y)
	if placement.is_empty():
		return {
			"available": false,
			"title": "앞에 상호작용 대상이 없다.",
			"detail": "시선을 돌리거나 한 칸 이동해 거점과 통로를 맞춘다."
		}
	var kind := String(placement.get("type", ""))
	var title := String(placement.get("label", placement.get("id", kind)))
	var action := "Space로 상호작용"
	var detail := ""
	if source == "selected" and distance > 1:
		action = "Space로 접근"
	match kind:
		"quest_board":
			if action == "Space로 상호작용":
				action = "Space로 의뢰 확인"
			detail = "현재 보드 오퍼와 보상 전표를 확인한다.\n%s" % _town_service_preview(placement)
		"healer":
			if action == "Space로 상호작용":
				action = "Space로 치료"
			detail = "전열 체력과 상태를 회복하는 서비스다.\n%s" % _town_service_preview(placement)
		"skill_shop":
			if action == "Space로 상호작용":
				action = "Space로 기술 상점 열기"
			detail = "현재 재고와 리롤 가능한 기술 목록을 본다.\n%s" % _town_service_preview(placement)
		"trade":
			if action == "Space로 상호작용":
				action = "Space로 거래"
			detail = "소모품과 잡화를 구매한다.\n%s" % _town_service_preview(placement)
		"npc_service":
			if action == "Space로 상호작용":
				action = "Space로 대화"
			detail = "NPC 서비스와 대화 분기를 연다.\n%s" % _town_service_preview(placement)
		"gate", "stairs":
			if action == "Space로 상호작용":
				action = "Space로 이동"
			var blocked_message := _route_block_message(placement)
			detail = _route_affordance_detail(placement, blocked_message)
		"rest":
			if action == "Space로 상호작용":
				action = "Space로 휴식"
			detail = "짧은 휴식과 회복을 시도한다.\n%s" % _town_service_preview(placement)
		"field_monster":
			action = "Space로 전투 진입"
			detail = _field_monster_affordance_detail(placement)
		"event":
			action = "Space로 이벤트 조사"
			detail = _event_affordance_detail(placement)
		"locked_door":
			action = "Space로 문 확인"
			detail = _door_affordance_detail(placement)
		"secret_door":
			action = "Space로 비밀문 확인"
			detail = _secret_affordance_detail(placement)
		"loot":
			action = "Space로 수집"
			detail = _loot_affordance_detail(placement)
		"trap":
			action = "Space로 함정 접촉"
			detail = _trap_affordance_detail(placement)
	return {
		"available": true,
		"id": String(placement.get("id", "")),
		"type": kind,
		"title": title,
		"action": action,
		"detail": detail,
		"blocked": kind in ["gate", "stairs"] and _route_block_message(placement) != "",
		"source": source,
		"distance": distance,
		"hint": _interaction_alignment_hint(placement, source, distance),
		"selection": _town_focus_summary(placement, source),
		"anchorCell": _town_anchor_snapshot(placement, source),
		"intent": _interaction_intent_label(placement, source, distance),
		"nextStep": _interaction_next_step_snapshot(placement, source),
		"guide": _interaction_guide_text(placement, source, distance)
	}

func _interaction_next_step_snapshot(placement: Dictionary, source: String) -> Array:
	if placement.is_empty():
		return []
	if _is_town_map() and source == "selected":
		var anchor := _town_interaction_anchor_cell(placement)
		var next_step := _town_next_step_toward(anchor)
		if next_step != player_cell:
			return [next_step.x, next_step.y]
	var cell := _placement_runtime_cell(placement)
	return [cell.x, cell.y]

func _interaction_guide_text(placement: Dictionary, source: String, distance: int) -> String:
	var intent := _interaction_intent_label(placement, source, distance)
	if source == "selected" and distance > 1:
		return "W/Space advances toward the selected hub."
	match intent:
		"route":
			var blocked := _route_block_message(placement)
			if blocked != "":
				return "Route is gated: satisfy the listed condition before using Space."
			return "Space travels to the linked map."
		"combat":
			return "Space starts combat; prepare skills/items before engaging."
		"event":
			return "Space resolves this event or hazard immediately."
		"door":
			return "Space checks the door; keys/secrets may change passability."
		"reward":
			return "Space collects loot and records it in recent rewards."
		"rest":
			return "Space rests here and applies the authored recovery event."
		"service":
			return "Space opens the NPC/service menu."
		_:
			return "Space interacts with the highlighted object."

func _objective_guide_snapshot() -> Dictionary:
	var quest_state := QuestService.current_quest(current_slot)
	var quest_status := String(quest_state.get("status", "none"))
	var title := "Explore"
	var detail := "Map unknowns, read nearby markers, and push toward open routes."
	var tone := "neutral"
	if quest_status == "accepted":
		title = "Quest Target"
		var target_monster_id := String(quest_state.get("targetMonsterId", ""))
		var monster_def := ContentRegistry.get_definition("monsters", target_monster_id)
		detail = "Find and defeat %s. Quest targets are marked on the minimap when visible." % String(monster_def.get("name", target_monster_id))
		tone = "danger"
	elif quest_status == "complete_ready":
		title = "Turn In Reward"
		detail = "Return to a quest board or eligible NPC service to claim the completed quest reward."
		tone = "reward"
	for route in _route_state_entries():
		if typeof(route) != TYPE_DICTIONARY:
			continue
		if not bool(route.get("blocked", false)):
			continue
		var blocked_message := String(route.get("blockedMessage", ""))
		if blocked_message != "":
			detail += "\nGate: %s" % blocked_message
			break
	var active_seeds: Array[String] = []
	var quest_seeds := QuestService.quest_seed_states(current_slot)
	for seed_id in quest_seeds.keys():
		var state: Dictionary = quest_seeds.get(seed_id, {})
		if String(state.get("status", "")) == "active":
			active_seeds.append(String(state.get("title", seed_id)))
	if not active_seeds.is_empty():
		title = "Quest Seed"
		detail += "\nSeed: %s" % ", ".join(active_seeds)
		tone = "reward" if quest_status == "complete_ready" else "neutral"
	return {
		"title": title,
		"detail": detail,
		"tone": tone
	}

func _interaction_intent_label(placement: Dictionary, source: String, distance: int) -> String:
	var kind := String(placement.get("type", ""))
	if source == "selected" and distance > 1:
		return "approach"
	match kind:
		"gate", "stairs":
			return "route"
		"field_monster":
			return "combat"
		"event", "trap":
			return "event"
		"locked_door", "secret_door":
			return "door"
		"npc_service", "quest_board", "healer", "skill_shop", "trade":
			return "service"
		"loot":
			return "reward"
		"rest":
			return "rest"
		_:
			return "interact"

func _route_affordance_detail(placement: Dictionary, blocked_message: String) -> String:
	var target_route := String(placement.get("targetRoute", ""))
	var target_map_id := String(placement.get("targetMapId", ""))
	var lines: Array[String] = []
	if blocked_message != "":
		lines.append("[color=#d89a6d]%s[/color]" % blocked_message)
	else:
		lines.append("[color=#9fd6a5]열림[/color] 다음 지역으로 이동한다.")
	if target_route != "" or target_map_id != "":
		lines.append("목적지: %s / %s" % [target_route, target_map_id])
	var required_flag := String(placement.get("requiredFlag", ""))
	if required_flag != "":
		lines.append("필요 flag: %s" % required_flag)
	var required_seed_id := String(placement.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		lines.append("필요 quest seed: %s = %s" % [required_seed_id, String(placement.get("requiredQuestSeedStatus", "rewarded"))])
	return "\n".join(lines)

func _field_monster_affordance_detail(placement: Dictionary) -> String:
	var monster_id := String(placement.get("monsterId", placement.get("id", "")))
	var monster_def := ContentRegistry.get_definition("monsters", monster_id)
	var ai := _field_ai_config(placement)
	var profile: Dictionary = monster_def.get("combatProfile", {})
	var lines := [
		"전방 몬스터와 즉시 전투를 시작한다.",
		"대상: %s / encounter %s" % [String(monster_def.get("name", monster_id)), String(placement.get("encounterId", ""))],
		"AI: %s alert=%s faction=%s" % [String(ai.get("behavior", "guard")), String(ai.get("alertGroup", "")), String(ai.get("faction", ""))]
	]
	if not profile.is_empty():
		lines.append("전투 성향: %s" % String(profile.get("behavior", profile.get("role", "profile"))))
	return "\n".join(lines)

func _event_affordance_detail(placement: Dictionary) -> String:
	var event_id := String(placement.get("eventId", ""))
	var event_def := ContentRegistry.get_definition("events", event_id)
	var entry_step := String(event_def.get("entryStepId", ""))
	var effect_count := int(event_def.get("effects", []).size())
	var step_count := int(event_def.get("steps", []).size())
	return "이벤트 정의와 분기를 실행한다.\n%s / entry %s / steps %d / effects %d" % [
		String(event_def.get("name", event_id)),
		entry_step if entry_step != "" else "direct",
		step_count,
		effect_count
	]

func _door_affordance_detail(placement: Dictionary) -> String:
	var key_item := String(placement.get("keyItemId", ""))
	var has_key := key_item != "" and SaveService.inventory(current_slot).has(key_item)
	if key_item == "":
		return "잠금 상태와 차단 이유를 확인한다."
	return "잠긴 통로다.\n필요 열쇠: %s / 보유 %s" % [key_item, "yes" if has_key else "no"]

func _secret_affordance_detail(placement: Dictionary) -> String:
	var contains_item := String(placement.get("containsItemId", ""))
	if contains_item != "":
		return "발견된 경우 통로와 보상이 열린다.\n단서 보상: %s" % contains_item
	return "발견된 경우에만 통로가 열린다."

func _loot_affordance_detail(placement: Dictionary) -> String:
	var loot_table_id := String(placement.get("lootTableId", ""))
	var item_id := String(placement.get("itemId", ""))
	var parts: Array[String] = ["획득 가능한 보상이나 아이템을 챙긴다."]
	if loot_table_id != "":
		parts.append("loot table: %s" % loot_table_id)
	if item_id != "":
		parts.append("fallback item: %s" % item_id)
	return "\n".join(parts)

func _trap_affordance_detail(placement: Dictionary) -> String:
	var event_id := String(placement.get("eventId", ""))
	var event_def := ContentRegistry.get_definition("events", event_id)
	var detection: Dictionary = event_def.get("detection", {})
	var disarm: Dictionary = event_def.get("disarm", {})
	var lines: Array[String] = ["주의하지 않으면 즉시 효과가 발동한다."]
	if not detection.is_empty():
		lines.append("탐지: %s DC %d" % [String(detection.get("check", "")), int(detection.get("difficulty", 0))])
	if not disarm.is_empty():
		lines.append("해제: %s DC %d" % [String(disarm.get("check", "")), int(disarm.get("difficulty", 0))])
	return "\n".join(lines)

func _interaction_prompt_text() -> String:
	var interaction := _interaction_snapshot()
	if not bool(interaction.get("available", false)):
		return String(interaction.get("title", ""))
	var suffix := String(interaction.get("action", ""))
	var hint := String(interaction.get("hint", ""))
	if hint != "":
		suffix += " / %s" % hint
	return "%s - %s" % [String(interaction.get("title", "")), suffix]

func _refresh_interaction_focus() -> void:
	var interaction := _interaction_snapshot()
	var focus_id := String(interaction.get("id", ""))
	var selected_id := _selected_town_focus_id()
	for placement in map_data.get("placements", []):
		var placement_id := String(placement.get("id", ""))
		var node: MeshInstance3D = placement_nodes.get(placement_id)
		var ring: MeshInstance3D = placement_rings.get(placement_id)
		var intent_node: MeshInstance3D = placement_intent_nodes.get(placement_id)
		var is_front := placement_id != "" and placement_id == focus_id
		var is_selected := placement_id != "" and placement_id == selected_id
		var color := _placement_runtime_color(placement)
		if node and is_instance_valid(node):
			if is_front:
				node.scale = _dungeon_marker_scale(String(placement.get("type", ""))) * 1.28 if not _is_town_map() else Vector3.ONE * 0.52
				node.position.y = _dungeon_marker_height(String(placement.get("type", ""))) + 0.08 if not _is_town_map() else 0.28
				node.material_override = _marker_material(color.lightened(0.22))
			elif is_selected:
				node.scale = Vector3.ONE * 0.44
				node.position.y = 0.24
				node.material_override = _marker_material(color.lightened(0.12))
			else:
				node.scale = _dungeon_marker_scale(String(placement.get("type", ""))) if not _is_town_map() else Vector3.ONE * 0.35
				node.position.y = _dungeon_marker_height(String(placement.get("type", ""))) if not _is_town_map() else 0.2
				node.material_override = _marker_material(color)
		if ring and is_instance_valid(ring):
			if is_front:
				ring.scale = Vector3.ONE * 1.18
				ring.material_override = _flat_color_material(color.lightened(0.18))
			elif is_selected:
				ring.scale = Vector3.ONE * 1.1
				ring.material_override = _flat_color_material(color.lightened(0.08))
			else:
				ring.scale = Vector3.ONE
				ring.material_override = _flat_color_material(color.darkened(0.2))
		if intent_node and is_instance_valid(intent_node):
			intent_node.visible = is_front or _dungeon_marker_always_shows_intent(placement)
			intent_node.material_override = _marker_material(color.lightened(0.38 if is_front else 0.1))
	if dungeon_focus_node and is_instance_valid(dungeon_focus_node):
		dungeon_focus_node.visible = focus_id != "" and not _is_town_map()
		if dungeon_focus_node.visible:
			var focus_placement := _placement_by_id(focus_id)
			var focus_cell := _placement_runtime_cell(focus_placement) if not focus_placement.is_empty() else player_cell
			dungeon_focus_node.position = Vector3(focus_cell.x, 0.09, focus_cell.y)
			dungeon_focus_node.scale = Vector3.ONE * (1.4 if bool(interaction.get("blocked", false)) else 1.15)
	_update_dungeon_focus_path(interaction)
	_update_town_focus_anchor(selected_id)

func _dungeon_marker_always_shows_intent(placement: Dictionary) -> bool:
	var kind := String(placement.get("type", ""))
	if kind in ["gate", "stairs"] and _route_block_message(placement) != "":
		return true
	var pos := _placement_runtime_cell(placement)
	var key := "%d,%d" % [pos.x, pos.y]
	if _quest_target_keys().has(key) or _quest_turn_in_keys().has(key) or _quest_seed_objective_keys().has(key):
		return true
	return kind in ["trap", "field_monster"]

func _placement_by_id(placement_id: String) -> Dictionary:
	for placement in map_data.get("placements", []):
		if typeof(placement) == TYPE_DICTIONARY and String(placement.get("id", "")) == placement_id:
			return placement
	return {}

func _animate_dungeon_affordances() -> void:
	if dungeon_affordance_presenter != null:
		dungeon_affordance_presenter.call("animate_affordances")

func _interaction_alignment_hint(placement: Dictionary, source: String, distance: int) -> String:
	if town_focus_runtime == null:
		return ""
	return String(town_focus_runtime.call("alignment_hint", placement, source, distance))

func _town_focus_direction_hint(placement: Dictionary, distance: int) -> String:
	if town_focus_runtime == null:
		return ""
	return String(town_focus_runtime.call("direction_hint", placement, distance))

func _refresh_town_focus_targets() -> void:
	if town_focus_runtime != null:
		town_focus_runtime.call("refresh_targets")

func _town_focus_direction_score(cell: Vector2i) -> int:
	if town_focus_runtime == null:
		return 4
	return int(town_focus_runtime.call("_direction_score", cell))

func _cycle_town_focus(step: int) -> void:
	if town_focus_runtime != null:
		town_focus_runtime.call("cycle_focus", step)

func _town_focus_summary(active_placement: Dictionary, source: String) -> String:
	if town_focus_runtime == null:
		return ""
	return String(town_focus_runtime.call("focus_summary", active_placement, source))

func _town_anchor_snapshot(placement: Dictionary, source: String) -> Array:
	if town_focus_runtime == null:
		return []
	return town_focus_runtime.call("anchor_snapshot", placement, source)

func _orient_toward_town_focus(placement: Dictionary) -> void:
	if town_focus_runtime != null:
		town_focus_runtime.call("orient_toward", placement)

func _town_focus_snapshot() -> Dictionary:
	if town_focus_runtime == null:
		return {}
	return town_focus_runtime.call("focus_snapshot")

func _selected_town_focus_id() -> String:
	if town_focus_runtime == null:
		return ""
	return String(town_focus_runtime.call("selected_id"))

func _clear_dungeon_focus_path_nodes() -> void:
	if dungeon_affordance_presenter != null:
		dungeon_affordance_presenter.call("clear_focus_path")

func _update_town_focus_anchor(selected_id: String) -> void:
	if _is_town_map() and town_world_presenter != null:
		town_world_presenter.call("update_focus_visuals", selected_id)

func _animate_town_focus_anchor(_delta: float) -> void:
	if town_world_presenter != null:
		town_world_presenter.call("animate_focus_anchor")

func _update_dungeon_focus_path(interaction: Dictionary) -> void:
	_clear_dungeon_focus_path_nodes()
	if _is_town_map() or dungeon_affordance_presenter == null or not bool(interaction.get("available", false)):
		return
	var focus_id := String(interaction.get("id", ""))
	if focus_id == "":
		return
	var placement := _placement_by_id(focus_id)
	if placement.is_empty():
		return
	var target := _placement_runtime_cell(placement)
	var path := _dungeon_path_to_cell(target)
	dungeon_affordance_presenter.call("spawn_focus_path", path, placement, interaction)

func _dungeon_path_to_cell(target: Vector2i) -> Array[Vector2i]:
	if target == player_cell:
		return [player_cell]
	var queue: Array[Vector2i] = [player_cell]
	var came_from := {player_cell: player_cell}
	var found := false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == target:
			found = true
			break
		for dir in DIRS:
			var candidate: Vector2i = current + dir
			if came_from.has(candidate):
				continue
			if candidate != target and _cell_hard_blocked(candidate):
				continue
			came_from[candidate] = current
			queue.append(candidate)
	if not found:
		return [player_cell]
	var reversed_path: Array[Vector2i] = [target]
	var step: Vector2i = target
	while step != player_cell:
		step = came_from.get(step, player_cell)
		reversed_path.append(step)
	reversed_path.reverse()
	return reversed_path

func _town_path_to_anchor(anchor: Vector2i) -> Array[Vector2i]:
	if town_focus_runtime == null:
		return [player_cell]
	return town_focus_runtime.call("path_to_anchor", anchor)

func _town_service_preview(placement: Dictionary) -> String:
	if town_focus_runtime == null:
		return ""
	return String(town_focus_runtime.call("service_preview", placement, current_slot))

func _route_from_placement(placement: Dictionary) -> void:
	var blocked_message := _route_block_message(placement)
	if blocked_message != "":
		_log(blocked_message)
		return
	if _should_mark_campaign_clear(placement):
		SaveService.mark_campaign_clear(
			current_slot,
			_resolved_campaign_clear_title(placement),
			String(map_data.get("id", default_map_id))
		)
	var target_route := String(placement.get("targetRoute", "town"))
	var target_map_id := String(placement.get("targetMapId", "town_square"))
	GameApp.current_mode = target_route
	SceneRouter.change_route(target_route, {
		"slot": current_slot,
		"map_id": target_map_id,
		"dungeon_source": dungeon_source_mode
	})

func _route_block_message(placement: Dictionary) -> String:
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var required_flag := String(placement.get("requiredFlag", ""))
	if required_flag != "" and not bool(slot_data.get("flags", {}).get(required_flag, false)):
		return String(placement.get("blockedMessage", "The route is still sealed."))
	var required_bosses := int(placement.get("bossesDefeatedAtLeast", 0))
	if required_bosses > 0 and QuestService.progression_bosses_defeated(current_slot) < required_bosses:
		return String(placement.get("blockedMessage", "Requires progression %d." % required_bosses))
	var required_quest_statuses: Array = placement.get("requiredQuestStatuses", [])
	if not required_quest_statuses.is_empty():
		var quest_status := String(QuestService.current_quest(current_slot).get("status", "none"))
		if not required_quest_statuses.has(quest_status):
			return String(placement.get("blockedMessage", "The route is still sealed."))
	var required_seed_id := String(placement.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		var required_seed_status := String(placement.get("requiredQuestSeedStatus", "rewarded"))
		var seed_status := String(QuestService.quest_seed_states(current_slot).get(required_seed_id, {}).get("status", ""))
		if seed_status != required_seed_status:
			return String(placement.get("blockedMessage", "The route is still sealed."))
	return ""

func _should_mark_campaign_clear(placement: Dictionary) -> bool:
	if String(placement.get("endingFlag", "")).strip_edges() != "":
		return true
	if String(map_data.get("id", "")) != "dungeon_floor_03":
		return false
	if String(placement.get("targetRoute", "")) != GameApp.MODE_TOWN:
		return false
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	return bool(slot_data.get("flags", {}).get("blind_priest_cleared", false))

func _resolved_campaign_clear_title(placement: Dictionary) -> String:
	var title := String(placement.get("endingTitle", ""))
	if title != "":
		return title
	if String(map_data.get("id", "")) == "dungeon_floor_03":
		return "Blind Priest Defeated"
	return "Expedition Cleared"

func _enter_combat(placement: Dictionary) -> void:
	GameApp.enter_combat({
		"slot": current_slot,
		"monster_instance_id": String(placement.get("id", "")),
		"monster_id": String(placement.get("monsterId", placement.get("id", ""))),
		"monster_name": String(placement.get("label", "Field Monster")),
		"return_route": route_name,
		"return_map_id": String(map_data.get("id", default_map_id))
	})

func _persist_runtime() -> void:
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var visited_cells: Dictionary = runtime.get("visitedCells", {})
	runtime["mapId"] = String(map_data.get("id", default_map_id))
	runtime["dungeonSource"] = dungeon_source_mode
	runtime["playerCell"] = [player_cell.x, player_cell.y]
	runtime["facing"] = facing
	runtime["log"] = log_lines
	visited_cells[_cell_visit_key(player_cell)] = true
	runtime["visitedCells"] = visited_cells
	SaveService.update_runtime(current_slot, runtime, route_name)

func _ensure_field_monster_runtime() -> void:
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	if slot_data.is_empty():
		return
	var runtime: Dictionary = slot_data.get("runtime", {})
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	var changed := false
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		var pos: Array = placement.get("position", [0, 0])
		var start_cell := [int(pos[0]), int(pos[1])]
		var state: Dictionary = field_monsters.get(placement_id, {})
		if not state.has("startCell"):
			state["startCell"] = start_cell
			changed = true
		if not state.has("currentCell"):
			state["currentCell"] = start_cell
			changed = true
		if String(state.get("aiState", "")).strip_edges() == "":
			var behavior := _field_ai_behavior(placement)
			if behavior == "patrol":
				state["aiState"] = "patrolling"
			elif behavior == "ambush":
				state["aiState"] = "ambushing"
			else:
				state["aiState"] = "idle"
			changed = true
		if String(state.get("monsterId", "")).strip_edges() == "":
			state["monsterId"] = String(placement.get("monsterId", placement_id))
			changed = true
		if not state.has("patrolIndex"):
			state["patrolIndex"] = 0
			changed = true
		if not state.has("warningCounter"):
			state["warningCounter"] = 0
			changed = true
		if not state.has("lostSightCounter"):
			state["lostSightCounter"] = 0
			changed = true
		if not state.has("lastKnownPlayerCell"):
			state["lastKnownPlayerCell"] = start_cell
			changed = true
		if not state.has("revealed"):
			state["revealed"] = _field_ai_behavior(placement) != "ambush"
			changed = true
		field_monsters[placement_id] = state
	runtime["fieldMonsters"] = field_monsters
	slot_data["runtime"] = runtime
	if changed:
		SaveService.save_slot(current_slot, slot_data)

func _tick_field_monsters() -> Dictionary:
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	if slot_data.is_empty():
		return {}
	var runtime: Dictionary = slot_data.get("runtime", {})
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	var occupied := {}
	var pending_combat: Dictionary = {}
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		var state: Dictionary = field_monsters.get(placement_id, {})
		if bool(state.get("defeated", false)):
			continue
		var current := _state_cell(state, "currentCell", placement)
		occupied["%d,%d" % [current.x, current.y]] = placement_id
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		var state: Dictionary = field_monsters.get(placement_id, {})
		if bool(state.get("defeated", false)):
			continue
		var current := _state_cell(state, "currentCell", placement)
		var start := _state_cell(state, "startCell", placement)
		var field_ai := _field_ai_config(placement)
		var chase_range := maxi(int(field_ai.get("chaseRange", 2)), 0)
		var approach_range := maxi(int(field_ai.get("approachRange", 4)), chase_range)
		var hearing_range := maxi(int(field_ai.get("hearingRange", 1)), 0)
		var leash_range := maxi(int(field_ai.get("leashRange", 5)), approach_range)
		var distance: int = abs(current.x - player_cell.x) + abs(current.y - player_cell.y)
		var leash_distance: int = abs(start.x - player_cell.x) + abs(start.y - player_cell.y)
		var next_state := String(state.get("aiState", "idle"))
		var previous_state := next_state
		var behavior := _field_ai_behavior(placement)
		var revealed := bool(state.get("revealed", behavior != "ambush"))
		var warning_turns := int(field_ai.get("warningTurns", 0))
		var wake_range := maxi(int(field_ai.get("wakeRange", 0)), 0)
		var lose_sight_turns := maxi(int(field_ai.get("loseSightTurns", 1)), 0)
		var warning_counter := int(state.get("warningCounter", 0))
		var lost_sight_counter := maxi(int(state.get("lostSightCounter", 0)), 0)
		var patrol_route := _field_patrol_route(placement)
		var last_known := _state_cell(state, "lastKnownPlayerCell", placement)
		var player_visible := _has_cardinal_line_of_sight(current, player_cell)
		var player_heard := distance <= hearing_range
		var player_detected := leash_distance <= leash_range and ((player_visible and distance <= approach_range) or player_heard)
		if warning_counter < 0:
			warning_counter = 0
		if player_detected:
			last_known = player_cell
			lost_sight_counter = 0
		if behavior == "ambush" and not revealed:
			if (player_visible or player_heard) and distance <= chase_range:
				revealed = true
				next_state = "chasing"
				warning_counter = 0
			elif leash_distance <= leash_range and ((player_visible and distance <= wake_range) or player_heard):
				revealed = true
				if warning_turns > 0:
					next_state = "warning"
					warning_counter = warning_turns
				else:
					next_state = "approaching"
					warning_counter = 0
			else:
				next_state = "ambushing"
				warning_counter = 0
		elif player_detected and distance <= chase_range:
			next_state = "chasing"
			warning_counter = 0
		elif player_detected:
			if warning_turns > 0 and next_state not in ["warning", "approaching", "chasing"]:
				next_state = "warning"
				warning_counter = warning_turns
			elif next_state == "warning" and warning_counter > 1:
				next_state = "warning"
				warning_counter -= 1
			else:
				next_state = "approaching"
				warning_counter = 0
		elif next_state in ["warning", "approaching", "chasing", "giving_up"]:
			if current != last_known and lost_sight_counter <= lose_sight_turns:
				next_state = "giving_up"
				lost_sight_counter += 1
				warning_counter = 0
			elif current != start:
				next_state = "returning"
				warning_counter = 0
			elif behavior == "patrol" and patrol_route.size() > 1:
				next_state = "patrolling"
				lost_sight_counter = 0
			elif behavior == "ambush":
				next_state = "ambushing"
				revealed = false
				lost_sight_counter = 0
			else:
				next_state = "idle"
				lost_sight_counter = 0
		elif current != start:
			next_state = "returning"
			warning_counter = 0
		elif behavior == "patrol" and patrol_route.size() > 1:
			next_state = "patrolling"
			warning_counter = 0
		else:
			next_state = "idle"
			warning_counter = 0
		var goal := start
		if next_state in ["approaching", "chasing"]:
			goal = player_cell
		elif next_state == "giving_up":
			goal = last_known
		elif next_state == "patrolling":
			goal = _field_patrol_target(state, placement)
		var moved := current
		if next_state not in ["idle", "warning", "ambushing"]:
			moved = _step_monster_toward(current, goal, occupied, placement_id)
		if next_state == "giving_up" and moved == goal:
			next_state = "returning" if moved != start else ("ambushing" if behavior == "ambush" else ("patrolling" if behavior == "patrol" and patrol_route.size() > 1 else "idle"))
			if next_state == "ambushing":
				revealed = false
			lost_sight_counter = 0
		if next_state == "returning" and moved == start:
			if behavior == "patrol" and patrol_route.size() > 1:
				next_state = "patrolling"
			elif behavior == "ambush":
				next_state = "ambushing"
				revealed = false
			else:
				next_state = "idle"
			lost_sight_counter = 0
		if next_state == "patrolling":
			var patrol_index := int(state.get("patrolIndex", 0))
			if moved == goal and patrol_route.size() > 1:
				patrol_index = posmod(patrol_index + 1, patrol_route.size())
			state["patrolIndex"] = patrol_index
		occupied.erase("%d,%d" % [current.x, current.y])
		occupied["%d,%d" % [moved.x, moved.y]] = placement_id
		state["currentCell"] = [moved.x, moved.y]
		state["aiState"] = next_state
		state["warningCounter"] = warning_counter
		state["lostSightCounter"] = lost_sight_counter
		state["lastKnownPlayerCell"] = [last_known.x, last_known.y]
		state["revealed"] = revealed
		state["updatedAt"] = Time.get_datetime_string_from_system()
		field_monsters[placement_id] = state
		if next_state in ["warning", "approaching", "chasing"] and previous_state not in ["warning", "approaching", "chasing"]:
			_broadcast_field_alert(placement, field_monsters)
		if pending_combat.is_empty() and revealed and next_state in ["approaching", "chasing"] and _field_monster_should_auto_engage(moved, placement):
			pending_combat = placement
	runtime["fieldMonsters"] = field_monsters
	slot_data["runtime"] = runtime
	SaveService.save_slot(current_slot, slot_data)
	_refresh_field_monsters()
	return pending_combat

func _step_monster_toward(current: Vector2i, goal: Vector2i, occupied: Dictionary, placement_id: String) -> Vector2i:
	var routed_step := _monster_path_next_step(current, goal, occupied, placement_id)
	if routed_step != current:
		return routed_step
	var candidates: Array[Vector2i] = []
	var delta := goal - current
	if abs(delta.x) >= abs(delta.y):
		candidates.append(current + Vector2i(sign(delta.x), 0))
		candidates.append(current + Vector2i(0, sign(delta.y)))
	else:
		candidates.append(current + Vector2i(0, sign(delta.y)))
		candidates.append(current + Vector2i(sign(delta.x), 0))
	for candidate in candidates:
		if candidate == current:
			continue
		if candidate == player_cell:
			continue
		if _cell_hard_blocked(candidate):
			continue
		var key := "%d,%d" % [candidate.x, candidate.y]
		if occupied.has(key) and String(occupied.get(key, "")) != placement_id:
			continue
		return candidate
	return current

func _monster_path_next_step(current: Vector2i, goal: Vector2i, occupied: Dictionary, placement_id: String) -> Vector2i:
	if current == goal:
		return current
	var queue: Array[Vector2i] = [current]
	var came_from := {"%d,%d" % [current.x, current.y]: current}
	var found := false
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			found = true
			break
		for dir in DIRS:
			var candidate: Vector2i = cell + dir
			var key := "%d,%d" % [candidate.x, candidate.y]
			if came_from.has(key):
				continue
			if candidate != goal and candidate == player_cell:
				continue
			if _cell_hard_blocked(candidate):
				continue
			if occupied.has(key) and String(occupied.get(key, "")) != placement_id:
				continue
			came_from[key] = cell
			queue.append(candidate)
	if not found:
		return current
	var step := goal
	while came_from.has("%d,%d" % [step.x, step.y]):
		var previous: Vector2i = came_from["%d,%d" % [step.x, step.y]]
		if previous == current:
			return step
		if previous == step:
			break
		step = previous
	return current

func _cell_hard_blocked(cell: Vector2i) -> bool:
	var cells: Array = map_data.get("cells", [])
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := String(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	if row[cell.x] == "#":
		return true
	for placement in map_data.get("placements", []):
		var placement_type := String(placement.get("type", ""))
		if placement_type == "field_monster":
			continue
		if _placement_runtime_cell(placement) != cell:
			continue
		if placement_type == "locked_door" and bool(placement.get("blocking", false)):
			var slot_data: Dictionary = SaveService.load_slot(current_slot)
			var runtime: Dictionary = slot_data.get("runtime", {})
			var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
			if not bool(unlocked_doors.get(String(placement.get("id", "")), false)):
				return true
		if placement_type == "secret_door":
			var slot_data: Dictionary = SaveService.load_slot(current_slot)
			var runtime: Dictionary = slot_data.get("runtime", {})
			var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
			if not bool(discovered_secrets.get(String(placement.get("id", "")), false)):
				return true
	return false

func _cell_blocks_vision(cell: Vector2i) -> bool:
	var cells: Array = map_data.get("cells", [])
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := String(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	if row[cell.x] == "#":
		return true
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
	var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
	for placement in map_data.get("placements", []):
		var placement_type := String(placement.get("type", ""))
		if placement_type not in ["locked_door", "secret_door"]:
			continue
		var pos := _placement_runtime_cell(placement, runtime)
		if pos != cell:
			continue
		if placement_type == "locked_door" and bool(placement.get("blocking", false)):
			if not bool(unlocked_doors.get(String(placement.get("id", "")), false)):
				return true
		elif placement_type == "secret_door":
			if not bool(discovered_secrets.get(String(placement.get("id", "")), false)):
				return true
	return false

func _placement_runtime_cell(placement: Dictionary, runtime: Dictionary = {}) -> Vector2i:
	if runtime.is_empty():
		runtime = SaveService.load_slot(current_slot).get("runtime", {})
	if String(placement.get("type", "")) == "field_monster":
		var state: Dictionary = runtime.get("fieldMonsters", {}).get(String(placement.get("id", "")), {})
		return _state_cell(state, "currentCell", placement)
	var pos: Array = placement.get("position", [0, 0])
	return Vector2i(int(pos[0]), int(pos[1]))

func _field_ai_config(placement: Dictionary) -> Dictionary:
	var field_ai: Dictionary = placement.get("fieldAi", {})
	var patrol_points: Array = []
	for point_variant in field_ai.get("patrolPoints", []):
		if typeof(point_variant) != TYPE_ARRAY:
			continue
		var point: Array = point_variant
		if point.size() != 2:
			continue
		patrol_points.append([int(point[0]), int(point[1])])
	return {
		"behavior": _field_ai_behavior(placement),
		"approachRange": maxi(int(field_ai.get("approachRange", 4)), 0),
		"chaseRange": maxi(int(field_ai.get("chaseRange", 2)), 0),
		"hearingRange": maxi(int(field_ai.get("hearingRange", 1)), 0),
		"leashRange": maxi(int(field_ai.get("leashRange", 5)), 0),
		"wakeRange": maxi(int(field_ai.get("wakeRange", 0)), 0),
		"loseSightTurns": maxi(int(field_ai.get("loseSightTurns", 1)), 0),
		"alertGroup": String(field_ai.get("alertGroup", "")),
		"alertRadius": maxi(int(field_ai.get("alertRadius", 0)), 0),
		"warningTurns": maxi(int(field_ai.get("warningTurns", 0)), 0),
		"patrolPoints": patrol_points
	}

func _has_cardinal_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if from.x != to.x and from.y != to.y:
		return false
	if from == to:
		return true
	if from.x == to.x:
		var step_y := 1 if to.y > from.y else -1
		for y in range(from.y + step_y, to.y, step_y):
			if _cell_blocks_vision(Vector2i(from.x, y)):
				return false
		return true
	var step_x := 1 if to.x > from.x else -1
	for x in range(from.x + step_x, to.x, step_x):
		if _cell_blocks_vision(Vector2i(x, from.y)):
			return false
	return true

func _field_alert_group_id(placement: Dictionary) -> String:
	var config := _field_ai_config(placement)
	var explicit_group := String(config.get("alertGroup", ""))
	if explicit_group != "":
		return explicit_group
	return String(placement.get("encounterId", ""))

func _broadcast_field_alert(source_placement: Dictionary, field_monsters: Dictionary) -> void:
	var group_id := _field_alert_group_id(source_placement)
	if group_id == "":
		return
	var source_cell := _placement_runtime_cell(source_placement, {"fieldMonsters": field_monsters})
	var source_radius := int(_field_ai_config(source_placement).get("alertRadius", 0))
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		if placement_id == String(source_placement.get("id", "")):
			continue
		if _field_alert_group_id(placement) != group_id:
			continue
		var state: Dictionary = field_monsters.get(placement_id, {}).duplicate(true)
		if state.is_empty() or bool(state.get("defeated", false)):
			continue
		var ally_cell := _state_cell(state, "currentCell", placement)
		var ally_radius := int(_field_ai_config(placement).get("alertRadius", 0))
		var effective_radius := maxi(source_radius, ally_radius)
		if effective_radius > 0 and abs(source_cell.x - ally_cell.x) + abs(source_cell.y - ally_cell.y) > effective_radius:
			continue
		var ai_state := String(state.get("aiState", "idle"))
		if ai_state in ["warning", "approaching", "chasing", "combat"]:
			continue
		var behavior := _field_ai_behavior(placement)
		if behavior == "ambush":
			state["revealed"] = true
		var ally_config := _field_ai_config(placement)
		var warning_turns := int(ally_config.get("warningTurns", 0))
		state["aiState"] = "warning" if warning_turns > 0 else "approaching"
		state["warningCounter"] = warning_turns
		state["lostSightCounter"] = 0
		state["lastKnownPlayerCell"] = [player_cell.x, player_cell.y]
		state["updatedAt"] = Time.get_datetime_string_from_system()
		field_monsters[placement_id] = state

func _field_ai_behavior(placement: Dictionary) -> String:
	var field_ai: Dictionary = placement.get("fieldAi", {})
	var behavior := String(field_ai.get("behavior", "guard"))
	return behavior if behavior in ["guard", "patrol", "ambush"] else "guard"

func _field_patrol_route(placement: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var base_cell := _state_cell({}, "currentCell", placement)
	result.append(base_cell)
	for point in _field_ai_config(placement).get("patrolPoints", []):
		if typeof(point) != TYPE_ARRAY:
			continue
		var point_array: Array = point
		if point_array.size() != 2:
			continue
		var patrol_cell := Vector2i(int(point_array[0]), int(point_array[1]))
		if patrol_cell not in result:
			result.append(patrol_cell)
	return result

func _field_patrol_target(state: Dictionary, placement: Dictionary) -> Vector2i:
	var route := _field_patrol_route(placement)
	if route.is_empty():
		return _state_cell(state, "startCell", placement)
	var index := clampi(int(state.get("patrolIndex", 0)), 0, route.size() - 1)
	return route[index]

func _field_monster_should_auto_engage(monster_cell: Vector2i, placement: Dictionary) -> bool:
	if not bool(placement.get("blocking", false)):
		return false
	return abs(monster_cell.x - player_cell.x) + abs(monster_cell.y - player_cell.y) <= 1

func _field_monster_marker_color(state: Dictionary) -> Color:
	match String(state.get("aiState", "idle")):
		"ambushing":
			return Color("6f5a8e")
		"warning":
			return Color("d8a84e")
		"approaching":
			return Color("d47f4a")
		"chasing":
			return Color("d04f4f")
		"returning":
			return Color("8f79c9")
		"giving_up":
			return Color("8d6767")
		"patrolling":
			return Color("c25ac2")
		_:
			return Color("d04f4f")

func _state_cell(state: Dictionary, key: String, placement: Dictionary) -> Vector2i:
	var fallback: Array = placement.get("position", [0, 0])
	var raw: Array = state.get(key, fallback)
	return Vector2i(int(raw[0]), int(raw[1]))

func _log(message: String) -> void:
	log_lines.append(message)
	_persist_runtime()

func _cell_visit_key(cell: Vector2i) -> String:
	return "%s:%d,%d" % [String(map_data.get("id", default_map_id)), cell.x, cell.y]

func _visited_keys_for_map(runtime: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var visited_cells: Dictionary = runtime.get("visitedCells", {})
	var prefix := "%s:" % String(map_data.get("id", default_map_id))
	for key in visited_cells.keys():
		var cell_key := String(key)
		if cell_key.begins_with(prefix) and bool(visited_cells.get(key, false)):
			result.append(cell_key.substr(prefix.length()))
	return result

func _visible_minimap_placements(runtime: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
	var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
	var claimed_loot: Dictionary = runtime.get("claimedLoot", {})
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var placement_id := String(placement.get("id", ""))
		var placement_type := String(placement.get("type", ""))
		if placement_type == "field_monster":
			var field_state: Dictionary = field_monsters.get(placement_id, {})
			if bool(field_state.get("defeated", false)):
				continue
			if _field_ai_behavior(placement) == "ambush" and not bool(field_state.get("revealed", false)):
				continue
		if placement_type == "secret_door" and not bool(discovered_secrets.get(placement_id, false)):
			continue
		if placement_type == "locked_door" and bool(unlocked_doors.get(placement_id, false)):
			continue
		if placement_type == "loot" and bool(claimed_loot.get(placement_id, false)):
			continue
		var cell := _placement_runtime_cell(placement, runtime)
		var row := {
			"id": placement_id,
			"type": placement_type,
			"position": [cell.x, cell.y]
		}
		if placement_type in ["gate", "stairs"]:
			var blocked_message := _route_block_message(placement)
			row["routeBlocked"] = blocked_message != ""
			row["blockedMessage"] = blocked_message
			row["targetMapId"] = String(placement.get("targetMapId", ""))
			row["targetRoute"] = String(placement.get("targetRoute", ""))
		result.append(row)
	return result

func _route_state_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var placement_type := String(placement.get("type", ""))
		if placement_type not in ["gate", "stairs"]:
			continue
		var pos: Array = placement.get("position", [0, 0])
		var blocked_message := _route_block_message(placement)
		result.append({
			"id": String(placement.get("id", "")),
			"type": placement_type,
			"label": String(placement.get("label", placement.get("id", ""))),
			"position": [int(pos[0]), int(pos[1])],
			"targetMapId": String(placement.get("targetMapId", "")),
			"targetRoute": String(placement.get("targetRoute", "")),
			"blocked": blocked_message != "",
			"blockedMessage": blocked_message
		})
	return result

func _field_monster_snapshot(runtime: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		var state: Dictionary = runtime.get("fieldMonsters", {}).get(placement_id, {})
		var cell := _placement_runtime_cell(placement, runtime)
		result.append({
			"id": placement_id,
			"monsterId": String(state.get("monsterId", placement.get("monsterId", placement_id))),
			"aiState": String(state.get("aiState", "idle")),
			"currentCell": [cell.x, cell.y],
			"startCell": state.get("startCell", placement.get("position", [0, 0])),
			"fieldAi": _field_ai_config(placement),
			"lastKnownPlayerCell": state.get("lastKnownPlayerCell", placement.get("position", [0, 0])),
			"revealed": bool(state.get("revealed", _field_ai_behavior(placement) != "ambush")),
			"defeated": bool(state.get("defeated", false))
		})
	return result

func _field_monster_state_summary(runtime: Dictionary) -> String:
	var rows: Array[String] = []
	for row in _field_monster_snapshot(runtime):
		if bool(row.get("defeated", false)):
			continue
		var cell: Array = row.get("currentCell", [0, 0])
		rows.append("%s:%s@%d,%d" % [
			String(row.get("monsterId", row.get("id", ""))),
			String(row.get("aiState", "idle")),
			int(cell[0]),
			int(cell[1])
		])
	if rows.is_empty():
		return "-"
	return ", ".join(rows)

func _route_summary() -> String:
	var route_entries := _route_state_entries()
	if route_entries.is_empty():
		return "-"
	var labels: Array[String] = []
	for entry in route_entries:
		labels.append("%s:%s" % [
			String(entry.get("label", entry.get("id", ""))),
			"locked" if bool(entry.get("blocked", false)) else "open"
		])
	return ", ".join(labels)

func _quest_target_keys() -> Array[String]:
	var result: Array[String] = []
	var quest_state := QuestService.current_quest(current_slot)
	var quest_status := String(quest_state.get("status", ""))
	if quest_status not in ["accepted", "complete_ready"]:
		return result
	var target_monster_id := String(quest_state.get("targetMonsterId", ""))
	if target_monster_id == "":
		return result
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_monster_id := String(placement.get("monsterId", placement.get("id", "")))
		if placement_monster_id != target_monster_id and String(placement.get("id", "")) != target_monster_id:
			continue
		var pos: Array = placement.get("position", [0, 0])
		result.append("%d,%d" % [int(pos[0]), int(pos[1])])
	return result

func _quest_turn_in_keys() -> Array[String]:
	var result: Array[String] = []
	var quest_state := QuestService.current_quest(current_slot)
	if String(quest_state.get("status", "")) != "complete_ready":
		return result
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var placement_type := String(placement.get("type", ""))
		if placement_type not in ["quest_board", "npc_service"]:
			continue
		var pos: Array = placement.get("position", [0, 0])
		result.append("%d,%d" % [int(pos[0]), int(pos[1])])
	return result

func _quest_seed_objective_keys() -> Array[String]:
	var result: Array[String] = []
	var quest_seeds := QuestService.quest_seed_states(current_slot)
	for quest_seed_id in quest_seeds.keys():
		var state: Dictionary = quest_seeds.get(quest_seed_id, {})
		var status := String(state.get("status", ""))
		if status not in ["active", "completed"]:
			continue
		var npc_id := String(state.get("npcId", ""))
		var seed_def := _find_quest_seed_definition(npc_id, String(quest_seed_id))
		if seed_def.is_empty():
			continue
		if status == "active":
			result.append_array(_placement_keys_for_event(String(seed_def.get("completeEventId", ""))))
		else:
			result.append_array(_placement_keys_for_npc(npc_id))
	return result

func _find_quest_seed_definition(npc_id: String, quest_seed_id: String) -> Dictionary:
	if npc_id == "" or quest_seed_id == "":
		return {}
	var npc_def := ContentRegistry.get_definition("npcs", npc_id)
	for seed_variant in npc_def.get("questSeeds", []):
		if typeof(seed_variant) != TYPE_DICTIONARY:
			continue
		var seed: Dictionary = seed_variant
		if String(seed.get("id", "")) == quest_seed_id:
			return seed
	return {}

func _placement_keys_for_event(event_id: String) -> Array[String]:
	var result: Array[String] = []
	if event_id == "":
		return result
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		if String(placement.get("eventId", "")) != event_id:
			continue
		var pos: Array = placement.get("position", [0, 0])
		result.append("%d,%d" % [int(pos[0]), int(pos[1])])
	return result

func _placement_keys_for_npc(npc_id: String) -> Array[String]:
	var result: Array[String] = []
	if npc_id == "":
		return result
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		if String(placement.get("npcId", "")) != npc_id:
			continue
		var pos: Array = placement.get("position", [0, 0])
		result.append("%d,%d" % [int(pos[0]), int(pos[1])])
	return result

func _open_service_overlay(placement: Dictionary) -> void:
	_close_service_overlay()
	active_overlay = preload("res://scripts/ui/service_overlay.gd").new().configure(
		current_slot,
		placement,
		Callable(self, "_close_service_overlay")
	)
	SceneRouter.modal_layer.add_child(active_overlay)

func _close_service_overlay() -> void:
	if active_overlay != null and is_instance_valid(active_overlay):
		active_overlay.queue_free()
	active_overlay = null

func _toggle_inventory_overlay() -> void:
	if active_overlay != null and is_instance_valid(active_overlay):
		_close_service_overlay()
		return
	active_overlay = preload("res://scripts/ui/inventory_overlay.gd").new().configure(
		current_slot,
		Callable(self, "_close_service_overlay")
	)
	SceneRouter.modal_layer.add_child(active_overlay)

func _trigger_event_placement(placement: Dictionary) -> void:
	var event_id := String(placement.get("eventId", ""))
	var event_def := ContentRegistry.get_definition("events", event_id)
	var result := EventService.apply_event(current_slot, event_id, event_def)
	var messages: Array = result.get("messages", [])
	if messages.is_empty():
		_log("Triggered %s." % placement.get("label", "event"))
	else:
		for message in messages:
			if String(message).strip_edges() != "":
				_log(String(message))

func _try_unlock_door(placement: Dictionary) -> void:
	var key_item := String(placement.get("keyItemId", "rust_key"))
	if not SaveService.has_inventory_item(current_slot, key_item, 1):
		_log("Door is locked. Missing %s." % key_item)
		return
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
	unlocked_doors[String(placement.get("id", ""))] = true
	runtime["unlockedDoors"] = unlocked_doors
	SaveService.update_runtime(current_slot, runtime, route_name)
	_refresh_field_monsters()
	_log("Unlocked %s." % placement.get("label", "door"))

func _discover_secret(placement: Dictionary) -> void:
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var discovered: Dictionary = runtime.get("discoveredSecrets", {})
	if bool(discovered.get(String(placement.get("id", "")), false)):
		_log("Secret already discovered.")
		return
	discovered[String(placement.get("id", ""))] = true
	runtime["discoveredSecrets"] = discovered
	SaveService.update_runtime(current_slot, runtime, route_name)
	var contains_item := String(placement.get("containsItemId", ""))
	if contains_item != "":
		SaveService.add_inventory_item(current_slot, contains_item, 1)
	_log("Discovered secret cache: %s." % placement.get("label", "secret"))
	_refresh_field_monsters()

func _collect_loot(placement: Dictionary) -> void:
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var claimed: Dictionary = runtime.get("claimedLoot", {})
	if bool(claimed.get(String(placement.get("id", "")), false)):
		_log("Loot already claimed.")
		return
	claimed[String(placement.get("id", ""))] = true
	runtime["claimedLoot"] = claimed
	SaveService.update_runtime(current_slot, runtime, route_name)
	var rewards := ContentRegistry.resolve_loot_items(String(placement.get("lootTableId", "")))
	if rewards.is_empty():
		rewards.append({
			"itemId": String(placement.get("itemId", "healing_tonic")),
			"quantity": 1
		})
	for reward in rewards:
		SaveService.add_inventory_item(current_slot, String(reward.get("itemId", "")), int(reward.get("quantity", 1)))
	var reward_summary: Array[String] = []
	for reward in rewards:
		reward_summary.append("%s x%d" % [reward.get("itemId", ""), int(reward.get("quantity", 1))])
	SaveService.append_recent_reward(current_slot, {
		"source": "loot",
		"label": String(placement.get("label", "loot")),
		"items": reward_summary,
		"summary": "Loot %s" % ", ".join(reward_summary)
	})
	_log("Collected %s: %s." % [placement.get("label", "loot"), ", ".join(reward_summary)])
	_refresh_field_monsters()

func _rest_at_placement(placement: Dictionary) -> void:
	var event_def := ContentRegistry.get_definition("events", String(placement.get("eventId", "")))
	var result := EventService.apply_event(current_slot, String(placement.get("eventId", "")), event_def)
	var messages: Array = result.get("messages", [])
	if messages.is_empty():
		_log("Rested at %s." % placement.get("label", "camp"))
	else:
		for message in messages:
			if String(message).strip_edges() != "":
				_log(String(message))

func _trigger_trap(placement: Dictionary) -> void:
	var event_def := ContentRegistry.get_definition("events", String(placement.get("eventId", "")))
	var result := EventService.apply_event(current_slot, String(placement.get("eventId", "")), event_def)
	var messages: Array = result.get("messages", [])
	if messages.is_empty():
		_log("Trap triggered at %s." % placement.get("label", "trap"))
	else:
		for message in messages:
			if String(message).strip_edges() != "":
				_log(String(message))

func _try_rest() -> void:
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) == "rest":
			var pos: Array = placement.get("position", [0, 0])
			if Vector2i(pos[0], pos[1]) == player_cell:
				_rest_at_placement(placement)
				return
	_log("No rest point here.")

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
const INTERACTION_SNAPSHOT_BUILDER_SCRIPT := preload("res://scripts/runtime/interaction_snapshot_builder.gd")
const FIELD_MONSTER_RUNTIME_SCRIPT := preload("res://scripts/runtime/field_monster_runtime.gd")
const DUNGEON_WORLD_PRESENTER_SCRIPT := preload("res://scripts/runtime/dungeon_world_presenter.gd")

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
var map_profile: Dictionary = {}
var object_theme: Dictionary = {}
var compiled_preview: Dictionary = {}
var compiled_runtime_active := false
var dungeon_source_mode := GameApp.DUNGEON_SOURCE_COMPILED
var town_focus_runtime: RefCounted
var town_world_presenter: RefCounted
var dungeon_affordance_presenter: RefCounted
var interaction_snapshot_builder: RefCounted
var field_monster_runtime: RefCounted
var dungeon_world_presenter: RefCounted

@onready var world_root: Node3D = $WorldRoot
@onready var player_rig: Node3D = $PlayerRig3D
@onready var sun: DirectionalLight3D = $Sun

func setup(payload: Dictionary) -> void:
	if payload.is_empty() and allow_editor_test_payload:
		payload = EditorPlaytestBridge.consume_payload(route_name)
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
	town_focus_runtime = TOWN_FOCUS_RUNTIME_SCRIPT.new().configure(self)
	town_world_presenter = TOWN_WORLD_PRESENTER_SCRIPT.new().configure(self)
	dungeon_affordance_presenter = DUNGEON_AFFORDANCE_PRESENTER_SCRIPT.new().configure(self)
	interaction_snapshot_builder = INTERACTION_SNAPSHOT_BUILDER_SCRIPT.new().configure(self)
	field_monster_runtime = FIELD_MONSTER_RUNTIME_SCRIPT.new().configure(self)
	dungeon_world_presenter = DUNGEON_WORLD_PRESENTER_SCRIPT.new().configure(self)
	_ensure_field_monster_runtime()
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

func _build_world() -> void:
	for child in world_root.get_children():
		child.queue_free()
	placement_nodes.clear()
	placement_rings.clear()
	placement_intent_nodes.clear()
	dungeon_focus_node = null
	if town_world_presenter != null:
		town_world_presenter.call("clear")
	if dungeon_world_presenter != null:
		dungeon_world_presenter.call("clear")
	if _is_town_map():
		if town_world_presenter != null:
			town_world_presenter.call("build_world")
		_refresh_field_monsters()
		return
	if dungeon_world_presenter != null:
		dungeon_world_presenter.call("build_world")
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

func _spawn_town_placement_beacon(placement: Dictionary) -> void:
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

func _active_chunk_label() -> String:
	if dungeon_world_presenter != null:
		return String(dungeon_world_presenter.call("active_chunk_label"))
	return "-"

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

func _interaction_snapshot() -> Dictionary:
	if interaction_snapshot_builder == null:
		return {}
	return interaction_snapshot_builder.call("snapshot")

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
	if interaction_snapshot_builder == null:
		return ""
	return String(interaction_snapshot_builder.call("prompt_text"))

func _refresh_interaction_focus() -> void:
	var interaction := _interaction_snapshot()
	var focus_id := String(interaction.get("id", ""))
	var selected_id := String(town_focus_runtime.call("selected_id")) if town_focus_runtime != null else ""
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
	if _is_town_map() and town_world_presenter != null:
		town_world_presenter.call("update_focus_visuals", selected_id)

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

func _refresh_town_focus_targets() -> void:
	if town_focus_runtime != null:
		town_focus_runtime.call("refresh_targets")

func _clear_dungeon_focus_path_nodes() -> void:
	if dungeon_affordance_presenter != null:
		dungeon_affordance_presenter.call("clear_focus_path")

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
	if field_monster_runtime == null:
		return
	field_monster_runtime.call("ensure_runtime")

func _tick_field_monsters() -> Dictionary:
	if field_monster_runtime == null:
		return {}
	return field_monster_runtime.call("tick")

func _step_monster_toward(current: Vector2i, goal: Vector2i, occupied: Dictionary, placement_id: String) -> Vector2i:
	if field_monster_runtime == null:
		return current
	return field_monster_runtime.call("step_monster_toward", current, goal, occupied, placement_id)

func _monster_path_next_step(current: Vector2i, goal: Vector2i, occupied: Dictionary, placement_id: String) -> Vector2i:
	if field_monster_runtime == null:
		return current
	return field_monster_runtime.call("monster_path_next_step", current, goal, occupied, placement_id)

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
	if field_monster_runtime == null:
		return {}
	return field_monster_runtime.call("ai_config", placement)

func _has_cardinal_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if field_monster_runtime == null:
		return false
	return bool(field_monster_runtime.call("has_cardinal_line_of_sight", from, to))

func _field_alert_group_id(placement: Dictionary) -> String:
	if field_monster_runtime == null:
		return ""
	return String(field_monster_runtime.call("alert_group_id", placement))

func _broadcast_field_alert(source_placement: Dictionary, field_monsters: Dictionary) -> void:
	if field_monster_runtime != null:
		field_monster_runtime.call("broadcast_alert", source_placement, field_monsters)

func _field_ai_behavior(placement: Dictionary) -> String:
	if field_monster_runtime == null:
		return "guard"
	return String(field_monster_runtime.call("ai_behavior", placement))

func _field_patrol_route(placement: Dictionary) -> Array[Vector2i]:
	if field_monster_runtime == null:
		return []
	return field_monster_runtime.call("patrol_route", placement)

func _field_patrol_target(state: Dictionary, placement: Dictionary) -> Vector2i:
	if field_monster_runtime == null:
		return _state_cell(state, "startCell", placement)
	return field_monster_runtime.call("patrol_target", state, placement)

func _field_monster_should_auto_engage(monster_cell: Vector2i, placement: Dictionary) -> bool:
	if field_monster_runtime == null:
		return false
	return bool(field_monster_runtime.call("should_auto_engage", monster_cell, placement))

func _field_monster_marker_color(state: Dictionary) -> Color:
	if field_monster_runtime == null:
		return Color("d04f4f")
	return field_monster_runtime.call("marker_color", state)

func _state_cell(state: Dictionary, key: String, placement: Dictionary) -> Vector2i:
	if field_monster_runtime == null:
		var fallback: Array = placement.get("position", [0, 0])
		var raw: Array = state.get(key, fallback)
		return Vector2i(int(raw[0]), int(raw[1]))
	return field_monster_runtime.call("state_cell", state, key, placement)

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

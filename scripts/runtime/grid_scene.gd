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
const RUNTIME_SNAPSHOT_BUILDER_SCRIPT := preload("res://scripts/runtime/runtime_snapshot_builder.gd")
const DUNGEON_INTERACTION_RUNTIME_SCRIPT := preload("res://scripts/runtime/dungeon_interaction_runtime.gd")
const RUNTIME_MAP_QUERY_SCRIPT := preload("res://scripts/runtime/runtime_map_query.gd")
const RUNTIME_ROUTE_GATE_SCRIPT := preload("res://scripts/runtime/runtime_route_gate.gd")

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
var runtime_snapshot_builder: RefCounted
var dungeon_interaction_runtime: RefCounted
var runtime_map_query: RefCounted
var runtime_route_gate: RefCounted

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
	runtime_snapshot_builder = RUNTIME_SNAPSHOT_BUILDER_SCRIPT.new().configure(self)
	dungeon_interaction_runtime = DUNGEON_INTERACTION_RUNTIME_SCRIPT.new().configure(self)
	runtime_map_query = RUNTIME_MAP_QUERY_SCRIPT.new().configure(self)
	runtime_route_gate = RUNTIME_ROUTE_GATE_SCRIPT.new().configure(self)
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
	if runtime_snapshot_builder == null:
		return {}
	return runtime_snapshot_builder.call("hud_snapshot")

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
	if runtime_map_query == null:
		return true
	return bool(runtime_map_query.call("is_blocked", cell))

func _interact_forward() -> void:
	var front_placement := _front_interaction_placement()
	if not front_placement.is_empty():
		_trigger_interaction_placement(front_placement)
		return
	_log("Nothing to interact with.")

func _front_interaction_placement() -> Dictionary:
	if runtime_map_query == null:
		return {}
	return runtime_map_query.call("front_interaction_placement")

func _trigger_interaction_placement(placement: Dictionary) -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("trigger_interaction_placement", placement)

func _interaction_snapshot() -> Dictionary:
	if interaction_snapshot_builder == null:
		return {}
	return interaction_snapshot_builder.call("snapshot")

func _objective_guide_snapshot() -> Dictionary:
	if interaction_snapshot_builder == null:
		return {}
	return interaction_snapshot_builder.call("objective_guide_snapshot")

func _route_affordance_detail(placement: Dictionary, blocked_message: String) -> String:
	if interaction_snapshot_builder == null:
		return ""
	return String(interaction_snapshot_builder.call("route_affordance_detail", placement, blocked_message))

func _field_monster_affordance_detail(placement: Dictionary) -> String:
	if interaction_snapshot_builder == null:
		return ""
	return String(interaction_snapshot_builder.call("field_monster_affordance_detail", placement))

func _event_affordance_detail(placement: Dictionary) -> String:
	if interaction_snapshot_builder == null:
		return ""
	return String(interaction_snapshot_builder.call("event_affordance_detail", placement))

func _door_affordance_detail(placement: Dictionary) -> String:
	if interaction_snapshot_builder == null:
		return ""
	return String(interaction_snapshot_builder.call("door_affordance_detail", placement))

func _secret_affordance_detail(placement: Dictionary) -> String:
	if interaction_snapshot_builder == null:
		return ""
	return String(interaction_snapshot_builder.call("secret_affordance_detail", placement))

func _loot_affordance_detail(placement: Dictionary) -> String:
	if interaction_snapshot_builder == null:
		return ""
	return String(interaction_snapshot_builder.call("loot_affordance_detail", placement))

func _trap_affordance_detail(placement: Dictionary) -> String:
	if interaction_snapshot_builder == null:
		return ""
	return String(interaction_snapshot_builder.call("trap_affordance_detail", placement))

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
	if runtime_map_query == null:
		return [player_cell]
	return runtime_map_query.call("dungeon_path_to_cell", target)

func _route_from_placement(placement: Dictionary) -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("route_from_placement", placement)

func _route_block_message(placement: Dictionary) -> String:
	if runtime_route_gate == null:
		return ""
	return String(runtime_route_gate.call("route_block_message", placement))

func _should_mark_campaign_clear(placement: Dictionary) -> bool:
	if runtime_route_gate == null:
		return false
	return bool(runtime_route_gate.call("should_mark_campaign_clear", placement))

func _resolved_campaign_clear_title(placement: Dictionary) -> String:
	if runtime_route_gate == null:
		return "Expedition Cleared"
	return String(runtime_route_gate.call("resolved_campaign_clear_title", placement))

func _enter_combat(placement: Dictionary) -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("enter_combat", placement)

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
	if runtime_map_query == null:
		return true
	return bool(runtime_map_query.call("cell_hard_blocked", cell))

func _cell_blocks_vision(cell: Vector2i) -> bool:
	if runtime_map_query == null:
		return true
	return bool(runtime_map_query.call("cell_blocks_vision", cell))

func _placement_runtime_cell(placement: Dictionary, runtime: Dictionary = {}) -> Vector2i:
	if runtime_map_query == null:
		var pos: Array = placement.get("position", [0, 0])
		return Vector2i(int(pos[0]), int(pos[1]))
	return runtime_map_query.call("placement_runtime_cell", placement, runtime)

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
	if runtime_map_query == null:
		return "%s:%d,%d" % [String(map_data.get("id", default_map_id)), cell.x, cell.y]
	return String(runtime_map_query.call("cell_visit_key", cell))

func _visited_keys_for_map(runtime: Dictionary) -> Array[String]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("visited_keys_for_map", runtime)

func _visible_minimap_placements(runtime: Dictionary) -> Array[Dictionary]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("visible_minimap_placements", runtime)

func _route_state_entries() -> Array[Dictionary]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("route_state_entries")

func _field_monster_snapshot(runtime: Dictionary) -> Array[Dictionary]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("field_monster_snapshot", runtime)

func _field_monster_state_summary(runtime: Dictionary) -> String:
	if runtime_snapshot_builder == null:
		return "-"
	return String(runtime_snapshot_builder.call("field_monster_state_summary", runtime))

func _route_summary() -> String:
	if runtime_snapshot_builder == null:
		return "-"
	return String(runtime_snapshot_builder.call("route_summary"))

func _quest_target_keys() -> Array[String]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("quest_target_keys")

func _quest_turn_in_keys() -> Array[String]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("quest_turn_in_keys")

func _quest_seed_objective_keys() -> Array[String]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("quest_seed_objective_keys")

func _find_quest_seed_definition(npc_id: String, quest_seed_id: String) -> Dictionary:
	if runtime_snapshot_builder == null:
		return {}
	return runtime_snapshot_builder.call("find_quest_seed_definition", npc_id, quest_seed_id)

func _placement_keys_for_event(event_id: String) -> Array[String]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("placement_keys_for_event", event_id)

func _placement_keys_for_npc(npc_id: String) -> Array[String]:
	if runtime_snapshot_builder == null:
		return []
	return runtime_snapshot_builder.call("placement_keys_for_npc", npc_id)

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
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("trigger_event_placement", placement)

func _try_unlock_door(placement: Dictionary) -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("try_unlock_door", placement)

func _discover_secret(placement: Dictionary) -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("discover_secret", placement)

func _collect_loot(placement: Dictionary) -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("collect_loot", placement)

func _rest_at_placement(placement: Dictionary) -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("rest_at_placement", placement)

func _trigger_trap(placement: Dictionary) -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("trigger_trap", placement)

func _try_rest() -> void:
	if dungeon_interaction_runtime != null:
		dungeon_interaction_runtime.call("try_rest")

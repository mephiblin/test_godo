extends Node

const MODE_TITLE := "title"
const MODE_TOWN := "town"
const MODE_DUNGEON := "dungeon"
const MODE_COMBAT := "combat"
const MODE_EDITOR := "editor"
const DUNGEON_SOURCE_AUTHORED := "authored"
const DUNGEON_SOURCE_COMPILED := "compiled"

var current_mode := MODE_TITLE
var current_slot := 1
var pending_combat_context: Dictionary = {}
var smoke_enabled := false
var smoke_output_dir := ""
var dungeon_runtime_source := DUNGEON_SOURCE_COMPILED
var editor_test_payload: Dictionary = {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	smoke_enabled = "--smoke" in args or OS.get_environment("CONAN_DOT_SMOKE") == "1"
	smoke_output_dir = OS.get_environment("CONAN_DOT_OUTPUT_DIR")

func start_new_game(slot: int = 1, profile: Dictionary = {}) -> void:
	current_slot = slot
	dungeon_runtime_source = DUNGEON_SOURCE_COMPILED
	var data := SaveService.create_default_session(slot, profile)
	current_mode = MODE_TOWN
	SceneRouter.change_route(MODE_TOWN, {
		"slot": slot,
		"map_id": data.get("runtime", {}).get("mapId", "town_square")
	})

func continue_game(slot: int) -> void:
	current_slot = slot
	var inspection := SaveService.inspect_slot(slot)
	if bool(inspection.get("blocked", false)):
		push_warning("Blocked continue for slot %d: %s" % [slot, str(inspection.get("messages", []))])
		return
	var data := SaveService.load_slot(slot)
	if data.is_empty():
		start_new_game(slot)
		return
	current_mode = String(data.get("mode", MODE_TOWN))
	dungeon_runtime_source = String(data.get("runtime", {}).get("dungeonSource", dungeon_runtime_source))
	SceneRouter.change_route(current_mode, {
		"slot": slot,
		"map_id": data.get("runtime", {}).get("mapId", "town_square"),
		"dungeon_source": dungeon_runtime_source
	})

func return_to_title() -> void:
	current_mode = MODE_TITLE
	SceneRouter.change_route(MODE_TITLE, {})

func enter_combat(context: Dictionary) -> void:
	current_slot = int(context.get("slot", current_slot))
	pending_combat_context = context.duplicate(true)
	current_mode = MODE_COMBAT
	SceneRouter.change_route(MODE_COMBAT, context)

func exit_combat(victory: bool) -> void:
	var route := String(pending_combat_context.get("return_route", MODE_DUNGEON))
	var map_id := String(pending_combat_context.get("return_map_id", "dungeon_floor_01"))
	var monster_id := String(pending_combat_context.get("monster_id", ""))
	var monster_instance_id := String(pending_combat_context.get("monster_instance_id", monster_id))
	if victory and monster_instance_id != "":
		var monster_def := ContentRegistry.get_definition("monsters", monster_id)
		SaveService.mark_monster_state(current_slot, monster_instance_id, true)
		var slot_data := SaveService.load_slot(current_slot)
		if not slot_data.is_empty():
			var runtime_state: Dictionary = slot_data.get("runtime", {})
			var field_monsters: Dictionary = runtime_state.get("fieldMonsters", {})
			var state: Dictionary = field_monsters.get(monster_instance_id, {})
			state["monsterId"] = monster_id
			state["isBoss"] = bool(monster_def.get("boss", false))
			field_monsters[monster_instance_id] = state
			runtime_state["fieldMonsters"] = field_monsters
			slot_data["runtime"] = runtime_state
			SaveService.save_slot(current_slot, slot_data)
		if monster_id != "":
			QuestService.on_monster_defeated(current_slot, monster_id)
			if bool(monster_def.get("boss", false)):
				var data := SaveService.load_slot(current_slot)
				if not data.is_empty():
					var flags: Dictionary = data.get("flags", {})
					flags["%s_cleared" % monster_id] = true
					data["flags"] = flags
					SaveService.save_slot(current_slot, data)
		var victory_flag := String(pending_combat_context.get("victory_flag", ""))
		if victory_flag != "":
			var data := SaveService.load_slot(current_slot)
			if not data.is_empty():
				var flags: Dictionary = data.get("flags", {})
				flags[victory_flag] = true
				var npc_id := String(pending_combat_context.get("npc_id", ""))
				if npc_id != "":
					var npc_state: Dictionary = data.get("npcState", {})
					npc_state[npc_id] = {
						"lastService": "fight_victory",
						"updatedAt": Time.get_datetime_string_from_system()
					}
					data["npcState"] = npc_state
				data["flags"] = flags
				SaveService.save_slot(current_slot, data)
	pending_combat_context.clear()
	current_mode = route
	SceneRouter.change_route(route, {
		"slot": current_slot,
		"map_id": map_id,
		"dungeon_source": dungeon_runtime_source
	})

func handle_combat_defeat(summary: Dictionary, return_to_title: bool = false) -> void:
	SaveService.record_defeat(current_slot, summary, return_to_title)
	pending_combat_context.clear()
	if return_to_title:
		current_mode = MODE_TITLE
		SceneRouter.change_route(MODE_TITLE, {})
		return
	current_mode = MODE_TOWN
	SceneRouter.change_route(MODE_TOWN, {
		"slot": current_slot,
		"map_id": "town_square",
		"dungeon_source": dungeon_runtime_source
	})

func set_editor_test_payload(payload: Dictionary) -> void:
	editor_test_payload = payload.duplicate(true)

func consume_editor_test_payload(expected_route: String = "") -> Dictionary:
	if editor_test_payload.is_empty():
		return {}
	var payload := editor_test_payload.duplicate(true)
	var route := String(payload.get("route", ""))
	if expected_route != "" and route != "" and route != expected_route:
		return {}
	editor_test_payload.clear()
	return payload

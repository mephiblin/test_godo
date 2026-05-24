@tool
extends EditorPlugin

const DOCK_NAME := "Connan Content Editor"

var dock: Control

func _enter_tree() -> void:
	dock = preload("res://addons/connan_editor/docks/content_editor_dock.gd").new()
	dock.name = DOCK_NAME
	dock.custom_minimum_size = Vector2(360, 0)
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.plugin = self
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if dock != null:
		remove_control_from_docks(dock)
		dock.free()
		dock = null

func refresh_runtime_content() -> Dictionary:
	ContentRegistry.load_all()
	return ContentRegistry.validate_content()

func play_town_test() -> void:
	play_map_test("town_square")

func play_dungeon_test() -> void:
	play_map_test("dungeon_floor_01", GameApp.DUNGEON_SOURCE_COMPILED)

func play_dungeon_authored_test() -> void:
	play_map_test("dungeon_floor_01", GameApp.DUNGEON_SOURCE_AUTHORED)

func play_map_test(map_id: String, dungeon_source: String = GameApp.DUNGEON_SOURCE_COMPILED, slot: int = 1) -> void:
	refresh_runtime_content()
	var map_data := ContentRegistry.get_map(map_id)
	if map_data.is_empty():
		push_warning("Cannot test-play missing map %s." % map_id)
		return
	var route := String(map_data.get("kind", ""))
	var scene_path := "res://scenes/town/TownScene.tscn"
	if route == GameApp.MODE_DUNGEON:
		scene_path = "res://scenes/dungeon/DungeonScene.tscn"
	GameApp.current_slot = slot
	GameApp.current_mode = route
	GameApp.dungeon_runtime_source = dungeon_source
	GameApp.set_editor_test_payload({
		"route": route,
		"slot": slot,
		"map_id": map_id,
		"dungeon_source": dungeon_source
	})
	get_editor_interface().play_custom_scene(scene_path)

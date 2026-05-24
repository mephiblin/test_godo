extends RefCounted

func snapshot(slot: int, map_id: String, route: String, dungeon_source: String) -> Dictionary:
	var scene_path := "res://scenes/town/TownScene.tscn"
	if route == _game_app().get("MODE_DUNGEON"):
		scene_path = "res://scenes/dungeon/DungeonScene.tscn"
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return {}
	var scene: Node = packed.instantiate()
	_scene_router().get("scene_host").add_child(scene)
	if scene.has_method("setup"):
		scene.call("setup", {
			"slot": slot,
			"map_id": map_id,
			"dungeon_source": dungeon_source
		})
	var result: Dictionary = {}
	if scene.has_method("hud_snapshot"):
		result = scene.call("hud_snapshot")
	scene.queue_free()
	await _next_frame()
	return result

func transition(slot: int, start_map_id: String, target_map_id: String, dungeon_source: String) -> Dictionary:
	var packed: PackedScene = load("res://scenes/dungeon/DungeonScene.tscn")
	if packed == null:
		return {}
	var scene: Node = packed.instantiate()
	var scene_router := _scene_router()
	scene_router.get("scene_host").add_child(scene)
	if scene.has_method("setup"):
		scene.call("setup", {
			"slot": slot,
			"map_id": start_map_id,
			"dungeon_source": dungeon_source
		})
	var result: Dictionary = _grid_scene_smoke_driver().route_probe(scene, target_map_id)
	var current_scene: Node = scene_router.get("current_scene")
	if current_scene != null and current_scene != scene and current_scene.has_method("hud_snapshot"):
		result["snapshot"] = current_scene.call("hud_snapshot")
	if is_instance_valid(scene):
		scene.queue_free()
	await _next_frame()
	return result

func _grid_scene_smoke_driver() -> RefCounted:
	var script: Script = load("res://scripts/tests/grid_scene_smoke_driver.gd")
	return script.new()

func _game_app() -> Node:
	return _autoload("GameApp")

func _scene_router() -> Node:
	return _autoload("SceneRouter")

func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(name)

func _next_frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame

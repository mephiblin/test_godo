extends SceneTree

const PROBE_SLOT := 3

var failures: Array[String] = []
var slot_backup_text := ""
var slot_had_file := false

func _initialize() -> void:
	_backup_slot(PROBE_SLOT)
	_save_service().delete_slot(PROBE_SLOT)
	var registry := _registry()
	registry.load_all()
	var content: Dictionary = registry.validate_content()
	_expect(bool(content.get("ok", false)), "content registry should be valid")
	_expect(String(content.get("manifestPath", "")) == registry.IMPORTED_MANIFEST_PATH, "game runtime should use imported content manifest")
	_expect(registry.get_manifest().has("compiledMaps"), "active imported manifest should expose compiledMaps")
	_expect(not registry.get_manifest().get("definitionHashes", {}).is_empty(), "active imported manifest should expose definitionHashes")
	_probe_imported_maps(registry)
	await _probe_runtime_scene_ignores_editor_payload()
	_probe_new_game_runtime_state()
	_restore_slot(PROBE_SLOT)
	for failure in failures:
		print("IMPORTED_RUNTIME_PROBE_FAIL %s" % failure)
	var ok := failures.is_empty()
	print("IMPORTED_RUNTIME_PROBE ok=%s manifest=%s slot=%d" % [
		str(ok),
		String(content.get("manifestPath", "")),
		PROBE_SLOT
	])
	quit(0 if ok else 1)

func _probe_imported_maps(registry: Node) -> void:
	for map_id in ["town_square", "dungeon_floor_01", "dungeon_floor_02", "dungeon_floor_03"]:
		var map_data: Dictionary = registry.get_map(map_id)
		_expect(not map_data.is_empty(), "imported runtime map should load: %s" % map_id)
		_expect(String(map_data.get("id", "")) == map_id, "imported runtime map id should match: %s" % map_id)
		_expect(String(map_data.get("compiledFrom", "")) != "", "imported runtime map should keep source handoff metadata: %s" % map_id)
		_expect(typeof(map_data.get("compiledPreview", {})) == TYPE_DICTIONARY, "imported runtime map should include compiled preview metadata: %s" % map_id)

func _probe_new_game_runtime_state() -> void:
	var app := _game_app()
	app.editor_test_payload.clear()
	app.start_new_game(PROBE_SLOT, {
		"name": "Runtime Probe",
		"slotName": "Imported Runtime Probe"
	})
	_expect(app.editor_test_payload.is_empty(), "new game runtime should not consume or persist editor test payload")
	_expect(app.dungeon_runtime_source == app.DUNGEON_SOURCE_COMPILED, "new game runtime source should be compiled")
	_expect(app.current_mode == app.MODE_TOWN, "new game should enter town mode")
	var data: Dictionary = _save_service().load_slot(PROBE_SLOT)
	_expect(not data.is_empty(), "new game should write a runtime save session")
	_expect(String(data.get("mode", "")) == app.MODE_TOWN, "save mode should be town")
	var runtime: Dictionary = data.get("runtime", {})
	_expect(String(runtime.get("mapId", "")) == "town_square", "save runtime map should start at town_square")
	_expect(String(runtime.get("dungeonSource", "")) == app.DUNGEON_SOURCE_COMPILED, "save runtime should persist compiled dungeon source")
	for editor_key in ["editorDraft", "editorSelection", "editorPreview", "editorTestPayload"]:
		_expect(not data.has(editor_key), "save data should not contain editor-only key: %s" % editor_key)
	_expect(not runtime.has("editorDraft"), "runtime state should not contain editor draft data")

func _probe_runtime_scene_ignores_editor_payload() -> void:
	var app := _game_app()
	app.current_slot = PROBE_SLOT
	app.dungeon_runtime_source = app.DUNGEON_SOURCE_COMPILED
	app.set_editor_test_payload({
		"route": app.MODE_DUNGEON,
		"slot": PROBE_SLOT,
		"map_id": "dungeon_floor_02",
		"dungeon_source": app.DUNGEON_SOURCE_AUTHORED
	})
	var scene: Node = load("res://scenes/dungeon/DungeonScene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_expect(not app.editor_test_payload.is_empty(), "real runtime scene should not consume editor test payload")
	_expect(String(scene.get("map_data").get("id", "")) == "dungeon_floor_01", "real runtime scene should use its default/runtime payload instead of editor test payload")
	_expect(String(scene.get("dungeon_source_mode")) == app.DUNGEON_SOURCE_COMPILED, "real runtime scene should not inherit authored editor test source")
	scene.queue_free()
	await process_frame
	app.editor_test_payload.clear()

func _backup_slot(slot: int) -> void:
	var path: String = _save_service().slot_path(slot)
	slot_had_file = FileAccess.file_exists(path)
	if slot_had_file:
		var file := FileAccess.open(path, FileAccess.READ)
		slot_backup_text = file.get_as_text() if file != null else ""

func _restore_slot(slot: int) -> void:
	var path: String = _save_service().slot_path(slot)
	if slot_had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(slot_backup_text)
	else:
		_save_service().delete_slot(slot)

func _registry() -> Node:
	return root.get_node("ContentRegistry")

func _game_app() -> Node:
	return root.get_node("GameApp")

func _save_service() -> Node:
	return root.get_node("SaveService")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

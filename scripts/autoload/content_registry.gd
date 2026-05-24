extends Node

const SOURCE_MANIFEST_PATH := "res://data/source_json/content_manifest.json"
const IMPORTED_MANIFEST_PATH := "res://data/imported/content_build_manifest.json"

var manifest: Dictionary = {}
var maps: Dictionary = {}
var definitions: Dictionary = {}
var load_errors: PackedStringArray = []
var load_warnings: PackedStringArray = []
var active_manifest_path := SOURCE_MANIFEST_PATH

func _ready() -> void:
	load_all()

func load_all() -> void:
	load_errors.clear()
	load_warnings.clear()
	maps.clear()
	definitions.clear()
	active_manifest_path = _select_manifest_path()
	manifest = _load_json(active_manifest_path)
	if manifest.is_empty():
		load_errors.append("Missing content manifest: %s" % active_manifest_path)
		return
	var manifest_maps: Array = manifest.get("compiledMaps", manifest.get("maps", []))
	for entry in manifest_maps:
		var path := String(entry.get("path", ""))
		var map_data := _load_json(path)
		if map_data.is_empty():
			load_errors.append("Failed to load map: %s" % path)
			continue
		maps[map_data.get("id", path)] = map_data
	var definition_paths: Dictionary = manifest.get("definitions", {})
	for kind in definition_paths.keys():
		var path := String(definition_paths[kind])
		var rows: Array = _load_json_rows(path)
		var bucket: Dictionary = {}
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			bucket[String(row.get("id", ""))] = row
		definitions[String(kind)] = bucket

func validate_content() -> Dictionary:
	return {
			"ok": load_errors.is_empty(),
			"errors": load_errors.duplicate(),
			"warnings": load_warnings.duplicate(),
			"mapCount": maps.size(),
			"definitionKinds": definitions.keys(),
			"manifestPath": active_manifest_path,
			"contentVersion": int(manifest.get("contentVersion", 0))
	}

func get_map(map_id: String) -> Dictionary:
	return maps.get(map_id, {})

func get_manifest() -> Dictionary:
	return manifest

func get_definition(kind: String, definition_id: String) -> Dictionary:
	var bucket: Dictionary = definitions.get(kind, {})
	return bucket.get(definition_id, {})

func list_definitions(kind: String) -> Array[Dictionary]:
	var bucket: Dictionary = definitions.get(kind, {})
	var result: Array[Dictionary] = []
	for key in bucket.keys():
		result.append(bucket[key])
	return result

func _select_manifest_path() -> String:
	if not FileAccess.file_exists(IMPORTED_MANIFEST_PATH):
		return SOURCE_MANIFEST_PATH
	var source_manifest := _load_json(SOURCE_MANIFEST_PATH)
	var imported_manifest := _load_json(IMPORTED_MANIFEST_PATH)
	if imported_manifest.is_empty():
		load_warnings.append("Imported content manifest is unreadable; using source manifest.")
		return SOURCE_MANIFEST_PATH
	var source_version := int(source_manifest.get("contentVersion", 0))
	var imported_version := int(imported_manifest.get("contentVersion", 0))
	if source_version > 0 and imported_version < source_version:
		load_warnings.append("Imported content manifest is stale (%d < %d); using source manifest." % [imported_version, source_version])
		return SOURCE_MANIFEST_PATH
	for entry in imported_manifest.get("compiledMaps", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var source_path := String(entry.get("sourcePath", ""))
		var expected_hash := int(entry.get("sourceHash", 0))
		if source_path == "" or expected_hash == 0:
			continue
		var actual_hash := _file_content_hash(source_path)
		if actual_hash != 0 and actual_hash != expected_hash:
			load_warnings.append("Imported compiled map %s is stale; source hash changed." % String(entry.get("id", source_path)))
			return SOURCE_MANIFEST_PATH
	return IMPORTED_MANIFEST_PATH

func resolve_loot_items(table_id: String) -> Array[Dictionary]:
	var table := get_definition("loot_tables", table_id)
	if table.is_empty():
		return []
	var rewards: Array[Dictionary] = []
	for entry in table.get("guaranteed", []):
		if typeof(entry) == TYPE_DICTIONARY and String(entry.get("itemId", "")) != "":
			rewards.append({
				"itemId": String(entry.get("itemId", "")),
				"quantity": maxi(int(entry.get("quantity", 1)), 1)
			})
	if not rewards.is_empty():
		return rewards
	for tier in table.get("tierEntries", []):
		if typeof(tier) != TYPE_DICTIONARY:
			continue
		for entry in tier.get("entries", []):
			if typeof(entry) == TYPE_DICTIONARY and String(entry.get("itemId", "")) != "":
				rewards.append({
					"itemId": String(entry.get("itemId", "")),
					"quantity": maxi(int(entry.get("quantity", 1)), 1)
				})
				return rewards
	return rewards

func find_map_profile(profile_id: String = "", map_id: String = "") -> Dictionary:
	for row in list_definitions("map_profiles"):
		if profile_id != "" and String(row.get("id", "")) == profile_id:
			return row
		if map_id != "" and String(row.get("mapId", "")) == map_id:
			return row
	return {}

func find_object_theme(object_theme_id: String = "", theme_id: String = "") -> Dictionary:
	for row in list_definitions("object_themes"):
		if object_theme_id != "" and String(row.get("id", "")) == object_theme_id:
			return row
		if theme_id != "" and String(row.get("theme", "")) == theme_id:
			return row
	return {}

func find_tile_substitutions(theme_id: String, target: String = "floor") -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for row in list_definitions("tile_substitutions"):
		if String(row.get("theme", "")) == theme_id and String(row.get("target", "")) == target:
			matches.append(row)
	return matches

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _file_content_hash(path: String) -> int:
	if path == "" or not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	return file.get_as_text().hash()

func _load_json_rows(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		var rows_from_array: Array = []
		for index in range(parsed.size()):
			var row: Variant = parsed[index]
			if typeof(row) != TYPE_DICTIONARY:
				continue
			rows_from_array.append(_normalize_row(row, str(index)))
		return rows_from_array
	if typeof(parsed) == TYPE_DICTIONARY:
		var rows: Array = []
		for key in parsed.keys():
			var row: Variant = parsed[key]
			if typeof(row) != TYPE_DICTIONARY:
				continue
			rows.append(_normalize_row(row, String(key)))
		return rows
	return []

func _normalize_row(row: Variant, fallback_id: String) -> Dictionary:
	var normalized: Dictionary = (row as Dictionary).duplicate(true)
	var row_id := String(normalized.get("id", ""))
	if row_id == "":
		row_id = String(normalized.get("mapId", ""))
	if row_id == "":
		row_id = "floor_%s" % String(normalized.get("floor")) if normalized.has("floor") else fallback_id
	normalized["id"] = row_id
	return normalized

extends SceneTree

const IMPORTED_MANIFEST_PATH := "res://data/imported/content_build_manifest.json"
const SOURCE_MANIFEST_PATH := "res://data/source_json/content_manifest.json"

var failures: Array[String] = []

func _initialize() -> void:
	var registry := _registry()
	var imported_backup := _read_text(IMPORTED_MANIFEST_PATH)
	registry.load_all()
	var baseline: Dictionary = registry.validate_content()
	_expect(bool(baseline.get("ok", false)), "baseline content registry should load")
	_expect(String(baseline.get("manifestPath", "")) == IMPORTED_MANIFEST_PATH, "current valid imported bundle should be active")
	_probe_stale_imported_fallback(registry)
	_restore_text(IMPORTED_MANIFEST_PATH, imported_backup)
	registry.load_all()
	var restored: Dictionary = registry.validate_content()
	_expect(String(restored.get("manifestPath", "")) == IMPORTED_MANIFEST_PATH, "registry should return to imported manifest after restore")
	for failure in failures:
		print("CONTENT_REGISTRY_CONTRACT_FAIL %s" % failure)
	var ok := failures.is_empty()
	print("CONTENT_REGISTRY_CONTRACT ok=%s active=%s warnings=%s" % [
		str(ok),
		String(restored.get("manifestPath", "")),
		str(restored.get("warnings", []))
	])
	quit(0 if ok else 1)

func _probe_stale_imported_fallback(registry: Node) -> void:
	var imported := _read_json_dict(IMPORTED_MANIFEST_PATH)
	var source := _read_json_dict(SOURCE_MANIFEST_PATH)
	_expect(not imported.is_empty(), "imported manifest fixture should exist")
	_expect(not source.is_empty(), "source manifest fixture should exist")
	imported["contentVersion"] = maxi(int(source.get("contentVersion", 1)) - 1, 0)
	_write_text(IMPORTED_MANIFEST_PATH, JSON.stringify(imported, "\t"))
	registry.load_all()
	var stale: Dictionary = registry.validate_content()
	_expect(bool(stale.get("ok", false)), "stale imported fallback should still load valid content")
	_expect(String(stale.get("manifestPath", "")) == SOURCE_MANIFEST_PATH, "stale imported manifest should fall back to source manifest")
	var warning_text := "\n".join(stale.get("warnings", []))
	_expect(warning_text.contains("stale"), "stale imported fallback should expose warning")
	_expect(int(stale.get("contentVersion", 0)) == int(source.get("contentVersion", 0)), "fallback should expose source contentVersion")

func _registry() -> Node:
	return root.get_node("ContentRegistry")

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)

func _restore_text(path: String, text: String) -> void:
	_write_text(path, text)

func _read_json_dict(path: String) -> Dictionary:
	var text := _read_text(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

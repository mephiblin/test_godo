extends SceneTree

const ContentTools = preload("res://scripts/editor/content_tools.gd")

func _initialize() -> void:
	var definition_validation := ContentTools.validate_definitions(ContentTools.load_definitions())
	var map_validation := ContentTools.validate_maps()
	print("VALIDATION definitions_ok=%s map_ok=%s" % [str(definition_validation.get("ok", false)), str(map_validation.get("ok", false))])
	for error in definition_validation.get("errors", []):
		print("DEF_ERROR %s" % String(error))
	for error in map_validation.get("errors", []):
		print("MAP_ERROR %s" % String(error))
	quit(0 if bool(definition_validation.get("ok", false)) and bool(map_validation.get("ok", false)) else 1)

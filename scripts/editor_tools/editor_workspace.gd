extends Control

const ContentTools = preload("res://scripts/editor/content_tools.gd")
const ROUTE_PREVIEW_REPORT_PATHS := [
	"res://output/editor_route_preview_report.json",
	"res://data/imported/editor_route_preview_report.json"
]

var selected_map_id := "dungeon_floor_01"
var map_option: OptionButton
var map_entries: Array[Dictionary] = []
var summary_label: RichTextLabel
var route_preview_option: OptionButton
var route_preview_entries: Array[Dictionary] = []
var route_preview_detail_label: RichTextLabel
var route_target_service_option: OptionButton
var route_target_event_step_option: OptionButton
var route_target_event_choice_option: OptionButton
var current_route_target_service_index := 0
var current_route_target_event_step_id := ""
var current_route_target_event_choice_index := 0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = Color("0f1518")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 80
	panel.offset_top = 60
	panel.offset_right = -80
	panel.offset_bottom = -60
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "Editor Fallback Workspace"
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)

	summary_label = RichTextLabel.new()
	summary_label.bbcode_enabled = true
	summary_label.fit_content = true
	summary_label.custom_minimum_size = Vector2(720, 120)
	layout.add_child(summary_label)

	route_preview_option = OptionButton.new()
	route_preview_option.item_selected.connect(_on_route_preview_selected)
	layout.add_child(route_preview_option)

	route_preview_detail_label = RichTextLabel.new()
	route_preview_detail_label.bbcode_enabled = true
	route_preview_detail_label.fit_content = true
	route_preview_detail_label.custom_minimum_size = Vector2(720, 180)
	layout.add_child(route_preview_detail_label)

	route_target_service_option = OptionButton.new()
	route_target_service_option.item_selected.connect(_on_route_target_service_selected)
	layout.add_child(route_target_service_option)

	route_target_event_step_option = OptionButton.new()
	route_target_event_step_option.item_selected.connect(_on_route_target_event_step_selected)
	layout.add_child(route_target_event_step_option)

	route_target_event_choice_option = OptionButton.new()
	route_target_event_choice_option.item_selected.connect(_on_route_target_event_choice_selected)
	layout.add_child(route_target_event_choice_option)

	map_option = OptionButton.new()
	map_entries = ContentTools.list_map_entries()
	for entry in map_entries:
		var map_id := String(entry.get("id", ""))
		var kind := String(entry.get("kind", ""))
		map_option.add_item("%s (%s)" % [map_id, kind])
		if map_id == selected_map_id:
			map_option.select(map_option.item_count - 1)
	map_option.item_selected.connect(_on_map_selected)
	layout.add_child(map_option)
	refresh_summary()

	var test_town_button := Button.new()
	test_town_button.text = "Test Selected Compiled"
	test_town_button.pressed.connect(func() -> void:
		var content_registry: Node = get_node_or_null("/root/ContentRegistry")
		var game_app: Node = get_node_or_null("/root/GameApp")
		var scene_router: Node = get_node_or_null("/root/SceneRouter")
		if content_registry == null or game_app == null or scene_router == null:
			return
		var selected_map: Dictionary = content_registry.call("get_map", selected_map_id)
		var route := String(selected_map.get("kind", game_app.get("MODE_TOWN")))
		game_app.set("current_mode", route)
		game_app.set("dungeon_runtime_source", game_app.get("DUNGEON_SOURCE_COMPILED"))
		scene_router.call("change_route", route, {"slot": game_app.get("current_slot"), "map_id": selected_map_id, "dungeon_source": game_app.get("DUNGEON_SOURCE_COMPILED")})
	)
	layout.add_child(test_town_button)

	var test_dungeon_button := Button.new()
	test_dungeon_button.text = "Test Dungeon Compiled"
	test_dungeon_button.pressed.connect(func() -> void:
		var content_registry: Node = get_node_or_null("/root/ContentRegistry")
		var game_app: Node = get_node_or_null("/root/GameApp")
		var scene_router: Node = get_node_or_null("/root/SceneRouter")
		if content_registry == null or game_app == null or scene_router == null:
			return
		var selected_map: Dictionary = content_registry.call("get_map", selected_map_id)
		var route := String(selected_map.get("kind", game_app.get("MODE_DUNGEON")))
		game_app.set("current_mode", route)
		game_app.set("dungeon_runtime_source", game_app.get("DUNGEON_SOURCE_COMPILED"))
		scene_router.call("change_route", route, {"slot": game_app.get("current_slot"), "map_id": selected_map_id, "dungeon_source": game_app.get("DUNGEON_SOURCE_COMPILED")})
	)
	layout.add_child(test_dungeon_button)

	var test_dungeon_authored_button := Button.new()
	test_dungeon_authored_button.text = "Test Dungeon Authored"
	test_dungeon_authored_button.pressed.connect(func() -> void:
		var content_registry: Node = get_node_or_null("/root/ContentRegistry")
		var game_app: Node = get_node_or_null("/root/GameApp")
		var scene_router: Node = get_node_or_null("/root/SceneRouter")
		if content_registry == null or game_app == null or scene_router == null:
			return
		var selected_map: Dictionary = content_registry.call("get_map", selected_map_id)
		var route := String(selected_map.get("kind", game_app.get("MODE_DUNGEON")))
		game_app.set("current_mode", route)
		game_app.set("dungeon_runtime_source", game_app.get("DUNGEON_SOURCE_AUTHORED"))
		scene_router.call("change_route", route, {"slot": game_app.get("current_slot"), "map_id": selected_map_id, "dungeon_source": game_app.get("DUNGEON_SOURCE_AUTHORED")})
	)
	layout.add_child(test_dungeon_authored_button)

	var export_button := Button.new()
	export_button.text = "Export Manifest Report"
	export_button.pressed.connect(func() -> void:
		refresh_summary()
	)
	layout.add_child(export_button)

	var button := Button.new()
	button.text = "Return to Title"
	button.pressed.connect(func() -> void:
		var game_app: Node = get_node_or_null("/root/GameApp")
		if game_app != null:
			game_app.call("return_to_title")
	)
	layout.add_child(button)

func _on_map_selected(index: int) -> void:
	if index < 0 or index >= map_entries.size():
		return
	selected_map_id = String(map_entries[index].get("id", selected_map_id))
	refresh_summary()

func _on_route_preview_selected(_index: int) -> void:
	_reset_route_target_preview_state()
	_refresh_route_target_controls()
	_refresh_route_preview_detail()

func _on_route_target_service_selected(index: int) -> void:
	current_route_target_service_index = max(index, 0)
	_refresh_route_preview_detail()

func _on_route_target_event_step_selected(index: int) -> void:
	var step_options := _route_target_event_steps()
	if index < 0 or index >= step_options.size():
		return
	current_route_target_event_step_id = String(step_options[index].get("id", ""))
	current_route_target_event_choice_index = 0
	_refresh_route_target_controls()
	_refresh_route_preview_detail()

func _on_route_target_event_choice_selected(index: int) -> void:
	current_route_target_event_choice_index = max(index, 0)
	_refresh_route_preview_detail()

func refresh_summary() -> void:
	var content_registry: Node = get_node_or_null("/root/ContentRegistry")
	if content_registry == null:
		summary_label.text = "ContentRegistry unavailable."
		return
	var content: Dictionary = content_registry.call("validate_content")
	var report := ContentTools.export_manifest_report("")
	var selected_map: Dictionary = content_registry.call("get_map", selected_map_id)
	var preview := ContentTools.export_compiled_map_preview(selected_map_id, "")
	var profile: Dictionary = content_registry.call("find_map_profile", String(selected_map.get("mapProfileId", "")), String(selected_map.get("id", "")))
	var object_theme: Dictionary = content_registry.call("find_object_theme", String(selected_map.get("objectThemeId", "")), String(selected_map.get("themeId", "")))
	var preview_rows: Array = preview.get("previewRows", ["preview unavailable"])
	var route_preview_report := _load_route_preview_report()
	_refresh_route_preview_entries(route_preview_report, selected_map_id)
	_refresh_route_target_controls()
	summary_label.text = "[b]Manifest[/b] ok=%s mapCount=%d contentVersion=%d\n[b]Manifest Path[/b] %s\n[b]Selected Map[/b] %s / kind=%s\n[b]Definition Counts[/b] %s\n[b]Map Profile[/b] %s / chunks=%s\n[b]Map Theme[/b] %s / props=%s / floor rules=%d\n[b]Generated Assembly[/b] cells=%d placements=%d start=%s\n[b]Map Preview[/b]\n%s\n[b]Route Preview Report[/b]\n%s\n[b]Validation[/b] %s\nThis fallback workspace stays separate from runtime saves and mirrors the first-pass EditorPlugin workflow." % [
		content["ok"],
		content["mapCount"],
		content["contentVersion"],
		content["manifestPath"],
		selected_map_id,
		String(selected_map.get("kind", "-")),
		str(report.get("counts", {})),
		String(profile.get("name", selected_map.get("mapProfileId", "-"))),
		str(selected_map.get("sourceChunkIds", [])),
		String(selected_map.get("themeId", "-")),
		String(object_theme.get("id", "-")),
		int(content_registry.call("find_tile_substitutions", String(selected_map.get("themeId", "")), "floor").size()),
		preview.get("generatedCells", []).size(),
		preview.get("generatedPlacements", []).size(),
		str(preview.get("generatedStart", [])),
		"\n".join(preview_rows),
		_route_preview_summary_text(route_preview_report, selected_map_id),
		str(report.get("validation", {}).get("ok", false))
	]
	_refresh_route_preview_detail()

func _load_route_preview_report() -> Dictionary:
	for path in ROUTE_PREVIEW_REPORT_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			var report: Dictionary = parsed
			report["_artifactPath"] = path
			return report
	return {}

func _route_preview_summary_text(report: Dictionary, map_id: String) -> String:
	if report.is_empty():
		return "artifact unavailable (%s)" % ", ".join(ROUTE_PREVIEW_REPORT_PATHS)
	var matching_entries := _matching_route_preview_entries(report, map_id)
	if matching_entries.is_empty():
		return "artifact loaded (%s) but no route previews target %s" % [_route_preview_artifact_path(report), map_id]
	var rows: Array[String] = ["artifact=%s | matches=%d" % [_route_preview_artifact_path(report), matching_entries.size()]]
	for entry in matching_entries:
		rows.append(_route_preview_entry_text(String(entry.get("label", "")), entry.get("snapshot", {})))
	return "\n".join(rows)

func _route_preview_artifact_path(report: Dictionary) -> String:
	return String(report.get("_artifactPath", ROUTE_PREVIEW_REPORT_PATHS[0]))

func _matching_route_preview_entries(report: Dictionary, map_id: String) -> Array[Dictionary]:
	var matching_entries: Array[Dictionary] = []
	for key_variant in report.keys():
		var key := String(key_variant)
		var snapshot_variant: Variant = report.get(key, {})
		if typeof(snapshot_variant) != TYPE_DICTIONARY:
			continue
		var snapshot: Dictionary = snapshot_variant
		if _route_preview_matches_map(snapshot, map_id):
			matching_entries.append({
				"label": key,
				"snapshot": snapshot
			})
	matching_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")) < String(b.get("label", ""))
	)
	return matching_entries

func _route_preview_matches_map(snapshot: Dictionary, map_id: String) -> bool:
	if map_id == "":
		return false
	for target_variant in snapshot.get("routeTargets", []):
		if String(target_variant) == map_id:
			return true
	return String(snapshot.get("routeTargetPreview", "")).contains(map_id)

func _route_preview_entry_text(label: String, snapshot: Dictionary) -> String:
	var highlight := String(snapshot.get("routeHighlightedPlacement", "highlight unavailable"))
	var selected_service := String(snapshot.get("routeTargetSelectedNpcService", ""))
	var selected_step := String(snapshot.get("routeTargetSelectedEventStep", ""))
	var selected_choice := String(snapshot.get("routeTargetSelectedEventChoice", ""))
	var downstream := String(snapshot.get("routeHighlightedPlacementDownstream", ""))
	var details: Array[String] = [highlight]
	if selected_service != "" and not selected_service.contains("unavailable"):
		details.append(selected_service)
	if selected_step != "" and not selected_step.contains("unavailable"):
		details.append(selected_step)
	if selected_choice != "" and not selected_choice.contains("unavailable"):
		details.append(selected_choice)
	if downstream != "" and downstream != "Highlighted downstream: none" and not downstream.contains("unavailable"):
		details.append(downstream)
	return "- %s\n  %s" % [label, "\n  ".join(details)]

func _refresh_route_preview_entries(report: Dictionary, map_id: String) -> void:
	var previous_label := _selected_route_preview_label()
	route_preview_entries = _matching_route_preview_entries(report, map_id)
	route_preview_option.clear()
	for entry in route_preview_entries:
		route_preview_option.add_item(String(entry.get("label", "")))
	if route_preview_entries.is_empty():
		route_preview_option.disabled = true
		_reset_route_target_preview_state()
		_refresh_route_target_controls()
		return
	route_preview_option.disabled = false
	var selected_index := 0
	for index in route_preview_entries.size():
		if String(route_preview_entries[index].get("label", "")) == previous_label:
			selected_index = index
			break
	route_preview_option.select(selected_index)
	_reset_route_target_preview_state()
	_refresh_route_target_controls()

func _refresh_route_preview_detail() -> void:
	if route_preview_detail_label == null:
		return
	var snapshot := _selected_route_preview_snapshot()
	if snapshot.is_empty():
		route_preview_detail_label.text = "[b]Route Preview Detail[/b]\nNo matching route-preview entry for this map."
		return
	var label := _selected_route_preview_label()
	var live_selected_npc := _route_target_selected_npc_service_text(snapshot)
	var live_selected_step := _route_target_selected_event_step_text(snapshot)
	var live_selected_choice := _route_target_selected_event_choice_text(snapshot)
	var live_downstream := _route_target_downstream_text(snapshot)
	route_preview_detail_label.text = "[b]Route Preview Detail[/b] %s\n[b]Summary[/b] %s\n[b]Highlight[/b] %s\n[b]Contract[/b] %s\n[b]Detail[/b] %s\n[b]Selected Target NPC[/b] %s\n[b]Selected Target Step[/b] %s\n[b]Selected Target Choice[/b] %s\n[b]Downstream[/b] %s\n[b]Mini-grid[/b]\n%s" % [
		label,
		String(snapshot.get("summary", "-")),
		String(snapshot.get("routeHighlightedPlacement", "-")),
		String(snapshot.get("routeHighlightedPlacementContract", "-")),
		String(snapshot.get("routeHighlightedPlacementDetail", "-")),
		live_selected_npc,
		live_selected_step,
		live_selected_choice,
		live_downstream,
		String(snapshot.get("routeTargetMiniGrid", "-"))
	]

func _selected_route_preview_label() -> String:
	if route_preview_option == null or route_preview_entries.is_empty():
		return ""
	var index := route_preview_option.selected
	if index < 0 or index >= route_preview_entries.size():
		return ""
	return String(route_preview_entries[index].get("label", ""))

func _selected_route_preview_snapshot() -> Dictionary:
	if route_preview_option == null or route_preview_entries.is_empty():
		return {}
	var index := route_preview_option.selected
	if index < 0 or index >= route_preview_entries.size():
		return {}
	return route_preview_entries[index].get("snapshot", {})

func _selected_route_target_placement() -> Dictionary:
	var snapshot := _selected_route_preview_snapshot()
	if snapshot.is_empty():
		return {}
	var highlighted := String(snapshot.get("routeHighlightedPlacement", ""))
	var placement_id := _parse_route_highlight_property(highlighted, "Highlighted target: ", " |")
	if placement_id == "":
		return {}
	for placement in ContentTools.list_map_placements(selected_map_id):
		if String(placement.get("id", "")) == placement_id:
			return placement
	return {}

func _selected_route_target_type() -> String:
	var snapshot := _selected_route_preview_snapshot()
	if snapshot.is_empty():
		return ""
	return _parse_route_highlight_property(String(snapshot.get("routeHighlightedPlacement", "")), "type=", " |")

func _refresh_route_target_controls() -> void:
	var placement := _selected_route_target_placement()
	var target_type := String(placement.get("type", _selected_route_target_type()))
	_refresh_route_target_service_control(placement, target_type)
	_refresh_route_target_event_step_control(placement, target_type)
	_refresh_route_target_event_choice_control(placement, target_type)

func _refresh_route_target_service_control(placement: Dictionary, target_type: String) -> void:
	route_target_service_option.clear()
	if target_type != "npc_service":
		route_target_service_option.disabled = true
		route_target_service_option.visible = false
		return
	var services := _route_target_npc_services(placement)
	for service in services:
		route_target_service_option.add_item("%s:%s" % [String(service.get("type", "")), String(service.get("label", ""))])
	route_target_service_option.disabled = services.is_empty()
	route_target_service_option.visible = not services.is_empty()
	if services.is_empty():
		return
	current_route_target_service_index = clamp(current_route_target_service_index, 0, services.size() - 1)
	route_target_service_option.select(current_route_target_service_index)

func _refresh_route_target_event_step_control(placement: Dictionary, target_type: String) -> void:
	route_target_event_step_option.clear()
	if not ["event", "rest", "trap"].has(target_type):
		route_target_event_step_option.disabled = true
		route_target_event_step_option.visible = false
		return
	var steps := _route_target_event_steps(placement)
	for step in steps:
		route_target_event_step_option.add_item("%s:%s" % [String(step.get("id", "")), String(step.get("text", ""))])
	route_target_event_step_option.disabled = steps.is_empty()
	route_target_event_step_option.visible = not steps.is_empty()
	if steps.is_empty():
		return
	var selected_index := 0
	if current_route_target_event_step_id != "":
		for index in steps.size():
			if String(steps[index].get("id", "")) == current_route_target_event_step_id:
				selected_index = index
				break
	else:
		current_route_target_event_step_id = String(steps[0].get("id", ""))
	route_target_event_step_option.select(selected_index)

func _refresh_route_target_event_choice_control(placement: Dictionary, target_type: String) -> void:
	route_target_event_choice_option.clear()
	if not ["event", "rest", "trap"].has(target_type):
		route_target_event_choice_option.disabled = true
		route_target_event_choice_option.visible = false
		return
	var choices := _route_target_event_choices(placement)
	for choice in choices:
		route_target_event_choice_option.add_item(String(choice.get("label", "")))
	route_target_event_choice_option.disabled = choices.is_empty()
	route_target_event_choice_option.visible = not choices.is_empty()
	if choices.is_empty():
		return
	current_route_target_event_choice_index = clamp(current_route_target_event_choice_index, 0, choices.size() - 1)
	route_target_event_choice_option.select(current_route_target_event_choice_index)

func _reset_route_target_preview_state() -> void:
	current_route_target_service_index = 0
	current_route_target_event_step_id = ""
	current_route_target_event_choice_index = 0

func _route_target_npc_services(placement: Dictionary) -> Array[Dictionary]:
	var npc_id := String(placement.get("npcId", ""))
	if npc_id == "":
		return []
	var content_registry: Node = get_node_or_null("/root/ContentRegistry")
	if content_registry == null:
		return []
	var npc: Dictionary = content_registry.call("get_definition", "npcs", npc_id)
	var result: Array[Dictionary] = []
	for service in npc.get("services", []):
		if typeof(service) == TYPE_DICTIONARY:
			result.append(service)
	return result

func _route_target_event_definition(placement: Dictionary) -> Dictionary:
	var event_id := String(placement.get("eventId", ""))
	if event_id == "":
		return {}
	var content_registry: Node = get_node_or_null("/root/ContentRegistry")
	if content_registry == null:
		return {}
	return content_registry.call("get_definition", "events", event_id)

func _route_target_event_steps(placement: Dictionary = {}) -> Array[Dictionary]:
	if placement.is_empty():
		placement = _selected_route_target_placement()
	var event_def := _route_target_event_definition(placement)
	var result: Array[Dictionary] = []
	for step in event_def.get("steps", []):
		if typeof(step) == TYPE_DICTIONARY:
			result.append(step)
	if result.is_empty() and not event_def.is_empty():
		var entry_step_id := String(event_def.get("entryStepId", ""))
		if entry_step_id != "":
			result.append({
				"id": entry_step_id,
				"text": String(event_def.get("text", event_def.get("name", entry_step_id)))
			})
	return result

func _route_target_selected_event_step(placement: Dictionary = {}) -> Dictionary:
	var steps := _route_target_event_steps(placement)
	if steps.is_empty():
		return {}
	if current_route_target_event_step_id == "":
		return steps[0]
	for step in steps:
		if String(step.get("id", "")) == current_route_target_event_step_id:
			return step
	return steps[0]

func _route_target_event_choices(placement: Dictionary = {}) -> Array[Dictionary]:
	var step := _route_target_selected_event_step(placement)
	var result: Array[Dictionary] = []
	for choice in step.get("choices", []):
		if typeof(choice) == TYPE_DICTIONARY:
			result.append(choice)
	return result

func _route_target_selected_event_choice(placement: Dictionary = {}) -> Dictionary:
	var choices := _route_target_event_choices(placement)
	if choices.is_empty():
		return {}
	var index: int = clamp(current_route_target_event_choice_index, 0, choices.size() - 1)
	return choices[index]

func _route_target_selected_npc_service_text(snapshot: Dictionary) -> String:
	var placement := _selected_route_target_placement()
	if String(placement.get("type", "")) != "npc_service":
		return String(snapshot.get("routeTargetSelectedNpcService", "-"))
	var services := _route_target_npc_services(placement)
	if services.is_empty():
		return String(snapshot.get("routeTargetSelectedNpcService", "-"))
	var service := services[clamp(current_route_target_service_index, 0, services.size() - 1)]
	var text := "Selected service: %s:%s" % [str(service.get("type", "")), str(service.get("label", ""))]
	var opens_service: Variant = service.get("opensService", {})
	var opens_kind := ""
	var opens_id := ""
	if typeof(opens_service) == TYPE_DICTIONARY:
		opens_kind = String((opens_service as Dictionary).get("kind", ""))
		opens_id = String((opens_service as Dictionary).get("serviceId", ""))
	else:
		opens_kind = String(opens_service)
		opens_id = String(service.get("opensServiceId", ""))
	if opens_kind != "" or opens_id != "":
		text += " | opens %s/%s" % [opens_kind, opens_id]
	return text

func _route_target_selected_event_step_text(snapshot: Dictionary) -> String:
	var placement := _selected_route_target_placement()
	if not ["event", "rest", "trap"].has(String(placement.get("type", ""))):
		return String(snapshot.get("routeTargetSelectedEventStep", "-"))
	var step := _route_target_selected_event_step(placement)
	if step.is_empty():
		return String(snapshot.get("routeTargetSelectedEventStep", "-"))
	return "Selected step: %s | %s" % [String(step.get("id", "")), String(step.get("text", ""))]

func _route_target_selected_event_choice_text(snapshot: Dictionary) -> String:
	var placement := _selected_route_target_placement()
	if not ["event", "rest", "trap"].has(String(placement.get("type", ""))):
		return String(snapshot.get("routeTargetSelectedEventChoice", "-"))
	var choice := _route_target_selected_event_choice(placement)
	if choice.is_empty():
		return String(snapshot.get("routeTargetSelectedEventChoice", "-"))
	var parts: Array[String] = ["Selected choice: %s" % String(choice.get("label", ""))]
	var next_step := String(choice.get("nextStepId", ""))
	if next_step != "":
		parts.append("next=%s" % next_step)
	var seed_id := String(choice.get("questSeedId", ""))
	if seed_id != "":
		parts.append("seed=%s" % seed_id)
	var seed_status := String(choice.get("questSeedStatus", ""))
	if seed_status != "":
		parts.append("seedStatus=%s" % seed_status)
	var effect_names: Array[String] = []
	for effect in choice.get("effects", []):
		if typeof(effect) == TYPE_DICTIONARY:
			effect_names.append(String((effect as Dictionary).get("kind", "")))
	if not effect_names.is_empty():
		parts.append("effects=%s" % ", ".join(effect_names))
	return " | ".join(parts)

func _route_target_downstream_text(snapshot: Dictionary) -> String:
	var placement := _selected_route_target_placement()
	var target_type := String(placement.get("type", ""))
	if target_type == "npc_service":
		var services := _route_target_npc_services(placement)
		if services.is_empty():
			return String(snapshot.get("routeHighlightedPlacementDownstream", "-"))
		var service := services[clamp(current_route_target_service_index, 0, services.size() - 1)]
		var text := "Highlighted downstream: Selected service: %s:%s" % [str(service.get("type", "")), str(service.get("label", ""))]
		var opens_service: Variant = service.get("opensService", {})
		var opens_kind := ""
		var opens_id := ""
		if typeof(opens_service) == TYPE_DICTIONARY:
			opens_kind = String((opens_service as Dictionary).get("kind", ""))
			opens_id = String((opens_service as Dictionary).get("serviceId", ""))
		else:
			opens_kind = String(opens_service)
			opens_id = String(service.get("opensServiceId", ""))
		if opens_kind != "" or opens_id != "":
			text += " | opens %s/%s" % [opens_kind, opens_id]
		return text
	if ["event", "rest", "trap"].has(target_type):
		return "Highlighted downstream: %s | %s" % [
			_route_target_selected_event_step_text(snapshot),
			_route_target_selected_event_choice_text(snapshot)
		]
	return String(snapshot.get("routeHighlightedPlacementDownstream", "-"))

func _parse_route_highlight_property(text: String, prefix: String, suffix: String) -> String:
	if prefix != "" and text.contains(prefix):
		var start := text.find(prefix) + prefix.length()
		var end := text.length()
		if suffix != "":
			var suffix_index := text.find(suffix, start)
			if suffix_index >= 0:
				end = suffix_index
		return text.substr(start, end - start).strip_edges()
	return ""

func smoke_set_selected_map(map_id: String) -> void:
	selected_map_id = map_id
	for index in map_entries.size():
		if String(map_entries[index].get("id", "")) == map_id:
			map_option.select(index)
			break
	refresh_summary()

func smoke_set_route_preview_entry(label: String) -> bool:
	for index in route_preview_entries.size():
		if String(route_preview_entries[index].get("label", "")) == label:
			route_preview_option.select(index)
			_reset_route_target_preview_state()
			_refresh_route_target_controls()
			_refresh_route_preview_detail()
			return true
	return false

func smoke_set_route_target_service_index(index: int) -> bool:
	if route_target_service_option == null or route_target_service_option.disabled:
		return false
	if index < 0 or index >= route_target_service_option.item_count:
		return false
	route_target_service_option.select(index)
	_on_route_target_service_selected(index)
	return true

func smoke_set_route_target_event_step_id(step_id: String) -> bool:
	for index in route_target_event_step_option.item_count:
		var text := route_target_event_step_option.get_item_text(index)
		if text.begins_with("%s:" % step_id):
			route_target_event_step_option.select(index)
			_on_route_target_event_step_selected(index)
			return true
	return false

func smoke_set_route_target_event_choice_index(index: int) -> bool:
	if route_target_event_choice_option == null or route_target_event_choice_option.disabled:
		return false
	if index < 0 or index >= route_target_event_choice_option.item_count:
		return false
	route_target_event_choice_option.select(index)
	_on_route_target_event_choice_selected(index)
	return true

func smoke_get_summary_text() -> String:
	return summary_label.text if summary_label != null else ""

func smoke_get_route_preview_detail_text() -> String:
	return route_preview_detail_label.text if route_preview_detail_label != null else ""

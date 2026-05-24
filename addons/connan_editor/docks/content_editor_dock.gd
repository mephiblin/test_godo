@tool
extends VBoxContainer

const ContentTools = preload("res://scripts/editor/content_tools.gd")
const PLACEMENT_REFERENCE_SOURCES := {
	"targetRoute": {"source": "static", "options": ["town", "dungeon"]},
	"targetMapId": {"source": "maps"},
	"eventId": {"source": "definitions", "kind": "events"},
	"npcId": {"source": "definitions", "kind": "npcs"},
	"lootTableId": {"source": "definitions", "kind": "loot_tables"},
	"monsterId": {"source": "definitions", "kind": "monsters"},
	"encounterId": {"source": "definitions", "kind": "encounters"},
	"itemId": {"source": "definitions", "kind": "items"},
	"vendorId": {"source": "definitions", "kind": "vendors"}
}

var plugin: EditorPlugin
var kind_option: OptionButton
var entry_list: ItemList
var fields_box: VBoxContainer
var status_label: RichTextLabel
var current_kind := "monsters"
var current_row_id := ""
var definitions_cache: Dictionary = {}
var editors: Dictionary = {}
var map_option: OptionButton
var map_entries: Array[Dictionary] = []
var placement_option: OptionButton
var placement_fields_box: VBoxContainer
var placement_affordance_box: VBoxContainer
var placement_editors: Dictionary = {}
var current_placement_id := ""
var map_fields_box: VBoxContainer
var map_editors: Dictionary = {}
var map_grid_container: GridContainer
var grid_mode_option: OptionButton
var current_grid_mode := "floor"
var current_map_cells: Array[String] = []
var current_map_start := Vector2i.ZERO
var current_map_placements: Array[Dictionary] = []
var current_grid_cursor := Vector2i.ZERO
var placement_type_option: OptionButton
var current_preview_event_step_id := ""
var current_preview_event_choice_index := 0
var current_preview_npc_service_index := 0
var current_preview_route_target_placement_id := ""

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_reload()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "Connan Content Editor"
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)

	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	kind_option = OptionButton.new()
	for kind in ContentTools.EDITABLE_KINDS:
		kind_option.add_item(kind)
	kind_option.item_selected.connect(_on_kind_selected)
	toolbar.add_child(kind_option)

	var reload_button := Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(_reload)
	toolbar.add_child(reload_button)

	var validate_button := Button.new()
	validate_button.text = "Validate"
	validate_button.pressed.connect(_validate)
	toolbar.add_child(validate_button)

	var export_button := Button.new()
	export_button.text = "Export Manifest"
	export_button.pressed.connect(_export_manifest)
	toolbar.add_child(export_button)

	var bundle_button := Button.new()
	bundle_button.text = "Build Bundle"
	bundle_button.pressed.connect(_build_bundle)
	toolbar.add_child(bundle_button)

	var map_button := Button.new()
	map_button.text = "Validate Maps"
	map_button.pressed.connect(_validate_maps)
	toolbar.add_child(map_button)

	var preview_button := Button.new()
	preview_button.text = "Preview Dungeon Build"
	preview_button.pressed.connect(_preview_dungeon_build)
	toolbar.add_child(preview_button)

	map_option = OptionButton.new()
	map_option.item_selected.connect(_on_map_selected)
	toolbar.add_child(map_option)

	placement_option = OptionButton.new()
	placement_option.custom_minimum_size = Vector2(180, 0)
	placement_option.item_selected.connect(_on_placement_selected)
	toolbar.add_child(placement_option)

	var play_town_button := Button.new()
	play_town_button.text = "Play Selected"
	play_town_button.pressed.connect(_play_selected_map)
	toolbar.add_child(play_town_button)

	var play_dungeon_button := Button.new()
	play_dungeon_button.text = "Play Selected Compiled"
	play_dungeon_button.pressed.connect(_play_selected_compiled)
	toolbar.add_child(play_dungeon_button)

	var play_dungeon_authored_button := Button.new()
	play_dungeon_authored_button.text = "Play Selected Authored"
	play_dungeon_authored_button.pressed.connect(_play_selected_authored)
	toolbar.add_child(play_dungeon_authored_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	entry_list = ItemList.new()
	entry_list.custom_minimum_size = Vector2(220, 360)
	entry_list.item_selected.connect(_on_entry_selected)
	split.add_child(entry_list)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)

	fields_box = VBoxContainer.new()
	fields_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(fields_box)

	var placement_title := Label.new()
	placement_title.text = "Selected Map Placement"
	placement_title.add_theme_font_size_override("font_size", 16)
	add_child(placement_title)

	var placement_scroll := ScrollContainer.new()
	placement_scroll.custom_minimum_size = Vector2(0, 220)
	placement_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(placement_scroll)

	placement_fields_box = VBoxContainer.new()
	placement_fields_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement_fields_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placement_scroll.add_child(placement_fields_box)

	placement_affordance_box = VBoxContainer.new()
	placement_affordance_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(placement_affordance_box)

	var map_title := Label.new()
	map_title.text = "Selected Map Structure"
	map_title.add_theme_font_size_override("font_size", 16)
	add_child(map_title)

	var map_scroll := ScrollContainer.new()
	map_scroll.custom_minimum_size = Vector2(0, 220)
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(map_scroll)

	map_fields_box = VBoxContainer.new()
	map_fields_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_fields_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_scroll.add_child(map_fields_box)

	var grid_toolbar := HBoxContainer.new()
	add_child(grid_toolbar)

	var grid_label := Label.new()
	grid_label.text = "Grid Edit Mode"
	grid_toolbar.add_child(grid_label)

	grid_mode_option = OptionButton.new()
	grid_mode_option.add_item("floor")
	grid_mode_option.add_item("wall")
	grid_mode_option.add_item("start")
	grid_mode_option.add_item("placement")
	grid_mode_option.item_selected.connect(_on_grid_mode_selected)
	grid_toolbar.add_child(grid_mode_option)

	placement_type_option = OptionButton.new()
	for placement_type in ["loot", "rest", "field_monster", "event", "npc_service", "stairs"]:
		placement_type_option.add_item(placement_type)
	grid_toolbar.add_child(placement_type_option)

	var add_placement_button := Button.new()
	add_placement_button.text = "Add Placement"
	add_placement_button.pressed.connect(_add_placement_at_cursor)
	grid_toolbar.add_child(add_placement_button)

	var delete_placement_button := Button.new()
	delete_placement_button.text = "Delete Placement"
	delete_placement_button.pressed.connect(_delete_selected_placement)
	grid_toolbar.add_child(delete_placement_button)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.custom_minimum_size = Vector2(0, 180)
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(grid_scroll)

	map_grid_container = GridContainer.new()
	map_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(map_grid_container)

	var save_button := Button.new()
	save_button.text = "Save Row"
	save_button.pressed.connect(_save_current)
	add_child(save_button)

	var save_placement_button := Button.new()
	save_placement_button.text = "Save Placement"
	save_placement_button.pressed.connect(_save_current_placement)
	add_child(save_placement_button)

	var save_map_button := Button.new()
	save_map_button.text = "Save Map"
	save_map_button.pressed.connect(_save_current_map)
	add_child(save_map_button)

	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.custom_minimum_size = Vector2(0, 100)
	add_child(status_label)

func _reload() -> void:
	definitions_cache = ContentTools.load_definitions()
	_refresh_map_option()
	_refresh_list()
	_validate()

func _refresh_map_option() -> void:
	map_entries = ContentTools.list_map_entries()
	map_option.clear()
	for entry in map_entries:
		var map_id := String(entry.get("id", ""))
		var kind := String(entry.get("kind", ""))
		map_option.add_item("%s (%s)" % [map_id, kind])
	_refresh_placement_option()

func _refresh_placement_option() -> void:
	if placement_option == null:
		return
	placement_option.clear()
	placement_editors.clear()
	current_placement_id = ""
	for child in placement_fields_box.get_children():
		child.queue_free()
	for child in placement_affordance_box.get_children():
		child.queue_free()
	var map_id := _selected_map_id()
	if map_id == "":
		return
	var placements := ContentTools.list_map_placements(map_id)
	for placement in placements:
		placement_option.add_item("%s (%s)" % [
			String(placement.get("id", "")),
			String(placement.get("type", ""))
		])
	if placements.size() > 0:
		placement_option.select(0)
		_on_placement_selected(0)
	_refresh_map_editor()

func _refresh_map_editor() -> void:
	map_editors.clear()
	for child in map_fields_box.get_children():
		child.queue_free()
	for child in map_grid_container.get_children():
		child.queue_free()
	current_map_cells.clear()
	current_map_placements.clear()
	var map_id := _selected_map_id()
	if map_id == "":
		return
	var map_data := ContentTools.load_map_data(map_id)
	for key in map_data.keys():
		if key in ["placements", "cells", "start"]:
			continue
		var label := Label.new()
		label.text = "%s (%s)" % [str(key), _value_type_name(map_data[key])]
		map_fields_box.add_child(label)
		var value: Variant = map_data[key]
		var spec := _build_editor_for_value(value)
		map_fields_box.add_child(spec["control"])
		map_editors[key] = spec
	current_map_cells.clear()
	for row in map_data.get("cells", []):
		current_map_cells.append(String(row))
	var start: Array = map_data.get("start", [0, 0])
	current_map_start = Vector2i(int(start[0]), int(start[1]))
	current_grid_cursor = current_map_start
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		current_map_placements.append((placement as Dictionary).duplicate(true))
	_rebuild_map_grid()

func _refresh_list() -> void:
	entry_list.clear()
	editors.clear()
	current_row_id = ""
	for child in fields_box.get_children():
		child.queue_free()
	var rows: Array = definitions_cache.get(current_kind, [])
	for row in rows:
		entry_list.add_item(String(row.get("id", "")))
	if rows.size() > 0:
		entry_list.select(0)
		_on_entry_selected(0)

func _on_kind_selected(index: int) -> void:
	current_kind = kind_option.get_item_text(index)
	_refresh_list()

func _on_map_selected(_index: int) -> void:
	_refresh_placement_option()
	_validate()

func _on_entry_selected(index: int) -> void:
	var rows: Array = definitions_cache.get(current_kind, [])
	if index < 0 or index >= rows.size():
		return
	var row: Dictionary = rows[index]
	current_row_id = String(row.get("id", ""))
	editors.clear()
	for child in fields_box.get_children():
		child.queue_free()
	for key in row.keys():
		var label := Label.new()
		label.text = "%s (%s)" % [str(key), _value_type_name(row[key])]
		fields_box.add_child(label)
		var value: Variant = row[key]
		var spec := _build_editor_for_value(value)
		fields_box.add_child(spec["control"])
		editors[key] = spec

func _on_placement_selected(index: int) -> void:
	var placements := ContentTools.list_map_placements(_selected_map_id())
	if index < 0 or index >= placements.size():
		return
	var placement: Dictionary = placements[index]
	_show_placement_editor(placement)

func _collect_current_row_result() -> Dictionary:
	return _collect_editor_row_result(editors)

func _save_current() -> void:
	if current_row_id == "":
		return
	var collect_result := _collect_current_row_result()
	var collect_errors: Array = collect_result.get("errors", [])
	if not collect_errors.is_empty():
		status_label.text = "[b]Edit Parse Failed[/b]\n%s" % "\n".join(collect_errors)
		return
	var result := ContentTools.save_definition_row(current_kind, current_row_id, collect_result.get("row", {}))
	if bool(result.get("ok", false)):
		if plugin != null and plugin.has_method("refresh_runtime_content"):
			plugin.refresh_runtime_content()
		status_label.text = "[b]Saved[/b] %s / %s\n[b]Selected Map[/b] %s" % [current_kind, current_row_id, _selected_map_id()]
		_reload()
	else:
		status_label.text = "[b]Validation Failed[/b] %s / %s\n%s" % [current_kind, current_row_id, "\n".join(result.get("errors", []))]

func _save_current_placement() -> void:
	if current_placement_id == "":
		return
	var collect_result := _collect_editor_row_result(placement_editors)
	var collect_errors: Array = collect_result.get("errors", [])
	if not collect_errors.is_empty():
		status_label.text = "[b]Placement Parse Failed[/b] %s / %s\n%s" % [
			_selected_map_id(),
			current_placement_id,
			"\n".join(collect_errors)
		]
		return
	var row_data: Dictionary = collect_result.get("row", {})
	var result := ContentTools.save_map_placement(_selected_map_id(), current_placement_id, row_data)
	if bool(result.get("ok", false)):
		_sync_current_placement_cache(row_data)
		if plugin != null and plugin.has_method("refresh_runtime_content"):
			plugin.refresh_runtime_content()
		status_label.text = "[b]Placement Saved[/b] %s / %s" % [_selected_map_id(), current_placement_id]
		_refresh_placement_option()
	else:
		status_label.text = "[b]Placement Validation Failed[/b] %s / %s\n%s" % [
			_selected_map_id(),
			current_placement_id,
			"\n".join(result.get("errors", []))
		]

func _save_current_map() -> void:
	var map_id := _selected_map_id()
	if map_id == "":
		return
	var existing_map := ContentTools.load_map_data(map_id)
	if existing_map.is_empty():
		return
	var collect_result := _collect_editor_row_result(map_editors)
	var collect_errors: Array = collect_result.get("errors", [])
	if not collect_errors.is_empty():
		status_label.text = "[b]Map Parse Failed[/b] %s\n%s" % [map_id, "\n".join(collect_errors)]
		return
	var new_map := existing_map.duplicate(true)
	for key in collect_result.get("row", {}).keys():
		new_map[key] = collect_result.get("row", {})[key]
	new_map["cells"] = current_map_cells.duplicate(true)
	new_map["start"] = [current_map_start.x, current_map_start.y]
	new_map["placements"] = current_map_placements.duplicate(true)
	var result := ContentTools.save_map_data(map_id, new_map)
	if bool(result.get("ok", false)):
		if plugin != null and plugin.has_method("refresh_runtime_content"):
			plugin.refresh_runtime_content()
		status_label.text = "[b]Map Saved[/b] %s" % map_id
		_refresh_map_editor()
	else:
		status_label.text = "[b]Map Validation Failed[/b] %s\n%s" % [map_id, "\n".join(result.get("errors", []))]

func _on_grid_mode_selected(index: int) -> void:
	current_grid_mode = grid_mode_option.get_item_text(index)

func _rebuild_map_grid() -> void:
	for child in map_grid_container.get_children():
		child.queue_free()
	if current_map_cells.is_empty():
		return
	var width := String(current_map_cells[0]).length()
	map_grid_container.columns = maxi(width, 1)
	for y in range(current_map_cells.size()):
		var row := String(current_map_cells[y])
		for x in range(row.length()):
			var button := Button.new()
			button.custom_minimum_size = Vector2(26, 26)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.pressed.connect(_on_grid_cell_pressed.bind(x, y))
			map_grid_container.add_child(button)
	_refresh_grid_buttons()

func _refresh_grid_buttons() -> void:
	if current_map_cells.is_empty():
		return
	var index := 0
	for y in range(current_map_cells.size()):
		var row := String(current_map_cells[y])
		for x in range(row.length()):
			var button := map_grid_container.get_child(index) as Button
			var token := row[x]
			var is_start := current_map_start == Vector2i(x, y)
			var placement_marker := _grid_placement_marker(Vector2i(x, y))
			if is_start and placement_marker != "":
				button.text = "S/%s" % placement_marker
			elif is_start:
				button.text = "S"
			elif placement_marker != "":
				button.text = placement_marker
			else:
				button.text = token
			button.tooltip_text = "%d,%d %s" % [x, y, current_grid_mode]
			if current_grid_cursor == Vector2i(x, y):
				button.modulate = Color(0.82, 0.9, 1.0, 1.0)
			elif _selected_placement_cell() == Vector2i(x, y):
				button.modulate = Color(1.0, 0.85, 0.45, 1.0)
			elif is_start:
				button.modulate = Color(0.75, 1.0, 0.75, 1.0)
			elif token == "#":
				button.modulate = Color(0.6, 0.6, 0.6, 1.0)
			else:
				button.modulate = Color(1.0, 1.0, 1.0, 1.0)
			index += 1

func _on_grid_cell_pressed(x: int, y: int) -> void:
	current_grid_cursor = Vector2i(x, y)
	_apply_grid_edit(Vector2i(x, y))

func _apply_grid_edit(cell: Vector2i) -> void:
	if cell.y < 0 or cell.y >= current_map_cells.size():
		return
	var row := String(current_map_cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return
	match current_grid_mode:
		"wall":
			current_map_cells[cell.y] = _replace_row_char(row, cell.x, "#")
			if current_map_start == cell:
				current_map_start = Vector2i.ZERO
		"floor":
			current_map_cells[cell.y] = _replace_row_char(row, cell.x, ".")
		"start":
			if row[cell.x] == "#":
				current_map_cells[cell.y] = _replace_row_char(row, cell.x, ".")
			current_map_start = cell
		"placement":
			if row[cell.x] == "#":
				current_map_cells[cell.y] = _replace_row_char(row, cell.x, ".")
			_move_selected_placement(cell)
	_refresh_grid_buttons()

func _replace_row_char(row: String, index: int, token: String) -> String:
	return row.substr(0, index) + token + row.substr(index + 1)

func smoke_select_map(map_id: String) -> void:
	for index in range(map_entries.size()):
		if String(map_entries[index].get("id", "")) != map_id:
			continue
		map_option.select(index)
		_on_map_selected(index)
		return

func smoke_set_grid_mode(mode: String) -> void:
	for index in range(grid_mode_option.item_count):
		if grid_mode_option.get_item_text(index) != mode:
			continue
		grid_mode_option.select(index)
		_on_grid_mode_selected(index)
		return

func smoke_select_placement(placement_id: String) -> void:
	for index in range(placement_option.item_count):
		var label := placement_option.get_item_text(index)
		if not label.begins_with(placement_id):
			continue
		placement_option.select(index)
		_on_placement_selected(index)
		return

func smoke_apply_grid_edit(x: int, y: int) -> void:
	_apply_grid_edit(Vector2i(x, y))

func smoke_commit_current_map() -> Dictionary:
	var map_id := _selected_map_id()
	var existing_map := ContentTools.load_map_data(map_id)
	var collect_result := _collect_editor_row_result(map_editors)
	var new_map := existing_map.duplicate(true)
	for key in collect_result.get("row", {}).keys():
		new_map[key] = collect_result.get("row", {})[key]
	new_map["cells"] = current_map_cells.duplicate(true)
	new_map["start"] = [current_map_start.x, current_map_start.y]
	new_map["placements"] = current_map_placements.duplicate(true)
	return ContentTools.save_map_data(map_id, new_map)

func smoke_commit_current_placement() -> Dictionary:
	if current_placement_id == "":
		return {"ok": false, "errors": ["No selected placement."]}
	var collect_result := _collect_editor_row_result(placement_editors)
	var collect_errors: Array = collect_result.get("errors", [])
	if not collect_errors.is_empty():
		return {"ok": false, "errors": collect_errors}
	var row_data: Dictionary = collect_result.get("row", {})
	var result := ContentTools.save_map_placement(_selected_map_id(), current_placement_id, row_data)
	if bool(result.get("ok", false)):
		_sync_current_placement_cache(row_data)
	return result

func smoke_create_placement(placement_type: String, x: int, y: int) -> Dictionary:
	smoke_set_grid_mode("placement")
	current_grid_cursor = Vector2i(x, y)
	for index in range(placement_type_option.item_count):
		if placement_type_option.get_item_text(index) != placement_type:
			continue
		placement_type_option.select(index)
		break
	return _create_placement_at_cursor()

func smoke_delete_selected_placement() -> Dictionary:
	return _delete_selected_placement()

func smoke_set_current_placement_field(key: String, value: Variant) -> bool:
	if not placement_editors.has(key):
		return false
	var spec: Dictionary = placement_editors.get(key, {})
	var control: Control = spec.get("control")
	if String(spec.get("editor_kind", "")) == "reference_option":
		return _set_reference_option_value(spec, value)
	var value_type: int = int(spec.get("value_type", TYPE_STRING))
	match value_type:
		TYPE_ARRAY, TYPE_DICTIONARY:
			if control is TextEdit:
				(control as TextEdit).text = JSON.stringify(value, "\t")
				return true
		TYPE_BOOL:
			if control is CheckBox:
				(control as CheckBox).button_pressed = bool(value)
				return true
		TYPE_INT, TYPE_FLOAT:
			if control is SpinBox:
				(control as SpinBox).value = float(value)
				return true
		_:
			if control is LineEdit:
				(control as LineEdit).text = str(value)
				return true
	return false

func smoke_get_current_placement_affordance_snapshot() -> Dictionary:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return {}
	return {
		"type": String(placement.get("type", "")),
		"summary": _placement_affordance_summary(placement),
		"routeTargets": _placement_route_target_ids(placement),
		"routeRequirements": _route_requirement_text(placement),
		"routeTargetPreview": _route_target_preview_text(String(placement.get("targetMapId", ""))),
		"routeTargetMiniGrid": _route_target_minigrid_text(String(placement.get("targetMapId", ""))),
		"routeHighlightedPlacement": _route_highlighted_placement_preview(String(placement.get("targetMapId", ""))),
		"routeHighlightedPlacementDetail": _route_highlighted_placement_detail_preview(String(placement.get("targetMapId", ""))),
		"routeHighlightedPlacementContract": _route_highlighted_placement_contract_preview(String(placement.get("targetMapId", ""))),
		"routeHighlightedPlacementDownstream": _route_highlighted_placement_downstream_preview(String(placement.get("targetMapId", ""))),
		"routeTargetSelectedEventStep": _route_target_selected_event_step_preview(String(placement.get("targetMapId", ""))),
		"routeTargetSelectedEventChoice": _route_target_selected_event_choice_preview(String(placement.get("targetMapId", ""))),
		"routeTargetSelectedNpcService": _route_target_selected_npc_service_preview(String(placement.get("targetMapId", ""))),
		"eventPreview": _event_preview_text(String(placement.get("eventId", ""))),
		"eventChoices": _event_choice_preview(String(placement.get("eventId", ""))),
		"eventEffects": _event_effect_preview(String(placement.get("eventId", ""))),
		"eventGraph": _event_graph_preview(String(placement.get("eventId", ""))),
		"selectedEventStep": _event_selected_step_preview(String(placement.get("eventId", ""))),
		"selectedEventChoice": _event_selected_choice_preview(String(placement.get("eventId", ""))),
		"npcPreview": _npc_preview_text(String(placement.get("npcId", ""))),
		"npcServices": _npc_service_preview(String(placement.get("npcId", ""))),
		"npcServiceDetails": _npc_service_detail_preview(String(placement.get("npcId", ""))),
		"selectedNpcService": _npc_selected_service_preview(String(placement.get("npcId", ""))),
		"opensServicePreview": _npc_opens_service_preview(String(placement.get("npcId", ""))),
		"opensServiceSurface": _npc_opens_service_surface_preview(String(placement.get("npcId", ""))),
		"opensServiceCatalog": _npc_opens_service_catalog_preview(String(placement.get("npcId", ""))),
		"opensServiceStock": _npc_opens_service_stock_preview(String(placement.get("npcId", "")))
	}

func smoke_set_preview_event_step(step_id: String) -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	var event_id := String(placement.get("eventId", ""))
	for step in _event_step_options(event_id):
		if String(step.get("id", "")) != step_id:
			continue
		current_preview_event_step_id = step_id
		current_preview_event_choice_index = 0
		_render_placement_affordances(placement)
		return true
	return false

func smoke_set_preview_event_choice_index(index: int) -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	var event_id := String(placement.get("eventId", ""))
	var step := _selected_event_step(event_id)
	if step.is_empty():
		return false
	var option_count := _event_step_choice_options(step).size()
	if index < 0 or index >= option_count:
		return false
	current_preview_event_choice_index = index
	_render_placement_affordances(placement)
	return true

func smoke_set_preview_npc_service_index(index: int) -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	var npc_id := String(placement.get("npcId", ""))
	var services := _npc_service_rows(npc_id)
	if index < 0 or index >= services.size():
		return false
	current_preview_npc_service_index = index
	_render_placement_affordances(placement)
	return true

func smoke_apply_selected_event_contract() -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	return _apply_selected_event_contract(placement)

func smoke_apply_selected_npc_service_contract() -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	return _apply_selected_npc_service_contract(placement)

func smoke_set_preview_route_target_placement(placement_id: String) -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	var target_map_id := String(placement.get("targetMapId", ""))
	for row in ContentTools.list_map_placements(target_map_id):
		if String(row.get("id", "")) != placement_id:
			continue
		current_preview_route_target_placement_id = placement_id
		_render_placement_affordances(placement)
		return true
	return false

func smoke_set_route_target_npc_service_index(index: int) -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	var target_map_id := String(placement.get("targetMapId", ""))
	var target_placement := _route_highlighted_target_placement(target_map_id)
	if target_placement.is_empty():
		return false
	if String(target_placement.get("type", "")) != "npc_service":
		return false
	var services := _npc_service_rows(String(target_placement.get("npcId", "")))
	if index < 0 or index >= services.size():
		return false
	current_preview_npc_service_index = index
	_render_placement_affordances(placement)
	return true

func smoke_set_route_target_event_step(step_id: String) -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	var target_map_id := String(placement.get("targetMapId", ""))
	var target_placement := _route_highlighted_target_placement(target_map_id)
	if target_placement.is_empty():
		return false
	if not ["event", "rest", "trap"].has(String(target_placement.get("type", ""))):
		return false
	var event_id := String(target_placement.get("eventId", ""))
	for step in _event_step_options(event_id):
		if String(step.get("id", "")) != step_id:
			continue
		current_preview_event_step_id = step_id
		current_preview_event_choice_index = 0
		_render_placement_affordances(placement)
		return true
	return false

func smoke_set_route_target_event_choice_index(index: int) -> bool:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return false
	var target_map_id := String(placement.get("targetMapId", ""))
	var target_placement := _route_highlighted_target_placement(target_map_id)
	if target_placement.is_empty():
		return false
	if not ["event", "rest", "trap"].has(String(target_placement.get("type", ""))):
		return false
	var event_id := String(target_placement.get("eventId", ""))
	var step := _selected_event_step(event_id)
	if step.is_empty():
		return false
	var option_count := _event_step_choice_options(step).size()
	if index < 0 or index >= option_count:
		return false
	current_preview_event_choice_index = index
	_render_placement_affordances(placement)
	return true

func _build_placement_editor_for_key(key: String, value: Variant, placement: Dictionary = {}) -> Dictionary:
	if typeof(value) == TYPE_STRING and PLACEMENT_REFERENCE_SOURCES.has(key):
		var options := _placement_reference_options(key, placement)
		if not options.is_empty():
			return _build_reference_editor(key, String(value), options)
	return _build_editor_for_value(value)

func _show_placement_editor(placement: Dictionary) -> void:
	current_placement_id = String(placement.get("id", ""))
	current_preview_event_step_id = ""
	current_preview_event_choice_index = 0
	current_preview_npc_service_index = 0
	current_preview_route_target_placement_id = ""
	placement_editors.clear()
	for child in placement_fields_box.get_children():
		child.queue_free()
	for child in placement_affordance_box.get_children():
		child.queue_free()
	for key in placement.keys():
		var label := Label.new()
		label.text = "%s (%s)" % [str(key), _value_type_name(placement[key])]
		placement_fields_box.add_child(label)
		var value: Variant = placement[key]
		var spec := _build_placement_editor_for_key(key, value, placement)
		placement_fields_box.add_child(spec["control"])
		placement_editors[key] = spec
	_render_placement_affordances(placement)

func _placement_reference_options(key: String, placement: Dictionary = {}) -> Array[String]:
	var source_spec: Dictionary = PLACEMENT_REFERENCE_SOURCES.get(key, {})
	if source_spec.is_empty():
		return []
	var source := String(source_spec.get("source", ""))
	var options: Array[String] = []
	match source:
		"static":
			for option in source_spec.get("options", []):
				options.append(String(option))
		"maps":
			var allowed_kind := ""
			if key == "targetMapId":
				allowed_kind = _route_target_kind(String(placement.get("targetRoute", "")))
			for entry in map_entries:
				var map_id := String(entry.get("id", ""))
				var map_kind := String(entry.get("kind", ""))
				if map_id == "":
					continue
				if allowed_kind != "" and map_kind != allowed_kind:
					continue
				options.append(map_id)
		"definitions":
			var kind := String(source_spec.get("kind", ""))
			for row in definitions_cache.get(kind, []):
				if typeof(row) != TYPE_DICTIONARY:
					continue
				var row_id := String(row.get("id", ""))
				if row_id != "":
					options.append(row_id)
	return options

func _build_reference_editor(key: String, value: String, options: Array[String]) -> Dictionary:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(280, 0)
	var seen := {}
	if value != "":
		picker.add_item(value)
		seen[value] = true
	for option in options:
		if option == "" or seen.has(option):
			continue
		picker.add_item(option)
		seen[option] = true
	var selected_index := 0
	for index in range(picker.item_count):
		if picker.get_item_text(index) == value:
			selected_index = index
			break
	picker.select(selected_index)
	picker.item_selected.connect(_on_reference_option_selected.bind(key, picker))
	return {
		"control": picker,
		"value_type": TYPE_STRING,
		"original_value": value,
		"editor_kind": "reference_option",
		"editor_key": key
	}

func _set_reference_option_value(spec: Dictionary, value: Variant) -> bool:
	var control: Control = spec.get("control")
	if not control is OptionButton:
		return false
	var picker := control as OptionButton
	var value_text := str(value)
	for index in range(picker.item_count):
		if picker.get_item_text(index) != value_text:
			continue
		picker.select(index)
		if String(spec.get("editor_key", "")) == "targetRoute":
			_on_target_route_changed(value_text)
		return true
	return false

func _render_placement_affordances(placement: Dictionary) -> void:
	for child in placement_affordance_box.get_children():
		child.queue_free()
	if placement.is_empty():
		return
	var title := Label.new()
	title.text = "Placement Preview"
	title.add_theme_font_size_override("font_size", 15)
	placement_affordance_box.add_child(title)

	var summary := RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.fit_content = true
	summary.custom_minimum_size = Vector2(0, 70)
	summary.text = _placement_affordance_summary(placement)
	placement_affordance_box.add_child(summary)
	_add_guided_placement_fields(placement)
	_add_placement_quick_actions(placement)

	var placement_type := String(placement.get("type", ""))
	match placement_type:
		"stairs", "gate":
			var route_hint := Label.new()
			route_hint.text = "Route targets: %s" % ", ".join(_placement_route_target_ids(placement))
			placement_affordance_box.add_child(route_hint)
			var route_requirements := Label.new()
			route_requirements.text = _route_requirement_text(placement)
			route_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(route_requirements)
			var route_target_preview := Label.new()
			route_target_preview.text = _route_target_preview_text(String(placement.get("targetMapId", "")))
			route_target_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(route_target_preview)
			var route_target_minigrid := Label.new()
			route_target_minigrid.text = _route_target_minigrid_text(String(placement.get("targetMapId", "")))
			route_target_minigrid.autowrap_mode = TextServer.AUTOWRAP_OFF
			placement_affordance_box.add_child(route_target_minigrid)
			var route_target_picker := _build_route_target_placement_picker(String(placement.get("targetMapId", "")))
			if route_target_picker != null:
				placement_affordance_box.add_child(route_target_picker)
			var route_highlight := Label.new()
			route_highlight.text = _route_highlighted_placement_preview(String(placement.get("targetMapId", "")))
			route_highlight.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(route_highlight)
			var route_highlight_detail := Label.new()
			route_highlight_detail.text = _route_highlighted_placement_detail_preview(String(placement.get("targetMapId", "")))
			route_highlight_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(route_highlight_detail)
			var route_highlight_contract := Label.new()
			route_highlight_contract.text = _route_highlighted_placement_contract_preview(String(placement.get("targetMapId", "")))
			route_highlight_contract.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(route_highlight_contract)
			var route_highlight_downstream := Label.new()
			route_highlight_downstream.text = _route_highlighted_placement_downstream_preview(String(placement.get("targetMapId", "")))
			route_highlight_downstream.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(route_highlight_downstream)
			var route_target_event_picker := _build_route_target_event_step_picker(String(placement.get("targetMapId", "")))
			if route_target_event_picker != null:
				placement_affordance_box.add_child(route_target_event_picker)
			var route_target_event_choice_picker := _build_route_target_event_choice_picker(String(placement.get("targetMapId", "")))
			if route_target_event_choice_picker != null:
				placement_affordance_box.add_child(route_target_event_choice_picker)
			var route_target_npc_picker := _build_route_target_npc_service_picker(String(placement.get("targetMapId", "")))
			if route_target_npc_picker != null:
				placement_affordance_box.add_child(route_target_npc_picker)
		"event", "rest", "trap":
			var event_preview := Label.new()
			event_preview.text = _event_preview_text(String(placement.get("eventId", "")))
			event_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(event_preview)
			var event_step_picker := _build_event_step_picker(String(placement.get("eventId", "")))
			if event_step_picker != null:
				placement_affordance_box.add_child(event_step_picker)
			var event_choices := Label.new()
			event_choices.text = _event_choice_preview(String(placement.get("eventId", "")))
			event_choices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(event_choices)
			var event_effects := Label.new()
			event_effects.text = _event_effect_preview(String(placement.get("eventId", "")))
			event_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(event_effects)
			var event_graph := Label.new()
			event_graph.text = _event_graph_preview(String(placement.get("eventId", "")))
			event_graph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(event_graph)
			var selected_event_step := Label.new()
			selected_event_step.text = _event_selected_step_preview(String(placement.get("eventId", "")))
			selected_event_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(selected_event_step)
			var event_choice_picker := _build_event_choice_picker(String(placement.get("eventId", "")))
			if event_choice_picker != null:
				placement_affordance_box.add_child(event_choice_picker)
			var selected_event_choice := Label.new()
			selected_event_choice.text = _event_selected_choice_preview(String(placement.get("eventId", "")))
			selected_event_choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(selected_event_choice)
			var event_contract_button := Button.new()
			event_contract_button.text = "Apply Selected Event Contract"
			event_contract_button.pressed.connect(func() -> void:
				_apply_selected_event_contract(placement)
			)
			placement_affordance_box.add_child(event_contract_button)
		"npc_service":
			var npc_preview := Label.new()
			npc_preview.text = _npc_preview_text(String(placement.get("npcId", "")))
			npc_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(npc_preview)
			var npc_service_picker := _build_npc_service_picker(String(placement.get("npcId", "")))
			if npc_service_picker != null:
				placement_affordance_box.add_child(npc_service_picker)
			var npc_services := Label.new()
			npc_services.text = _npc_service_preview(String(placement.get("npcId", "")))
			npc_services.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(npc_services)
			var npc_service_details := Label.new()
			npc_service_details.text = _npc_service_detail_preview(String(placement.get("npcId", "")))
			npc_service_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(npc_service_details)
			var selected_npc_service := Label.new()
			selected_npc_service.text = _npc_selected_service_preview(String(placement.get("npcId", "")))
			selected_npc_service.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(selected_npc_service)
			var opens_service_preview := Label.new()
			opens_service_preview.text = _npc_opens_service_preview(String(placement.get("npcId", "")))
			opens_service_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(opens_service_preview)
			var opens_service_surface := Label.new()
			opens_service_surface.text = _npc_opens_service_surface_preview(String(placement.get("npcId", "")))
			opens_service_surface.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(opens_service_surface)
			var opens_service_catalog := Label.new()
			opens_service_catalog.text = _npc_opens_service_catalog_preview(String(placement.get("npcId", "")))
			opens_service_catalog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(opens_service_catalog)
			var opens_service_stock := Label.new()
			opens_service_stock.text = _npc_opens_service_stock_preview(String(placement.get("npcId", "")))
			opens_service_stock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			placement_affordance_box.add_child(opens_service_stock)
			var npc_contract_button := Button.new()
			npc_contract_button.text = "Apply Selected Service Contract"
			npc_contract_button.pressed.connect(func() -> void:
				_apply_selected_npc_service_contract(placement)
			)
			placement_affordance_box.add_child(npc_contract_button)

func _placement_affordance_summary(placement: Dictionary) -> String:
	var placement_type := String(placement.get("type", ""))
	match placement_type:
		"stairs", "gate":
			return "[b]%s[/b]\nRoute [code]%s[/code] -> [code]%s[/code]" % [
				String(placement.get("label", placement.get("id", ""))),
				String(placement.get("targetRoute", "")),
				String(placement.get("targetMapId", ""))
			]
		"event", "rest", "trap":
			return "[b]%s[/b]\nEvent [code]%s[/code]" % [
				String(placement.get("label", placement.get("id", ""))),
				String(placement.get("eventId", ""))
			]
		"npc_service":
			return "[b]%s[/b]\nNPC [code]%s[/code]" % [
				String(placement.get("label", placement.get("id", ""))),
				String(placement.get("npcId", ""))
			]
		_:
			return "[b]%s[/b]\nType [code]%s[/code]" % [
				String(placement.get("label", placement.get("id", ""))),
				placement_type
			]

func _placement_route_target_ids(placement: Dictionary) -> Array[String]:
	var route := String(placement.get("targetRoute", ""))
	var target_kind := _route_target_kind(route)
	var targets: Array[String] = []
	for entry in map_entries:
		if target_kind != "" and String(entry.get("kind", "")) != target_kind:
			continue
		var map_id := String(entry.get("id", ""))
		if map_id != "":
			targets.append(map_id)
	return targets

func _route_target_kind(route: String) -> String:
	match route:
		"town":
			return "town"
		"dungeon":
			return "dungeon"
		_:
			return ""

func _event_preview_text(event_id: String) -> String:
	var event_row := _find_definition_row("events", event_id)
	if event_row.is_empty():
		return "Event preview unavailable."
	var usage: Dictionary = event_row.get("usage", {})
	var usage_mode := String(usage.get("mode", "single"))
	var interaction := String(event_row.get("interaction", "interact"))
	var step_count := 0
	for step in event_row.get("steps", []):
		if typeof(step) == TYPE_DICTIONARY:
			step_count += 1
	return "Event: %s | interaction=%s | usage=%s | steps=%d" % [
		String(event_row.get("name", event_id)),
		interaction,
		usage_mode,
		step_count
	]

func _event_choice_preview(event_id: String) -> String:
	var event_row := _find_definition_row("events", event_id)
	if event_row.is_empty():
		return "Choices: unavailable"
	var entry_step_id := String(event_row.get("entryStepId", ""))
	if entry_step_id == "":
		return "Choices: direct effects only"
	for step in event_row.get("steps", []):
		if typeof(step) != TYPE_DICTIONARY:
			continue
		if String(step.get("id", "")) != entry_step_id:
			continue
		var title := String(step.get("title", entry_step_id))
		var choice_labels: Array[String] = []
		for choice in step.get("choices", []):
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			choice_labels.append(String(choice.get("label", "")))
		if choice_labels.is_empty():
			return "Entry: %s | no choices" % title
		return "Entry: %s | choices=%s" % [title, " / ".join(choice_labels)]
	return "Choices: entry step not found"

func _event_effect_preview(event_id: String) -> String:
	var event_row := _find_definition_row("events", event_id)
	if event_row.is_empty():
		return "Effects: unavailable"
	var entry_step_id := String(event_row.get("entryStepId", ""))
	for step in event_row.get("steps", []):
		if typeof(step) != TYPE_DICTIONARY:
			continue
		if String(step.get("id", "")) != entry_step_id:
			continue
		var branch_labels: Array[String] = []
		for branch in step.get("branches", []):
			if typeof(branch) != TYPE_DICTIONARY:
				continue
			branch_labels.append(String(branch.get("label", "")))
		if not branch_labels.is_empty():
			return "Branches: %s" % " / ".join(branch_labels)
		var choice_effects: Array[String] = []
		for choice in step.get("choices", []):
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var effect_kinds: Array[String] = []
			for effect in choice.get("effects", []):
				if typeof(effect) != TYPE_DICTIONARY:
					continue
				effect_kinds.append(String(effect.get("kind", "")))
			if not effect_kinds.is_empty():
				choice_effects.append("%s -> %s" % [
					String(choice.get("label", "")),
					", ".join(effect_kinds)
				])
		if choice_effects.is_empty():
			return "Effects: entry step has no effect summary"
		return "Effects: %s" % " | ".join(choice_effects)
	var direct_effects: Array[String] = []
	for effect in event_row.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		direct_effects.append(String(effect.get("kind", "")))
	if direct_effects.is_empty():
		return "Effects: none"
	return "Effects: %s" % ", ".join(direct_effects)

func _event_graph_preview(event_id: String) -> String:
	var event_row := _find_definition_row("events", event_id)
	if event_row.is_empty():
		return "Graph: unavailable"
	var lines: Array[String] = []
	for step in event_row.get("steps", []):
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var step_id := String(step.get("id", ""))
		var targets: Array[String] = []
		for choice in step.get("choices", []):
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var next_step := String(choice.get("nextStepId", ""))
			if next_step != "":
				targets.append(next_step)
		for branch in step.get("branches", []):
			if typeof(branch) != TYPE_DICTIONARY:
				continue
			var next_branch := String(branch.get("nextStepId", ""))
			if next_branch != "":
				targets.append(next_branch)
		if targets.is_empty():
			lines.append("%s -> end" % step_id)
		else:
			lines.append("%s -> %s" % [step_id, ", ".join(targets)])
	if lines.is_empty():
		return "Graph: direct effect event"
	return "Graph: %s" % " | ".join(lines)

func _event_selected_step_preview(event_id: String) -> String:
	var step := _selected_event_step(event_id)
	if step.is_empty():
		return "Selected step: unavailable"
	return "Selected step: %s | %s" % [
		String(step.get("title", step.get("id", ""))),
		String(step.get("text", ""))
	]

func _event_selected_choice_preview(event_id: String) -> String:
	var step := _selected_event_step(event_id)
	if step.is_empty():
		return "Selected choice: unavailable"
	var options := _event_step_choice_options(step)
	if options.is_empty():
		return "Selected choice: unavailable"
	var index := mini(maxi(current_preview_event_choice_index, 0), options.size() - 1)
	var option: Dictionary = options[index]
	var parts: Array[String] = [
		"%s" % String(option.get("label", option.get("kind", "")))
	]
	var next_step_id := String(option.get("nextStepId", ""))
	if next_step_id != "":
		parts.append("next=%s" % next_step_id)
	var required_flag := String(option.get("requiredFlag", ""))
	if required_flag != "":
		parts.append("flag=%s" % required_flag)
	var required_seed_id := String(option.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		parts.append("seed=%s" % required_seed_id)
	var required_seed_status := String(option.get("requiredQuestSeedStatus", ""))
	if required_seed_status != "":
		parts.append("seedStatus=%s" % required_seed_status)
	var effect_kinds: Array[String] = []
	for effect in option.get("effects", []):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		effect_kinds.append(String(effect.get("kind", "")))
	if not effect_kinds.is_empty():
		parts.append("effects=%s" % ", ".join(effect_kinds))
	return "Selected choice: %s" % " | ".join(parts)

func _npc_preview_text(npc_id: String) -> String:
	var npc_row := _find_definition_row("npcs", npc_id)
	if npc_row.is_empty():
		return "NPC preview unavailable."
	var service_summaries: Array[String] = []
	for service in npc_row.get("services", []):
		if typeof(service) != TYPE_DICTIONARY:
			continue
		service_summaries.append("%s:%s" % [
			String(service.get("type", "")),
			String(service.get("label", ""))
		])
	var quest_seed_count := 0
	for seed in npc_row.get("questSeeds", []):
		if typeof(seed) == TYPE_DICTIONARY:
			quest_seed_count += 1
	return "NPC: %s | services=%s | questSeeds=%d" % [
		String(npc_row.get("name", npc_id)),
		", ".join(service_summaries),
		quest_seed_count
	]

func _npc_service_preview(npc_id: String) -> String:
	var npc_row := _find_definition_row("npcs", npc_id)
	if npc_row.is_empty():
		return "Service rows: unavailable"
	var lines: Array[String] = []
	for service in npc_row.get("services", []):
		if typeof(service) != TYPE_DICTIONARY:
			continue
		var line := "%s:%s" % [
			String(service.get("type", "")),
			String(service.get("label", ""))
		]
		var opens_service: Dictionary = service.get("opensService", {})
		if not opens_service.is_empty():
			line += " -> opens %s/%s" % [
				String(opens_service.get("kind", "")),
				String(opens_service.get("serviceId", ""))
			]
		var note := String(service.get("note", ""))
		if note != "":
			line += " | %s" % note
		lines.append(line)
	if lines.is_empty():
		return "Service rows: none"
	return "Service rows: %s" % " || ".join(lines)

func _npc_service_detail_preview(npc_id: String) -> String:
	var npc_row := _find_definition_row("npcs", npc_id)
	if npc_row.is_empty():
		return "Service detail: unavailable"
	var details: Array[String] = []
	for service in npc_row.get("services", []):
		if typeof(service) != TYPE_DICTIONARY:
			continue
		var row := "%s:%s" % [
			String(service.get("type", "")),
			String(service.get("label", ""))
		]
		var opens_service: Dictionary = service.get("opensService", {})
		if not opens_service.is_empty():
			row += " opens(%s/%s)" % [
				String(opens_service.get("kind", "")),
				String(opens_service.get("serviceId", ""))
			]
		var dialogue: Dictionary = service.get("dialogue", {})
		if not dialogue.is_empty():
			row += " dialogue(%s)" % String(dialogue.get("entryStepId", ""))
		details.append(row)
	if details.is_empty():
		return "Service detail: none"
	return "Service detail: %s" % " || ".join(details)

func _npc_selected_service_preview(npc_id: String) -> String:
	var services := _npc_service_rows(npc_id)
	if services.is_empty():
		return "Selected service: unavailable"
	var index := mini(maxi(current_preview_npc_service_index, 0), services.size() - 1)
	var service: Dictionary = services[index]
	var line := "%s:%s" % [
		String(service.get("type", "")),
		String(service.get("label", ""))
	]
	var opens_service: Dictionary = service.get("opensService", {})
	if not opens_service.is_empty():
		line += " | opens %s/%s" % [
			String(opens_service.get("kind", "")),
			String(opens_service.get("serviceId", ""))
		]
	var dialogue: Dictionary = service.get("dialogue", {})
	if not dialogue.is_empty():
		line += " | dialogue %s" % String(dialogue.get("entryStepId", ""))
	return "Selected service: %s" % line

func _npc_opens_service_preview(npc_id: String) -> String:
	var services := _npc_service_rows(npc_id)
	if services.is_empty():
		return "Opens service: unavailable"
	var index := mini(maxi(current_preview_npc_service_index, 0), services.size() - 1)
	var service: Dictionary = services[index]
	var opens_service: Dictionary = service.get("opensService", {})
	if opens_service.is_empty():
		return "Opens service: unavailable"
	var parts: Array[String] = [
		"%s/%s" % [
			String(opens_service.get("kind", "")),
			String(opens_service.get("serviceId", ""))
		]
	]
	for key in ["title", "catalogId", "currency", "note"]:
		var value_text := String(opens_service.get(key, ""))
		if value_text != "":
			parts.append("%s=%s" % [key, value_text])
	return "Opens service: %s" % " | ".join(parts)

func _npc_opens_service_surface_preview(npc_id: String) -> String:
	var services := _npc_service_rows(npc_id)
	if services.is_empty():
		return "Opens surface: unavailable"
	var index := mini(maxi(current_preview_npc_service_index, 0), services.size() - 1)
	var service: Dictionary = services[index]
	var opens_service: Dictionary = service.get("opensService", {})
	if opens_service.is_empty():
		return "Opens surface: unavailable"
	var kind := String(opens_service.get("kind", ""))
	match kind:
		"skill_shop":
			var parts: Array[String] = [
				"kind=skill_shop",
				"ui=Buy Skill, Refresh Stock"
			]
			var title := String(opens_service.get("title", ""))
			if title != "":
				parts.append("title=%s" % title)
			var catalog_id := String(opens_service.get("catalogId", ""))
			if catalog_id != "":
				parts.append("catalog=%s" % catalog_id)
			var currency := String(opens_service.get("currency", ""))
			if currency != "":
				parts.append("currency=%s" % currency)
			return "Opens surface: %s" % " | ".join(parts)
		"trade":
			return "Opens surface: kind=trade | ui=Buy Item"
		"heal":
			return "Opens surface: kind=heal | ui=Heal Party"
		_:
			return "Opens surface: kind=%s" % kind

func _npc_opens_service_catalog_preview(npc_id: String) -> String:
	var services := _npc_service_rows(npc_id)
	if services.is_empty():
		return "Opens catalog: unavailable"
	var index := mini(maxi(current_preview_npc_service_index, 0), services.size() - 1)
	var service: Dictionary = services[index]
	var opens_service: Dictionary = service.get("opensService", {})
	if opens_service.is_empty():
		return "Opens catalog: unavailable"
	if String(opens_service.get("kind", "")) != "skill_shop":
		return "Opens catalog: unavailable"
	var catalog_skill_ids := _resolve_skill_shop_catalog_ids(opens_service)
	if catalog_skill_ids.is_empty():
		return "Opens catalog: unresolved"
	var preview_names: Array[String] = []
	for skill_id in catalog_skill_ids:
		var skill_def := _definition_row_for_preview("skills", skill_id)
		if skill_def.is_empty():
			continue
		preview_names.append("%s(%s)" % [
			String(skill_def.get("name", skill_id)),
			String(skill_def.get("kind", ""))
		])
		if preview_names.size() >= 4:
			break
	return "Opens catalog: count=%d | %s" % [
		catalog_skill_ids.size(),
		", ".join(preview_names)
	]

func _npc_opens_service_stock_preview(npc_id: String) -> String:
	var services := _npc_service_rows(npc_id)
	if services.is_empty():
		return "Opens stock: unavailable"
	var index := mini(maxi(current_preview_npc_service_index, 0), services.size() - 1)
	var service: Dictionary = services[index]
	var opens_service: Dictionary = service.get("opensService", {})
	if opens_service.is_empty():
		return "Opens stock: unavailable"
	if String(opens_service.get("kind", "")) != "skill_shop":
		return "Opens stock: unavailable"
	var stock_size := int(opens_service.get("stockSize", 3))
	var catalog_skill_ids := _resolve_skill_shop_catalog_ids(opens_service)
	var sample_prices: Array[String] = []
	for skill_id in catalog_skill_ids:
		var skill_def := _definition_row_for_preview("skills", skill_id)
		if skill_def.is_empty():
			continue
		sample_prices.append("%s=%dg" % [
			String(skill_def.get("name", skill_id)),
			int(skill_def.get("price", 0))
		])
		if sample_prices.size() >= 3:
			break
	return "Opens stock: stockSize=%d | samplePrices=%s" % [
		stock_size,
		", ".join(sample_prices)
	]

func _apply_selected_event_contract(placement: Dictionary) -> bool:
	var event_id := String(placement.get("eventId", ""))
	var step := _selected_event_step(event_id)
	if step.is_empty():
		return false
	var fields := {
		"authoringSelectedEventStepId": String(step.get("id", ""))
	}
	var options := _event_step_choice_options(step)
	if not options.is_empty():
		var index := mini(maxi(current_preview_event_choice_index, 0), options.size() - 1)
		var choice: Dictionary = options[index]
		fields["authoringSelectedEventChoiceIndex"] = index
		fields["authoringSelectedEventChoiceLabel"] = String(choice.get("label", choice.get("kind", "")))
		fields["authoringSelectedEventNextStepId"] = String(choice.get("nextStepId", ""))
	_apply_placement_quick_action(fields)
	return true

func _apply_selected_npc_service_contract(placement: Dictionary) -> bool:
	var npc_id := String(placement.get("npcId", ""))
	var services := _npc_service_rows(npc_id)
	if services.is_empty():
		return false
	var index := mini(maxi(current_preview_npc_service_index, 0), services.size() - 1)
	var service: Dictionary = services[index]
	var opens_service: Dictionary = service.get("opensService", {})
	var fields := {
		"authoringSelectedNpcServiceIndex": index,
		"authoringSelectedNpcServiceType": String(service.get("type", "")),
		"authoringSelectedNpcServiceLabel": String(service.get("label", ""))
	}
	if not opens_service.is_empty():
		fields["authoringSelectedOpensServiceId"] = String(opens_service.get("serviceId", ""))
		fields["authoringSelectedOpensServiceKind"] = String(opens_service.get("kind", ""))
	_apply_placement_quick_action(fields)
	return true

func _definition_row_for_preview(kind: String, row_id: String) -> Dictionary:
	var current_definitions := ContentTools.load_definitions()
	for row in current_definitions.get(kind, []):
		if typeof(row) == TYPE_DICTIONARY and String(row.get("id", "")) == row_id:
			return row
	var content_registry := get_tree().root.get_node_or_null("ContentRegistry")
	if content_registry != null:
		var registry_row: Dictionary = content_registry.call("get_definition", kind, row_id)
		if not registry_row.is_empty():
			return registry_row
	for row in definitions_cache.get(kind, []):
		if typeof(row) == TYPE_DICTIONARY and String(row.get("id", "")) == row_id:
			return row
	return {}

func _resolve_skill_shop_catalog_ids(opens_service: Dictionary) -> Array[String]:
	var skill_ids: Array[String] = []
	for skill_id_variant in opens_service.get("skillIds", []):
		var skill_id := String(skill_id_variant)
		if skill_id != "":
			skill_ids.append(skill_id)
	if not skill_ids.is_empty():
		return skill_ids
	var catalog_id := String(opens_service.get("catalogId", ""))
	match catalog_id:
		"trainer_skill_rotation":
			var content_registry := get_tree().root.get_node_or_null("ContentRegistry")
			var skill_rows: Array = []
			if content_registry != null:
				skill_rows = content_registry.call("list_definitions", "skills")
			if skill_rows.is_empty():
				skill_rows = definitions_cache.get("skills", [])
			for skill_def in skill_rows:
				if typeof(skill_def) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = skill_def
				var skill_id := String(row.get("id", ""))
				if skill_id == "" or skill_id == "basic_strike":
					continue
				skill_ids.append(skill_id)
	return skill_ids

func _route_requirement_text(placement: Dictionary) -> String:
	var requirements: Array[String] = []
	var required_flag := String(placement.get("requiredFlag", ""))
	if required_flag != "":
		requirements.append("flag=%s" % required_flag)
	var blocked_message := String(placement.get("blockedMessage", ""))
	var bosses_defeated := int(placement.get("bossesDefeatedAtLeast", -1))
	if bosses_defeated >= 0:
		requirements.append("bosses>=%d" % bosses_defeated)
	var quest_statuses: Array[String] = []
	for status in placement.get("requiredQuestStatuses", []):
		quest_statuses.append(String(status))
	if not quest_statuses.is_empty():
		requirements.append("questStatus in [%s]" % ", ".join(quest_statuses))
	var required_seed_id := String(placement.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		requirements.append("questSeed=%s" % required_seed_id)
	var required_seed_status := String(placement.get("requiredQuestSeedStatus", ""))
	if required_seed_status != "":
		requirements.append("seedStatus=%s" % required_seed_status)
	if requirements.is_empty():
		return "Route requirements: none"
	var line := "Route requirements: %s" % ", ".join(requirements)
	if blocked_message != "":
		line += " | blocked=\"%s\"" % blocked_message
	return line

func _route_target_preview_text(target_map_id: String) -> String:
	if target_map_id == "":
		return "Target map: unavailable"
	var map_data := ContentTools.load_map_data(target_map_id)
	if map_data.is_empty():
		return "Target map: missing %s" % target_map_id
	var size: Array = map_data.get("size", [0, 0])
	var start: Array = map_data.get("start", [0, 0])
	return "Target map: %s | kind=%s | size=%sx%s | start=%s,%s" % [
		target_map_id,
		String(map_data.get("kind", "")),
		int(size[0]),
		int(size[1]),
		int(start[0]),
		int(start[1])
	]

func _route_target_minigrid_text(target_map_id: String) -> String:
	if target_map_id == "":
		return "Mini-grid: unavailable"
	var map_data := ContentTools.load_map_data(target_map_id)
	if map_data.is_empty():
		return "Mini-grid: missing"
	var rows: Array[String] = []
	for row in map_data.get("cells", []):
		rows.append(String(row))
	var start: Array = map_data.get("start", [0, 0])
	var start_x := int(start[0])
	var start_y := int(start[1])
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var pos: Array = placement.get("position", [0, 0])
		var x := int(pos[0])
		var y := int(pos[1])
		if y < 0 or y >= rows.size():
			continue
		var line_with_marker := rows[y]
		if x < 0 or x >= line_with_marker.length():
			continue
		var marker := String(placement.get("id", "")).substr(0, 1).to_upper()
		if marker == "":
			continue
		if String(placement.get("id", "")) == current_preview_route_target_placement_id:
			marker = "@"
		line_with_marker = line_with_marker.substr(0, x) + marker + line_with_marker.substr(x + 1)
		rows[y] = line_with_marker
	if start_y >= 0 and start_y < rows.size():
		var line := rows[start_y]
		if start_x >= 0 and start_x < line.length():
			line = line.substr(0, start_x) + "S" + line.substr(start_x + 1)
			rows[start_y] = line
	var preview_rows: Array[String] = []
	var window_start := maxi(start_y - 1, 0)
	var window_end := mini(window_start + 4, rows.size())
	if window_end - window_start < 4:
		window_start = maxi(window_end - 4, 0)
	for index in range(window_start, window_end):
		preview_rows.append(rows[index])
	return "Mini-grid:\n%s" % "\n".join(preview_rows)

func _route_highlighted_placement_preview(target_map_id: String) -> String:
	if target_map_id == "":
		return "Highlighted target: unavailable"
	if current_preview_route_target_placement_id == "":
		return "Highlighted target: none"
	var placement := _route_highlighted_target_placement(target_map_id)
	if not placement.is_empty():
		var pos: Array = placement.get("position", [0, 0])
		return "Highlighted target: %s | type=%s | pos=%s,%s" % [
			current_preview_route_target_placement_id,
			String(placement.get("type", "")),
			int(pos[0]),
			int(pos[1])
		]
	return "Highlighted target: missing"

func _route_highlighted_placement_detail_preview(target_map_id: String) -> String:
	if target_map_id == "":
		return "Highlighted detail: unavailable"
	if current_preview_route_target_placement_id == "":
		return "Highlighted detail: none"
	var placement := _route_highlighted_target_placement(target_map_id)
	if not placement.is_empty():
		var placement_type := String(placement.get("type", ""))
		match placement_type:
			"field_monster":
				var field_ai: Dictionary = placement.get("fieldAi", {})
				return "Highlighted detail: blocking=%s | fieldAi=%s/%s/%s" % [
					str(placement.get("blocking", false)),
					int(field_ai.get("approachRange", -1)),
					int(field_ai.get("chaseRange", -1)),
					int(field_ai.get("leashRange", -1))
				]
			"event", "rest", "trap":
				return "Highlighted detail: %s | %s" % [
					String(placement.get("eventId", "")),
					_event_preview_text(String(placement.get("eventId", "")))
				]
			"npc_service":
				return "Highlighted detail: %s | %s" % [
					String(placement.get("npcId", "")),
					_npc_preview_text(String(placement.get("npcId", "")))
				]
			"stairs", "gate":
				return "Highlighted detail: route=%s -> %s" % [
					String(placement.get("targetRoute", "")),
					String(placement.get("targetMapId", ""))
				]
			"loot":
				return "Highlighted detail: lootTable=%s | item=%s" % [
					String(placement.get("lootTableId", "")),
					String(placement.get("itemId", ""))
				]
			_:
				return "Highlighted detail: type=%s" % placement_type
	return "Highlighted detail: missing"

func _route_highlighted_placement_contract_preview(target_map_id: String) -> String:
	if target_map_id == "":
		return "Highlighted contract: unavailable"
	if current_preview_route_target_placement_id == "":
		return "Highlighted contract: none"
	var placement := _route_highlighted_target_placement(target_map_id)
	if not placement.is_empty():
		var placement_type := String(placement.get("type", ""))
		match placement_type:
			"field_monster":
				return "Highlighted contract: encounter blocker | blocking=%s" % str(placement.get("blocking", false))
			"event", "rest", "trap":
				var event_id := String(placement.get("eventId", ""))
				return "Highlighted contract: %s | %s | %s" % [
					_event_preview_text(event_id),
					_event_choice_preview(event_id),
					_event_effect_preview(event_id)
				]
			"npc_service":
				var npc_id := String(placement.get("npcId", ""))
				return "Highlighted contract: %s | %s" % [
					_npc_preview_text(npc_id),
					_npc_service_preview(npc_id)
				]
			"stairs", "gate":
				return "Highlighted contract: %s" % _route_requirement_text(placement)
			"loot":
				return "Highlighted contract: loot pickup | lootTable=%s | item=%s" % [
					String(placement.get("lootTableId", "")),
					String(placement.get("itemId", ""))
				]
			_:
				return "Highlighted contract: type=%s" % placement_type
	return "Highlighted contract: missing"

func _route_highlighted_placement_downstream_preview(target_map_id: String) -> String:
	if target_map_id == "":
		return "Highlighted downstream: unavailable"
	if current_preview_route_target_placement_id == "":
		return "Highlighted downstream: none"
	var placement := _route_highlighted_target_placement(target_map_id)
	if not placement.is_empty():
		var placement_type := String(placement.get("type", ""))
		match placement_type:
			"npc_service":
				var npc_id := String(placement.get("npcId", ""))
				return "Highlighted downstream: %s | %s | %s" % [
					_npc_selected_service_preview(npc_id),
					_npc_opens_service_surface_preview(npc_id),
					_npc_opens_service_catalog_preview(npc_id)
				]
			"event", "rest", "trap":
				var event_id := String(placement.get("eventId", ""))
				return "Highlighted downstream: %s | %s" % [
					_event_selected_step_preview(event_id),
					_event_selected_choice_preview(event_id)
				]
			"stairs", "gate":
				return "Highlighted downstream: target=%s/%s" % [
					String(placement.get("targetRoute", "")),
					String(placement.get("targetMapId", ""))
				]
			_:
				return "Highlighted downstream: none"
	return "Highlighted downstream: missing"

func _route_target_selected_event_step_preview(target_map_id: String) -> String:
	var placement := _route_highlighted_target_placement(target_map_id)
	if placement.is_empty():
		return "Selected route event step: unavailable"
	if not ["event", "rest", "trap"].has(String(placement.get("type", ""))):
		return "Selected route event step: unavailable"
	return _event_selected_step_preview(String(placement.get("eventId", "")))

func _route_target_selected_event_choice_preview(target_map_id: String) -> String:
	var placement := _route_highlighted_target_placement(target_map_id)
	if placement.is_empty():
		return "Selected route event choice: unavailable"
	if not ["event", "rest", "trap"].has(String(placement.get("type", ""))):
		return "Selected route event choice: unavailable"
	return _event_selected_choice_preview(String(placement.get("eventId", "")))

func _route_target_selected_npc_service_preview(target_map_id: String) -> String:
	var placement := _route_highlighted_target_placement(target_map_id)
	if placement.is_empty():
		return "Selected route npc service: unavailable"
	if String(placement.get("type", "")) != "npc_service":
		return "Selected route npc service: unavailable"
	return _npc_selected_service_preview(String(placement.get("npcId", "")))

func _route_highlighted_target_placement(target_map_id: String) -> Dictionary:
	if target_map_id == "" or current_preview_route_target_placement_id == "":
		return {}
	for placement in ContentTools.list_map_placements(target_map_id):
		if String(placement.get("id", "")) == current_preview_route_target_placement_id:
			return placement
	return {}

func _build_route_target_event_step_picker(target_map_id: String) -> OptionButton:
	var placement := _route_highlighted_target_placement(target_map_id)
	if placement.is_empty():
		return null
	if not ["event", "rest", "trap"].has(String(placement.get("type", ""))):
		return null
	return _build_event_step_picker(String(placement.get("eventId", "")))

func _build_route_target_event_choice_picker(target_map_id: String) -> OptionButton:
	var placement := _route_highlighted_target_placement(target_map_id)
	if placement.is_empty():
		return null
	if not ["event", "rest", "trap"].has(String(placement.get("type", ""))):
		return null
	return _build_event_choice_picker(String(placement.get("eventId", "")))

func _build_route_target_npc_service_picker(target_map_id: String) -> OptionButton:
	var placement := _route_highlighted_target_placement(target_map_id)
	if placement.is_empty():
		return null
	if String(placement.get("type", "")) != "npc_service":
		return null
	return _build_npc_service_picker(String(placement.get("npcId", "")))

func _event_step_choice_options(step: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for choice in step.get("choices", []):
		if typeof(choice) == TYPE_DICTIONARY:
			var row: Dictionary = choice.duplicate(true)
			row["kind"] = "choice"
			options.append(row)
	for branch in step.get("branches", []):
		if typeof(branch) == TYPE_DICTIONARY:
			var row: Dictionary = branch.duplicate(true)
			row["kind"] = "branch"
			options.append(row)
	return options

func _build_event_choice_picker(event_id: String) -> OptionButton:
	var step := _selected_event_step(event_id)
	if step.is_empty():
		return null
	var options := _event_step_choice_options(step)
	if options.is_empty():
		return null
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(320, 0)
	for option in options:
		var kind := String(option.get("kind", "choice"))
		var label := String(option.get("label", kind))
		picker.add_item("%s: %s" % [kind.capitalize(), label])
	var selected_index := mini(maxi(current_preview_event_choice_index, 0), options.size() - 1)
	picker.select(selected_index)
	picker.item_selected.connect(_on_event_choice_selected.bind(event_id))
	return picker

func _on_event_choice_selected(index: int, _event_id: String) -> void:
	current_preview_event_choice_index = index
	_render_placement_affordances(_current_selected_placement())

func _build_route_target_placement_picker(target_map_id: String) -> OptionButton:
	var placements := ContentTools.list_map_placements(target_map_id)
	if placements.is_empty():
		return null
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(320, 0)
	for placement in placements:
		var placement_id := String(placement.get("id", ""))
		var placement_type := String(placement.get("type", ""))
		picker.add_item("%s (%s)" % [placement_id, placement_type])
	var selected_index := 0
	if current_preview_route_target_placement_id != "":
		for index in range(placements.size()):
			if String(placements[index].get("id", "")) == current_preview_route_target_placement_id:
				selected_index = index
				break
	else:
		current_preview_route_target_placement_id = String(placements[0].get("id", ""))
	picker.select(selected_index)
	picker.item_selected.connect(_on_route_target_placement_selected.bind(target_map_id))
	return picker

func _on_route_target_placement_selected(index: int, target_map_id: String) -> void:
	var placements := ContentTools.list_map_placements(target_map_id)
	if index < 0 or index >= placements.size():
		return
	current_preview_route_target_placement_id = String(placements[index].get("id", ""))
	_render_placement_affordances(_current_selected_placement())

func _event_step_options(event_id: String) -> Array[Dictionary]:
	var event_row := _find_definition_row("events", event_id)
	var options: Array[Dictionary] = []
	if event_row.is_empty():
		return options
	for step in event_row.get("steps", []):
		if typeof(step) != TYPE_DICTIONARY:
			continue
		options.append((step as Dictionary).duplicate(true))
	return options

func _selected_event_step(event_id: String) -> Dictionary:
	var steps := _event_step_options(event_id)
	if steps.is_empty():
		return {}
	var wanted_id := current_preview_event_step_id
	if wanted_id == "":
		wanted_id = String(_find_definition_row("events", event_id).get("entryStepId", ""))
	for step in steps:
		if String(step.get("id", "")) == wanted_id:
			return step
	return steps[0]

func _build_event_step_picker(event_id: String) -> OptionButton:
	var steps := _event_step_options(event_id)
	if steps.size() <= 1:
		return null
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(280, 0)
	var current_id := String(_selected_event_step(event_id).get("id", ""))
	var selected_index := 0
	for index in range(steps.size()):
		var step := steps[index]
		picker.add_item("%s (%s)" % [String(step.get("title", step.get("id", ""))), String(step.get("id", ""))])
		if String(step.get("id", "")) == current_id:
			selected_index = index
	picker.select(selected_index)
	picker.item_selected.connect(_on_event_step_selected.bind(event_id))
	return picker

func _on_event_step_selected(index: int, event_id: String) -> void:
	var steps := _event_step_options(event_id)
	if index < 0 or index >= steps.size():
		return
	current_preview_event_step_id = String(steps[index].get("id", ""))
	_render_placement_affordances(_current_selected_placement())

func _npc_service_rows(npc_id: String) -> Array[Dictionary]:
	var npc_row := _find_definition_row("npcs", npc_id)
	var rows: Array[Dictionary] = []
	if npc_row.is_empty():
		return rows
	for service in npc_row.get("services", []):
		if typeof(service) != TYPE_DICTIONARY:
			continue
		rows.append((service as Dictionary).duplicate(true))
	return rows

func _build_npc_service_picker(npc_id: String) -> OptionButton:
	var services := _npc_service_rows(npc_id)
	if services.size() <= 1:
		return null
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(280, 0)
	var selected_index := mini(maxi(current_preview_npc_service_index, 0), services.size() - 1)
	for service in services:
		picker.add_item("%s:%s" % [String(service.get("type", "")), String(service.get("label", ""))])
	picker.select(selected_index)
	picker.item_selected.connect(_on_npc_service_selected.bind(npc_id))
	return picker

func _on_npc_service_selected(index: int, _npc_id: String) -> void:
	current_preview_npc_service_index = index
	_render_placement_affordances(_current_selected_placement())

func _find_definition_row(kind: String, row_id: String) -> Dictionary:
	for row in definitions_cache.get(kind, []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if String(row.get("id", "")) == row_id:
			return (row as Dictionary).duplicate(true)
	return {}

func _current_selected_placement() -> Dictionary:
	for placement in current_map_placements:
		if String(placement.get("id", "")) == current_placement_id:
			return placement.duplicate(true)
	return {}

func _on_target_route_changed(new_route: String) -> void:
	var placement := _current_selected_placement()
	if placement.is_empty():
		return
	placement["targetRoute"] = new_route
	if placement_editors.has("targetRoute"):
		var route_spec: Dictionary = placement_editors.get("targetRoute", {})
		route_spec["original_value"] = new_route
		placement_editors["targetRoute"] = route_spec
	if placement_editors.has("targetMapId"):
		var target_spec: Dictionary = placement_editors.get("targetMapId", {})
		var control: Control = target_spec.get("control")
		if control is OptionButton:
			var picker := control as OptionButton
			picker.clear()
			var options := _placement_reference_options("targetMapId", placement)
			var current_value := ""
			if picker.item_count > 0:
				current_value = picker.get_item_text(maxi(picker.selected, 0))
			if current_value == "":
				current_value = String(target_spec.get("original_value", ""))
			var final_value := current_value if current_value in options else (options[0] if not options.is_empty() else current_value)
			var seen := {}
			if final_value != "":
				picker.add_item(final_value)
				seen[final_value] = true
			for option in options:
				if option == "" or seen.has(option):
					continue
				picker.add_item(option)
				seen[option] = true
			for index in range(picker.item_count):
				if picker.get_item_text(index) != final_value:
					continue
				picker.select(index)
				break
			target_spec["original_value"] = final_value
			placement_editors["targetMapId"] = target_spec
	for index in range(current_map_placements.size()):
		if String(current_map_placements[index].get("id", "")) != current_placement_id:
			continue
		var updated := current_map_placements[index].duplicate(true)
		updated["targetRoute"] = new_route
		if placement_editors.has("targetMapId"):
			var target_spec: Dictionary = placement_editors.get("targetMapId", {})
			updated["targetMapId"] = String(target_spec.get("original_value", updated.get("targetMapId", "")))
		current_map_placements[index] = updated
		break
	_render_placement_affordances(_current_selected_placement())

func _on_target_route_option_selected(index: int, picker: OptionButton) -> void:
	if picker == null or index < 0 or index >= picker.item_count:
		return
	_on_target_route_changed(picker.get_item_text(index))

func _on_reference_option_selected(index: int, key: String, picker: OptionButton) -> void:
	if picker == null or index < 0 or index >= picker.item_count:
		return
	var value := picker.get_item_text(index)
	if key == "targetRoute":
		_on_target_route_changed(value)
		return
	if placement_editors.has(key):
		var spec: Dictionary = placement_editors.get(key, {})
		spec["original_value"] = value
		placement_editors[key] = spec
	for placement_index in range(current_map_placements.size()):
		if String(current_map_placements[placement_index].get("id", "")) != current_placement_id:
			continue
		var updated := current_map_placements[placement_index].duplicate(true)
		updated[key] = value
		current_map_placements[placement_index] = updated
		break
	_render_placement_affordances(_current_selected_placement())

func _grid_placement_marker(cell: Vector2i) -> String:
	for placement in current_map_placements:
		var pos: Array = placement.get("position", [0, 0])
		if Vector2i(int(pos[0]), int(pos[1])) != cell:
			continue
		var placement_id := String(placement.get("id", ""))
		if placement_id == current_placement_id:
			return "*"
		return placement_id.substr(0, 1).to_upper()
	return ""

func _selected_placement_cell() -> Vector2i:
	for placement in current_map_placements:
		if String(placement.get("id", "")) != current_placement_id:
			continue
		var pos: Array = placement.get("position", [0, 0])
		return Vector2i(int(pos[0]), int(pos[1]))
	return Vector2i(-1, -1)

func _move_selected_placement(cell: Vector2i) -> void:
	for index in range(current_map_placements.size()):
		var placement := current_map_placements[index]
		if String(placement.get("id", "")) != current_placement_id:
			continue
		placement["position"] = [cell.x, cell.y]
		current_map_placements[index] = placement
		if placement_editors.has("position"):
			var spec: Dictionary = placement_editors.get("position", {})
			var control: Control = spec.get("control")
			if control is TextEdit:
				(control as TextEdit).text = JSON.stringify([cell.x, cell.y], "\t")
		return

func _sync_current_placement_cache(row_data: Dictionary) -> void:
	for index in range(current_map_placements.size()):
		if String(current_map_placements[index].get("id", "")) != current_placement_id:
			continue
		current_map_placements[index] = row_data.duplicate(true)
		return

func _add_placement_at_cursor() -> void:
	var result := _create_placement_at_cursor()
	if bool(result.get("ok", false)):
		status_label.text = "[b]Placement Added[/b] %s @ %d,%d" % [
			String(result.get("id", "")),
			current_grid_cursor.x,
			current_grid_cursor.y
		]
		_refresh_placement_option()
	else:
		status_label.text = "[b]Placement Add Failed[/b]\n%s" % "\n".join(result.get("errors", []))

func _create_placement_at_cursor() -> Dictionary:
	if current_grid_cursor.y < 0 or current_grid_cursor.y >= current_map_cells.size():
		return {"ok": false, "errors": ["Cursor is out of bounds."]}
	var row := String(current_map_cells[current_grid_cursor.y])
	if current_grid_cursor.x < 0 or current_grid_cursor.x >= row.length():
		return {"ok": false, "errors": ["Cursor is out of bounds."]}
	if row[current_grid_cursor.x] == "#":
		current_map_cells[current_grid_cursor.y] = _replace_row_char(row, current_grid_cursor.x, ".")
	var placement_type := placement_type_option.get_item_text(maxi(placement_type_option.selected, 0))
	var placement_id := _next_generated_placement_id(placement_type)
	var placement := _default_new_placement(placement_type, placement_id, current_grid_cursor)
	current_map_placements.append(placement)
	current_placement_id = placement_id
	_show_placement_editor(placement)
	_refresh_grid_buttons()
	return {"ok": true, "id": placement_id, "errors": []}

func _delete_selected_placement() -> Dictionary:
	if current_placement_id == "":
		return {"ok": false, "errors": ["No selected placement."]}
	var remaining: Array[Dictionary] = []
	var removed := false
	for placement in current_map_placements:
		if String(placement.get("id", "")) == current_placement_id:
			removed = true
			continue
		remaining.append(placement)
	current_map_placements = remaining
	if not removed:
		return {"ok": false, "errors": ["Selected placement was not found."]}
	current_placement_id = ""
	placement_editors.clear()
	for child in placement_fields_box.get_children():
		child.queue_free()
	_refresh_grid_buttons()
	return {"ok": true, "errors": []}

func _next_generated_placement_id(placement_type: String) -> String:
	var base := "editor_%s" % placement_type
	var suffix := 1
	var seen := {}
	for placement in current_map_placements:
		seen[String(placement.get("id", ""))] = true
	var candidate := "%s_%d" % [base, suffix]
	while seen.has(candidate):
		suffix += 1
		candidate = "%s_%d" % [base, suffix]
	return candidate

func _default_new_placement(placement_type: String, placement_id: String, cell: Vector2i) -> Dictionary:
	var placement := {
		"id": placement_id,
		"type": placement_type,
		"label": "%s %d" % [placement_type.capitalize(), current_map_placements.size() + 1],
		"position": [cell.x, cell.y]
	}
	match placement_type:
		"loot":
			placement["lootTableId"] = "loot_dungeon_satchel"
			placement["itemId"] = "healing_tonic"
		"rest":
			placement["eventId"] = "event_shrine_healing_spring"
		"field_monster":
			placement["monsterId"] = "slime_alpha"
			placement["encounterId"] = "encounter_grave_robber"
			placement["blocking"] = true
			placement["fieldAi"] = {
				"approachRange": 4,
				"chaseRange": 2,
				"leashRange": 5
			}
		"event":
			placement["eventId"] = "event_shrine_healing_spring"
		"npc_service":
			placement["npcId"] = "npc_scholar"
		"stairs":
			placement["targetRoute"] = "town"
			placement["targetMapId"] = "town_square"
	return placement

func _add_placement_quick_actions(placement: Dictionary) -> void:
	var placement_type := String(placement.get("type", ""))
	var actions: Array[Dictionary] = []
	match placement_type:
		"trap":
			actions.append({"label": "Poison Trap", "fields": {"eventId": "event_trap_poison_dart", "label": "Poison Dart Trap"}})
			actions.append({"label": "Bleed Trap", "fields": {"eventId": "event_trap_bleed_blade", "label": "Blade Trap"}})
			actions.append({"label": "Curse Trap", "fields": {"eventId": "event_trap_curse_rune", "label": "Curse Rune Trap"}})
		"rest":
			actions.append({"label": "Guarded Camp", "fields": {"eventId": "event_camp_guard_post", "label": "Guarded Camp"}})
			actions.append({"label": "Healing Shrine", "fields": {"eventId": "event_shrine_healing_spring", "label": "Healing Shrine"}})
		"field_monster":
			actions.append({"label": "Patrol Guard", "fields": {"fieldAi": {"behavior": "patrol", "approachRange": 4, "chaseRange": 2, "hearingRange": 1, "leashRange": 5, "alertRadius": 6, "warningTurns": 1, "patrolPoints": []}, "blocking": true}})
			actions.append({"label": "Ambush", "fields": {"fieldAi": {"behavior": "ambush", "approachRange": 4, "chaseRange": 2, "hearingRange": 1, "leashRange": 5, "wakeRange": 2, "alertRadius": 5, "warningTurns": 1, "patrolPoints": []}, "blocking": true}})
		"npc_service":
			actions.append({"label": "Scholar NPC", "fields": {"npcId": "npc_scholar", "label": "Scholar"}})
			actions.append({"label": "Mystic NPC", "fields": {"npcId": "npc_wounded_mystic", "label": "Wounded Mystic"}})
			actions.append({"label": "Captain NPC", "fields": {"npcId": "npc_deserter_captain", "label": "Deserter Captain"}})
		"stairs", "gate":
			actions.append({"label": "To Town", "fields": {"targetRoute": "town", "targetMapId": "town_square"}})
			actions.append({"label": "To Floor 2", "fields": {"targetRoute": "dungeon", "targetMapId": "dungeon_floor_02"}})
			actions.append({"label": "To Floor 3", "fields": {"targetRoute": "dungeon", "targetMapId": "dungeon_floor_03"}})
		"loot":
			actions.append({"label": "Satchel", "fields": {"lootTableId": "loot_dungeon_satchel", "itemId": "healing_tonic", "label": "Abandoned Satchel"}})
			actions.append({"label": "Antivenom Cache", "fields": {"lootTableId": "loot_dungeon_satchel", "itemId": "antivenom", "label": "Antivenom Cache"}})
	if actions.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	placement_affordance_box.add_child(row)
	var label := Label.new()
	label.text = "Quick author:"
	row.add_child(label)
	for action in actions:
		var button := Button.new()
		button.text = String(action.get("label", "Apply"))
		button.pressed.connect(_apply_placement_quick_action.bind(action.get("fields", {})))
		row.add_child(button)

func _apply_placement_quick_action(fields: Dictionary) -> void:
	if current_placement_id == "":
		return
	var updated := _current_selected_placement()
	if updated.is_empty():
		return
	for key in fields.keys():
		updated[String(key)] = fields[key]
		if placement_editors.has(String(key)):
			smoke_set_current_placement_field(String(key), fields[key])
	for index in range(current_map_placements.size()):
		if String(current_map_placements[index].get("id", "")) == current_placement_id:
			current_map_placements[index] = updated.duplicate(true)
			break
	_show_placement_editor(updated)
	status_label.text = "[b]Quick Author Applied[/b] %s" % current_placement_id

func _add_guided_placement_fields(placement: Dictionary) -> void:
	var placement_type := String(placement.get("type", ""))
	if placement_type not in ["event", "rest", "trap", "npc_service"]:
		return
	var panel := PanelContainer.new()
	placement_affordance_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Guided authoring"
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)
	if placement_type in ["event", "rest", "trap"]:
		_add_guided_reference_row(box, "Event", "eventId", "events", String(placement.get("eventId", "")))
		_add_guided_label_button(box, "Use Event Title", "events", String(placement.get("eventId", "")))
	if placement_type == "npc_service":
		_add_guided_reference_row(box, "NPC", "npcId", "npcs", String(placement.get("npcId", "")))
		_add_guided_label_button(box, "Use NPC Name", "npcs", String(placement.get("npcId", "")))

func _add_guided_reference_row(parent: VBoxContainer, label_text: String, key: String, definition_kind: String, current_value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := Label.new()
	label.text = "%s:" % label_text
	label.custom_minimum_size = Vector2(72, 0)
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(260, 0)
	var selected_index := 0
	var index := 0
	for definition in definitions_cache.get(definition_kind, []):
		if typeof(definition) != TYPE_DICTIONARY:
			continue
		var definition_id := String(definition.get("id", ""))
		if definition_id == "":
			continue
		picker.add_item(definition_id)
		if definition_id == current_value:
			selected_index = index
		index += 1
	if picker.item_count == 0:
		picker.add_item(current_value if current_value != "" else "-")
	picker.select(selected_index)
	picker.item_selected.connect(func(selected: int) -> void:
		var value := picker.get_item_text(selected)
		_apply_placement_quick_action({key: value})
	)
	row.add_child(picker)

func _add_guided_label_button(parent: VBoxContainer, button_text: String, definition_kind: String, definition_id: String) -> void:
	if definition_id == "":
		return
	var definition := _definition_by_id(definition_kind, definition_id)
	if definition.is_empty():
		return
	var label_value := String(definition.get("name", definition.get("title", definition_id)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var preview := Label.new()
	preview.text = "Label: %s" % label_value
	preview.custom_minimum_size = Vector2(240, 0)
	row.add_child(preview)
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(func() -> void:
		_apply_placement_quick_action({"label": label_value})
	)
	row.add_child(button)

func _definition_by_id(definition_kind: String, definition_id: String) -> Dictionary:
	for definition in definitions_cache.get(definition_kind, []):
		if typeof(definition) == TYPE_DICTIONARY and String(definition.get("id", "")) == definition_id:
			return definition
	return {}

func _validate() -> void:
	var result := ContentTools.validate_definitions(definitions_cache)
	if bool(result.get("ok", false)):
		status_label.text = "[b]Validation[/b] ok\n[b]Selected[/b] %s / %s\n[b]Map[/b] %s" % [current_kind, current_row_id, _selected_map_id()]
	else:
		status_label.text = "[b]Validation Failed[/b]\n%s" % "\n".join(result.get("errors", []))

func _export_manifest() -> void:
	var report := ContentTools.export_manifest_report()
	if plugin != null and plugin.has_method("refresh_runtime_content"):
		plugin.refresh_runtime_content()
	status_label.text = "[b]Exported[/b] contentVersion=%d counts=%s" % [
		int(report.get("contentVersion", 0)),
		str(report.get("counts", {}))
	]

func _build_bundle() -> void:
	var result := ContentTools.export_build_bundle()
	if bool(result.get("ok", false)):
		if plugin != null and plugin.has_method("refresh_runtime_content"):
			plugin.refresh_runtime_content()
		status_label.text = "[b]Build Bundle[/b] ok compiledMaps=%d manifest=%s" % [
			int(result.get("compiledMaps", 0)),
			String(result.get("manifestPath", ""))
		]
	else:
		status_label.text = "[b]Build Bundle Failed[/b]\n%s" % "\n".join(result.get("errors", []))

func _validate_maps() -> void:
	var result := ContentTools.validate_maps()
	if bool(result.get("ok", false)):
		status_label.text = "[b]Map Validation[/b] ok mapCount=%d" % int(result.get("mapCount", 0))
	else:
		status_label.text = "[b]Map Validation Failed[/b]\n%s" % "\n".join(result.get("errors", []))

func _preview_dungeon_build() -> void:
	var map_id := _selected_map_id()
	if map_id == "":
		status_label.text = "[b]Dungeon Preview Failed[/b]\nNo selected map."
		return
	var result := ContentTools.export_compiled_map_preview(map_id)
	if bool(result.get("ok", false)):
		status_label.text = "[b]Map Preview[/b] %s\n[b]Map[/b] %s\n%s\nchunks=%s" % [
			String(result.get("profileName", result.get("profileId", ""))),
			map_id,
			"\n".join(result.get("previewRows", [])),
			str(result.get("sourceChunkIds", []))
		]
	else:
		status_label.text = "[b]Dungeon Preview Failed[/b]\n%s" % "\n".join(result.get("errors", []))

func _selected_map_id() -> String:
	if map_option == null or map_option.item_count == 0:
		return ""
	var index := maxi(map_option.selected, 0)
	if index >= map_entries.size():
		return ""
	return String(map_entries[index].get("id", ""))

func _collect_editor_row_result(source_editors: Dictionary) -> Dictionary:
	var row := {}
	var errors: Array[String] = []
	for key in source_editors.keys():
		var spec: Dictionary = source_editors[key]
		var control: Control = spec.get("control")
		var editor_kind := String(spec.get("editor_kind", ""))
		if editor_kind == "reference_option":
			if control is OptionButton:
				var option := control as OptionButton
				row[key] = option.get_item_text(maxi(option.selected, 0))
			else:
				row[key] = str(spec.get("original_value", ""))
			continue
		var value_type: int = int(spec.get("value_type", TYPE_STRING))
		match value_type:
			TYPE_ARRAY, TYPE_DICTIONARY:
				var json_text := ""
				if control is TextEdit:
					json_text = control.text
				var parsed: Variant = JSON.parse_string(json_text)
				var valid_type := typeof(parsed) == value_type
				if parsed == null or not valid_type:
					errors.append("%s must be valid %s JSON." % [str(key), _value_type_name_by_id(value_type)])
				else:
					row[key] = parsed
			TYPE_BOOL:
				row[key] = bool((control as CheckBox).button_pressed)
			TYPE_INT:
				row[key] = int((control as SpinBox).value)
			TYPE_FLOAT:
				row[key] = float((control as SpinBox).value)
			_:
				if control is LineEdit:
					row[key] = control.text
				else:
					row[key] = str(spec.get("original_value", ""))
	return {
		"row": row,
		"errors": errors
	}

func _build_editor_for_value(value: Variant) -> Dictionary:
	var value_type := typeof(value)
	match value_type:
		TYPE_ARRAY, TYPE_DICTIONARY:
			var editor := TextEdit.new()
			editor.custom_minimum_size = Vector2(280, 96)
			editor.text = JSON.stringify(value, "\t")
			return {"control": editor, "value_type": value_type, "original_value": value}
		TYPE_BOOL:
			var toggle := CheckBox.new()
			toggle.text = "Enabled"
			toggle.button_pressed = bool(value)
			return {"control": toggle, "value_type": value_type, "original_value": value}
		TYPE_INT:
			var int_box := SpinBox.new()
			int_box.min_value = -9999
			int_box.max_value = 9999
			int_box.step = 1
			int_box.rounded = true
			int_box.value = int(value)
			return {"control": int_box, "value_type": value_type, "original_value": value}
		TYPE_FLOAT:
			var float_box := SpinBox.new()
			float_box.min_value = -9999
			float_box.max_value = 9999
			float_box.step = 0.1
			float_box.value = float(value)
			return {"control": float_box, "value_type": value_type, "original_value": value}
		_:
			var line := LineEdit.new()
			line.text = str(value)
			return {"control": line, "value_type": TYPE_STRING, "original_value": value}

func _value_type_name(value: Variant) -> String:
	return _value_type_name_by_id(typeof(value))

func _value_type_name_by_id(value_type: int) -> String:
	match value_type:
		TYPE_ARRAY:
			return "array"
		TYPE_DICTIONARY:
			return "object"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "string"
		_:
			return "value"

func _play_selected_map() -> void:
	var map_id := _selected_map_id()
	if map_id == "" or plugin == null or not plugin.has_method("play_map_test"):
		return
	plugin.play_map_test(map_id, "compiled")

func _play_selected_compiled() -> void:
	var map_id := _selected_map_id()
	if map_id == "" or plugin == null or not plugin.has_method("play_map_test"):
		return
	plugin.play_map_test(map_id, "compiled")

func _play_selected_authored() -> void:
	var map_id := _selected_map_id()
	if map_id == "" or plugin == null or not plugin.has_method("play_map_test"):
		return
	plugin.play_map_test(map_id, "authored")

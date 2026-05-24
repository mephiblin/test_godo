extends "res://scripts/ui/grid_hud.gd"

var town_focus_panel: PanelContainer
var town_focus_title: Label
var town_focus_radial: HBoxContainer
var town_focus_strip: HBoxContainer
var town_focus_detail: RichTextLabel

func _ready() -> void:
	super._ready()
	town_focus_panel = PanelContainer.new()
	town_focus_panel.offset_left = 16
	town_focus_panel.offset_top = 236
	town_focus_panel.custom_minimum_size = Vector2(420, 70)
	town_focus_panel.add_theme_stylebox_override("panel", _panel_style(0.6))
	add_child(town_focus_panel)

	var focus_layout := VBoxContainer.new()
	focus_layout.custom_minimum_size = Vector2(392, 62)
	town_focus_panel.add_child(focus_layout)

	town_focus_title = Label.new()
	town_focus_title.add_theme_font_size_override("font_size", 15)
	focus_layout.add_child(town_focus_title)

	town_focus_radial = HBoxContainer.new()
	town_focus_radial.alignment = BoxContainer.ALIGNMENT_CENTER
	town_focus_radial.add_theme_constant_override("separation", 8)
	town_focus_radial.custom_minimum_size = Vector2(392, 30)
	focus_layout.add_child(town_focus_radial)

	town_focus_strip = HBoxContainer.new()
	town_focus_strip.add_theme_constant_override("separation", 6)
	town_focus_strip.custom_minimum_size = Vector2(392, 24)
	focus_layout.add_child(town_focus_strip)

	town_focus_detail = RichTextLabel.new()
	town_focus_detail.bbcode_enabled = true
	town_focus_detail.fit_content = false
	town_focus_detail.scroll_active = false
	town_focus_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	town_focus_detail.custom_minimum_size = Vector2(392, 32)
	focus_layout.add_child(town_focus_detail)

func _process(delta: float) -> void:
	super._process(delta)
	_update_town_focus(last_snapshot.get("townFocus", {}))

func _apply_town_layout() -> void:
	info_panel.custom_minimum_size = Vector2(420, 188)
	left_column.custom_minimum_size = Vector2(250, 164)
	right_column.custom_minimum_size = Vector2(130, 164)
	objective_label.custom_minimum_size = Vector2(242, 42)
	state_label.custom_minimum_size = Vector2(242, 68)
	log_label.custom_minimum_size = Vector2(242, 40)
	prompt_panel.offset_left = 16
	prompt_panel.offset_right = -430
	interaction_detail.custom_minimum_size = Vector2(520, 40)
	if town_focus_panel != null:
		town_focus_panel.visible = true

func _update_town_focus(town_focus: Dictionary) -> void:
	var entries: Array = town_focus.get("entries", [])
	if entries.is_empty():
		town_focus_title.text = "Hub Focus"
		_clear_town_focus_radial()
		_clear_town_focus_strip()
		town_focus_detail.text = "근처 허브가 없다."
		return
	town_focus_title.text = "Hub Focus  |  %s" % String(town_focus.get("controls", ""))
	_rebuild_town_focus_radial(entries)
	_rebuild_town_focus_strip(entries)
	var parts: Array[String] = []
	var anchor: Array = town_focus.get("selectedAnchor", [])
	var next_step: Array = town_focus.get("nextStep", [])
	var path_length := int(town_focus.get("pathLength", 0))
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var label := String(entry.get("label", entry.get("id", "")))
		var distance := int(entry.get("distance", 0))
		if bool(entry.get("selected", false)):
			parts.append("[color=#f3e7b3]> %s (%d)[/color]" % [label, distance])
		else:
			parts.append("[color=#9aa7b8]%s (%d)[/color]" % [label, distance])
	if anchor.size() == 2:
		parts.append("[color=#d7c27a]anchor %d,%d[/color]" % [int(anchor[0]), int(anchor[1])])
	if next_step.size() == 2:
		parts.append("[color=#8fb7d8]next %d,%d[/color]" % [int(next_step[0]), int(next_step[1])])
	if path_length > 0:
		parts.append("[color=#9aa7b8]path %d[/color]" % path_length)
	town_focus_detail.text = "  ".join(parts)

func _clear_town_focus_strip() -> void:
	for child in town_focus_strip.get_children():
		child.queue_free()

func _clear_town_focus_radial() -> void:
	for child in town_focus_radial.get_children():
		child.queue_free()

func _rebuild_town_focus_radial(entries: Array) -> void:
	_clear_town_focus_radial()
	if entries.is_empty():
		return
	var selected_index := 0
	for idx in range(entries.size()):
		var entry: Dictionary = entries[idx]
		if bool(entry.get("selected", false)):
			selected_index = idx
			break
	var left_entry: Dictionary = entries[(selected_index - 1 + entries.size()) % entries.size()]
	var center_entry: Dictionary = entries[selected_index]
	var right_entry: Dictionary = entries[(selected_index + 1) % entries.size()]
	town_focus_radial.add_child(_town_focus_radial_chip(left_entry, "<"))
	town_focus_radial.add_child(_town_focus_radial_chip(center_entry, "*"))
	town_focus_radial.add_child(_town_focus_radial_chip(right_entry, ">"))

func _town_focus_radial_chip(entry: Dictionary, marker: String) -> Control:
	var segment := PanelContainer.new()
	segment.custom_minimum_size = Vector2(96, 28)
	segment.modulate = _town_focus_chip_color(String(entry.get("type", "")), bool(entry.get("selected", false)))
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.text = "%s %s" % [marker, _town_focus_chip_label(entry)]
	segment.add_child(label)
	return segment

func _rebuild_town_focus_strip(entries: Array) -> void:
	_clear_town_focus_strip()
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var segment := PanelContainer.new()
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.custom_minimum_size = Vector2(76, 22)
		segment.modulate = _town_focus_chip_color(String(entry.get("type", "")), bool(entry.get("selected", false)))
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.text = "%s %d" % [_town_focus_chip_label(entry), int(entry.get("distance", 0))]
		segment.add_child(label)
		town_focus_strip.add_child(segment)

func _town_focus_chip_label(entry: Dictionary) -> String:
	var kind := String(entry.get("type", ""))
	match kind:
		"quest_board":
			return "의뢰"
		"healer":
			return "치료"
		"skill_shop":
			return "기술"
		"trade":
			return "상점"
		"npc_service":
			return "NPC"
		"rest":
			return "휴식"
		_:
			return String(entry.get("label", entry.get("id", "")))

func _town_focus_chip_color(kind: String, selected: bool) -> Color:
	var base := Color("6f7b89")
	match kind:
		"quest_board":
			base = Color("b7895d")
		"healer", "rest":
			base = Color("6da87d")
		"skill_shop":
			base = Color("6e7fc5")
		"trade":
			base = Color("8d7c59")
		"npc_service":
			base = Color("8d679f")
	if selected:
		return base.lightened(0.45)
	return base

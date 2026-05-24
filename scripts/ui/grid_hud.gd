extends Control

var scene_ref: Node
var info_panel: PanelContainer
var left_column: VBoxContainer
var right_column: VBoxContainer
var title_label: Label
var state_label: RichTextLabel
var log_label: RichTextLabel
var minimap_texture: TextureRect
var minimap_caption: Label
var minimap_legend: RichTextLabel
var prompt_panel: PanelContainer
var interaction_title: Label
var interaction_detail: RichTextLabel
var last_minimap_hash := ""
var current_hud_mode := ""
var last_snapshot: Dictionary = {}

func configure(target_scene: Node) -> Control:
	scene_ref = target_scene
	return self

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel = PanelContainer.new()
	info_panel.offset_left = 16
	info_panel.offset_top = 16
	info_panel.custom_minimum_size = Vector2(560, 250)
	add_child(info_panel)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	info_panel.add_child(layout)

	left_column = VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(360, 220)
	layout.add_child(left_column)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	left_column.add_child(title_label)

	state_label = RichTextLabel.new()
	state_label.custom_minimum_size = Vector2(340, 90)
	state_label.bbcode_enabled = true
	state_label.fit_content = true
	left_column.add_child(state_label)

	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(340, 70)
	log_label.bbcode_enabled = true
	log_label.fit_content = true
	left_column.add_child(log_label)

	right_column = VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(160, 220)
	layout.add_child(right_column)

	minimap_caption = Label.new()
	minimap_caption.text = "Minimap"
	minimap_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_column.add_child(minimap_caption)

	minimap_texture = TextureRect.new()
	minimap_texture.custom_minimum_size = Vector2(144, 144)
	minimap_texture.stretch_mode = TextureRect.STRETCH_SCALE
	right_column.add_child(minimap_texture)

	minimap_legend = RichTextLabel.new()
	minimap_legend.bbcode_enabled = true
	minimap_legend.fit_content = true
	minimap_legend.custom_minimum_size = Vector2(144, 52)
	right_column.add_child(minimap_legend)

	prompt_panel = PanelContainer.new()
	prompt_panel.offset_left = 16
	prompt_panel.offset_right = -16
	prompt_panel.anchor_right = 1.0
	prompt_panel.anchor_bottom = 1.0
	prompt_panel.offset_bottom = -16
	add_child(prompt_panel)

	var prompt_layout := VBoxContainer.new()
	prompt_layout.custom_minimum_size = Vector2(820, 74)
	prompt_panel.add_child(prompt_layout)

	interaction_title = Label.new()
	interaction_title.add_theme_font_size_override("font_size", 18)
	prompt_layout.add_child(interaction_title)

	interaction_detail = RichTextLabel.new()
	interaction_detail.bbcode_enabled = true
	interaction_detail.fit_content = true
	interaction_detail.custom_minimum_size = Vector2(780, 42)
	prompt_layout.add_child(interaction_detail)

func _process(_delta: float) -> void:
	if scene_ref == null or not is_instance_valid(scene_ref):
		return
	var snapshot: Dictionary = scene_ref.call("hud_snapshot")
	last_snapshot = snapshot
	_apply_layout(String(snapshot.get("hudMode", "")))
	title_label.text = String(snapshot.get("title", ""))
	state_label.text = String(snapshot.get("state", ""))
	log_label.text = String(snapshot.get("log", ""))
	_update_interaction(snapshot.get("interaction", {}))
	_update_minimap(snapshot.get("minimap", {}))

func _apply_layout(hud_mode: String) -> void:
	if hud_mode == current_hud_mode:
		return
	current_hud_mode = hud_mode
	if hud_mode == "town":
		_apply_town_layout()
	else:
		_apply_dungeon_layout()

func _apply_dungeon_layout() -> void:
	info_panel.custom_minimum_size = Vector2(560, 250)
	left_column.custom_minimum_size = Vector2(360, 220)
	right_column.custom_minimum_size = Vector2(160, 220)
	state_label.custom_minimum_size = Vector2(340, 90)
	log_label.custom_minimum_size = Vector2(340, 70)
	prompt_panel.offset_left = 16
	prompt_panel.offset_right = -16
	interaction_detail.custom_minimum_size = Vector2(780, 42)

func _apply_town_layout() -> void:
	_apply_dungeon_layout()

func _update_interaction(interaction: Dictionary) -> void:
	if not bool(interaction.get("available", false)):
		interaction_title.text = String(interaction.get("title", ""))
		interaction_detail.text = String(interaction.get("detail", ""))
		return
	interaction_title.text = "%s  |  %s" % [
		String(interaction.get("title", "")),
		String(interaction.get("action", ""))
	]
	var status := "[color=#d89a6d]Blocked[/color]" if bool(interaction.get("blocked", false)) else "[color=#9fd6a5]Ready[/color]"
	var selection := String(interaction.get("selection", ""))
	var detail := String(interaction.get("detail", ""))
	if selection != "":
		detail += "\n[color=#8fb7d8]%s[/color]" % selection
	interaction_detail.text = "%s\n%s" % [status, detail]

func _update_minimap(minimap: Dictionary) -> void:
	var cells: Array = minimap.get("cells", [])
	if cells.is_empty():
		return
	var image := _build_minimap_image(minimap)
	var locked_route_count := 0
	for route_state in minimap.get("routeStates", []):
		if typeof(route_state) == TYPE_DICTIONARY and bool(route_state.get("blocked", false)):
			locked_route_count += 1
	var hash := "%s|%d|%s|%s|%s|%d" % [
		String(minimap.get("mapId", "")),
		minimap.get("visitedKeys", []).size(),
		str(minimap.get("currentCell", [])),
		str(minimap.get("questStatus", "")),
		str(minimap.get("questTargetKeys", [])),
		minimap.get("placements", []).size() + locked_route_count
	]
	if hash == last_minimap_hash and minimap_texture.texture != null:
		return
	last_minimap_hash = hash
	var texture := ImageTexture.create_from_image(image)
	minimap_texture.texture = texture
	minimap_caption.text = "Minimap %s" % String(minimap.get("mapId", ""))
	minimap_legend.text = _build_minimap_legend(minimap)

func _build_minimap_image(minimap: Dictionary) -> Image:
	var cells: Array = minimap.get("cells", [])
	var width := String(cells[0]).length()
	var height := cells.size()
	var visited := {}
	for key in minimap.get("visitedKeys", []):
		visited[String(key)] = true
	var placements_by_key := {}
	for placement in minimap.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var pos: Array = placement.get("position", [])
		if pos.size() != 2:
			continue
		placements_by_key["%d,%d" % [int(pos[0]), int(pos[1])]] = placement
	var quest_targets := {}
	for key in minimap.get("questTargetKeys", []):
		quest_targets[String(key)] = true
	var reward_turn_in := {}
	for key in minimap.get("rewardTurnInKeys", []):
		reward_turn_in[String(key)] = true
	var quest_seed_objectives := {}
	for key in minimap.get("questSeedObjectiveKeys", []):
		quest_seed_objectives[String(key)] = true
	var current: Array = minimap.get("currentCell", [0, 0])
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var row := String(cells[y])
		for x in range(width):
			var key := "%d,%d" % [x, y]
			var tile_color := Color("12181c")
			if row[x] == "#":
				tile_color = Color("2f363c")
			elif visited.has(key):
				tile_color = Color("9bb0a4")
			else:
				tile_color = Color("4e5a57")
			if placements_by_key.has(key):
				tile_color = _minimap_placement_color(placements_by_key[key])
			if quest_seed_objectives.has(key):
				tile_color = Color("d06fe8")
			if quest_targets.has(key):
				tile_color = Color("f06c6c")
			if reward_turn_in.has(key):
				tile_color = Color("6fd2b3")
			if int(current[0]) == x and int(current[1]) == y:
				tile_color = Color("f3e7b3")
			image.set_pixel(x, y, tile_color)
	return image

func _minimap_placement_color(placement: Dictionary) -> Color:
	var kind := String(placement.get("type", ""))
	match kind:
		"gate", "stairs":
			if bool(placement.get("routeBlocked", false)):
				return Color("8e5d50")
			return Color("d7c27a")
		"field_monster":
			return Color("d04f4f")
		"rest", "healer":
			return Color("5fb77d")
		"event":
			return Color("cc6f9a")
		"trap":
			return Color("8e73c7")
		"quest_board", "npc_service", "skill_shop", "trade":
			return Color("6ba7d8")
		"locked_door", "secret_door":
			return Color("8a7b62")
		"loot":
			return Color("cfa35c")
		_:
			return Color("7ca3d8")

func _build_minimap_legend(minimap: Dictionary) -> String:
	var quest_status := String(minimap.get("questStatus", "none"))
	var route_hint := "[color=#d7c27a]Route[/color]"
	for route_state in minimap.get("routeStates", []):
		if typeof(route_state) == TYPE_DICTIONARY and bool(route_state.get("blocked", false)):
			route_hint += "  [color=#8e5d50]Locked[/color]"
			break
	var quest_hint := ""
	if quest_status == "accepted":
		quest_hint = "  [color=#f06c6c]Target[/color]"
	elif quest_status == "complete_ready":
		quest_hint = "  [color=#6fd2b3]Turn-in[/color]"
	var seed_hint := ""
	if minimap.get("questSeedObjectiveKeys", []).size() > 0:
		seed_hint = "  [color=#d06fe8]Objective[/color]"
	return "%s%s%s\n[color=#f3e7b3]You[/color]  [color=#9bb0a4]Visited[/color]" % [route_hint, quest_hint, seed_hint]

extends Control

var subtitle_label: Label
var slot_summary_label: RichTextLabel
var name_edit: LineEdit
var class_option: OptionButton
var background_option: OptionButton
var supply_option: OptionButton
var slot_option: OptionButton
var rename_slot_option: OptionButton
var rename_edit: LineEdit
var continue_buttons: Array[Button] = []

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var background := ColorRect.new()
	background.color = Color("18140f")
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 520)
	panel.offset_left = 80
	panel.offset_top = 48
	add_child(panel)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	panel.add_child(root)

	var new_game_column := VBoxContainer.new()
	new_game_column.custom_minimum_size = Vector2(420, 480)
	new_game_column.add_theme_constant_override("separation", 10)
	root.add_child(new_game_column)

	var title := Label.new()
	title.text = "Conan Dot Bootstrap"
	title.add_theme_font_size_override("font_size", 28)
	new_game_column.add_child(title)

	subtitle_label = Label.new()
	subtitle_label.text = "Select a slot, name, class, background, and opening supply before starting."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_game_column.add_child(subtitle_label)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Hero Name"
	name_edit.text = "Conan"
	new_game_column.add_child(_labeled_control("Name", name_edit))

	slot_option = OptionButton.new()
	new_game_column.add_child(_labeled_control("Target Slot", slot_option))

	class_option = OptionButton.new()
	new_game_column.add_child(_labeled_control("Class", class_option))

	background_option = OptionButton.new()
	new_game_column.add_child(_labeled_control("Background", background_option))

	supply_option = OptionButton.new()
	new_game_column.add_child(_labeled_control("Start Supply", supply_option))

	var start_button := Button.new()
	start_button.text = "Start New Expedition"
	start_button.pressed.connect(_on_start_pressed)
	new_game_column.add_child(start_button)

	var editor_button := Button.new()
	editor_button.text = "Editor Fallback"
	editor_button.pressed.connect(func() -> void:
		GameApp.current_mode = GameApp.MODE_EDITOR
		SceneRouter.change_route(GameApp.MODE_EDITOR, {})
	)
	new_game_column.add_child(editor_button)

	var validate_button := Button.new()
	validate_button.text = "Content Smoke"
	validate_button.pressed.connect(_refresh_content_summary)
	new_game_column.add_child(validate_button)

	var slots_column := VBoxContainer.new()
	slots_column.custom_minimum_size = Vector2(420, 480)
	slots_column.add_theme_constant_override("separation", 10)
	root.add_child(slots_column)

	var slots_title := Label.new()
	slots_title.text = "Save Slots"
	slots_title.add_theme_font_size_override("font_size", 24)
	slots_column.add_child(slots_title)

	slot_summary_label = RichTextLabel.new()
	slot_summary_label.bbcode_enabled = true
	slot_summary_label.custom_minimum_size = Vector2(420, 220)
	slots_column.add_child(slot_summary_label)

	for slot in range(1, SaveService.SLOT_COUNT + 1):
		var continue_button := Button.new()
		continue_button.text = "Continue Slot %d" % slot
		continue_button.pressed.connect(func(selected_slot := slot) -> void:
			GameApp.continue_game(selected_slot)
		)
		continue_buttons.append(continue_button)
		slots_column.add_child(continue_button)

	rename_slot_option = OptionButton.new()
	slots_column.add_child(_labeled_control("Rename Slot", rename_slot_option))

	rename_edit = LineEdit.new()
	rename_edit.placeholder_text = "New Slot Name"
	slots_column.add_child(rename_edit)

	var rename_button := Button.new()
	rename_button.text = "Rename Selected Slot"
	rename_button.pressed.connect(_rename_selected_slot)
	slots_column.add_child(rename_button)

	var delete_button := Button.new()
	delete_button.text = "Delete Selected Slot"
	delete_button.pressed.connect(_delete_selected_slot)
	slots_column.add_child(delete_button)

	_populate_options()
	_refresh_slot_summary()
	_refresh_content_summary()

func _labeled_control(label_text: String, control: Control) -> Control:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	box.add_child(label)
	box.add_child(control)
	return box

func _populate_options() -> void:
	_clear_option(slot_option)
	_clear_option(rename_slot_option)
	for slot_info in SaveService.list_slots():
		var slot_text := "Slot %d" % int(slot_info["slot"])
		slot_option.add_item(slot_text, int(slot_info["slot"]))
		rename_slot_option.add_item(slot_text, int(slot_info["slot"]))
	_clear_option(class_option)
	for row in ContentRegistry.list_definitions("classes"):
		class_option.add_item(String(row.get("name", row.get("id", ""))), class_option.item_count)
		class_option.set_item_metadata(class_option.item_count - 1, String(row.get("id", "")))
	_clear_option(background_option)
	for row in ContentRegistry.list_definitions("backgrounds"):
		background_option.add_item(String(row.get("name", row.get("id", ""))), background_option.item_count)
		background_option.set_item_metadata(background_option.item_count - 1, String(row.get("id", "")))
	_clear_option(supply_option)
	for row in ContentRegistry.list_definitions("start_supplies"):
		supply_option.add_item(String(row.get("name", row.get("id", ""))), supply_option.item_count)
		supply_option.set_item_metadata(supply_option.item_count - 1, String(row.get("id", "")))

func _clear_option(option: OptionButton) -> void:
	while option.item_count > 0:
		option.remove_item(0)

func _selected_slot(option: OptionButton) -> int:
	if option.selected < 0:
		return 1
	return option.get_item_id(option.selected)

func _selected_definition_id(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	return String(option.get_item_metadata(option.selected))

func _on_start_pressed() -> void:
	var slot := _selected_slot(slot_option)
	var profile := {
		"name": name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Conan",
		"classId": _selected_definition_id(class_option),
		"backgroundId": _selected_definition_id(background_option),
		"startSupply": _selected_definition_id(supply_option)
	}
	GameApp.start_new_game(slot, profile)

func _rename_selected_slot() -> void:
	var new_name := rename_edit.text.strip_edges()
	if new_name == "":
		subtitle_label.text = "Rename requires a non-empty slot name."
		return
	SaveService.rename_slot(_selected_slot(rename_slot_option), new_name)
	rename_edit.clear()
	_refresh_slot_summary()

func _delete_selected_slot() -> void:
	SaveService.delete_slot(_selected_slot(rename_slot_option))
	_refresh_slot_summary()

func _refresh_slot_summary() -> void:
	_populate_options()
	var lines: Array[String] = []
	for slot_info in SaveService.list_slots():
		var slot := int(slot_info["slot"])
		if slot - 1 >= 0 and slot - 1 < continue_buttons.size():
			continue_buttons[slot - 1].disabled = (not bool(slot_info["exists"])) or bool(slot_info.get("blocked", false))
		if bool(slot_info["exists"]):
			var summary := SaveService.slot_summary(slot)
			var extra_lines: Array[String] = []
			if bool(summary.get("blocked", false)):
				extra_lines.append("[color=salmon]Blocked[/color]")
			for message in summary.get("messages", []):
				extra_lines.append(String(message))
			lines.append("[b]Slot %d[/b] %s\n%s / %s / %s\nGold %d  State %s\nSave v%d / Content v%d%s" % [
				slot,
				String(summary.get("slotName", "")),
				String(summary.get("playerName", "")),
				String(summary.get("classId", "")),
				String(summary.get("backgroundId", "")),
				int(summary.get("gold", 0)),
				String(summary.get("lastState", "title")),
				int(summary.get("saveVersion", 0)),
				int(summary.get("contentVersion", 0)),
				"\n%s" % "\n".join(extra_lines) if not extra_lines.is_empty() else ""
			])
			if bool(summary.get("campaignCleared", false)):
				lines[lines.size() - 1] += "\n[color=lightgreen]Cleared[/color] %s" % String(summary.get("endingTitle", "Expedition Complete"))
			var last_defeat: Dictionary = summary.get("lastDefeat", {})
			if not last_defeat.is_empty():
				lines[lines.size() - 1] += "\n[color=salmon]Defeats[/color] %d / last by %s (-%d gold)" % [
					int(summary.get("defeatCount", 0)),
					String(last_defeat.get("enemyName", "Unknown Enemy")),
					int(last_defeat.get("goldPenalty", 0))
				]
		else:
			lines.append("[b]Slot %d[/b] Empty" % slot)
	slot_summary_label.text = "\n\n".join(lines)

func _refresh_content_summary() -> void:
	var summary := ContentRegistry.validate_content()
	subtitle_label.text = "Content ok=%s, mapCount=%d, definitions=%s, manifest=%s" % [
		summary["ok"],
		summary["mapCount"],
		str(summary.get("definitionKinds", [])),
		String(summary.get("manifestPath", ""))
	]

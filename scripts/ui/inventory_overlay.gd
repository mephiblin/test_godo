extends Control

var slot := 1
var close_callback: Callable
var body_label: RichTextLabel
var action_box: VBoxContainer
var message_label: RichTextLabel
var reward_label: RichTextLabel
var search_input: LineEdit
var filter_select: OptionButton
var sort_select: OptionButton
var selected_item_id := ""
var search_query := ""
var filter_mode := "all"
var sort_mode := "name"

func configure(target_slot: int, callback: Callable) -> Control:
	slot = target_slot
	close_callback = callback
	return self

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0.55)
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	add_child(fade)

	var panel := PanelContainer.new()
	panel.offset_left = 150
	panel.offset_top = 70
	panel.custom_minimum_size = Vector2(760, 500)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	layout.add_child(controls)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search item"
	search_input.text_changed.connect(func(new_text: String) -> void:
		search_query = new_text.strip_edges().to_lower()
		refresh()
	)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(search_input)

	filter_select = OptionButton.new()
	for label in ["All", "Consumable", "Equippable", "Key", "Quest", "Supply"]:
		filter_select.add_item(label)
	filter_select.item_selected.connect(func(index: int) -> void:
		filter_mode = ["all", "consumable", "equippable", "key", "quest", "supply"][index]
		refresh()
	)
	controls.add_child(filter_select)

	sort_select = OptionButton.new()
	for label in ["Name", "Quantity", "Kind", "Price"]:
		sort_select.add_item(label)
	sort_select.item_selected.connect(func(index: int) -> void:
		sort_mode = ["name", "quantity", "kind", "price"][index]
		refresh()
	)
	controls.add_child(sort_select)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	layout.add_child(columns)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.custom_minimum_size = Vector2(420, 220)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(body_label)

	action_box = VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(250, 220)
	action_box.add_theme_constant_override("separation", 8)
	columns.add_child(action_box)

	message_label = RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.custom_minimum_size = Vector2(700, 96)
	layout.add_child(message_label)

	reward_label = RichTextLabel.new()
	reward_label.bbcode_enabled = true
	reward_label.custom_minimum_size = Vector2(700, 110)
	layout.add_child(reward_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close)
	layout.add_child(close_button)

	refresh()

func refresh() -> void:
	var inventory_data: Dictionary = SaveService.inventory(slot)
	var equipment_data: Dictionary = SaveService.equipment(slot)
	var visible_items := _visible_item_ids(inventory_data)
	if selected_item_id != "" and not visible_items.has(selected_item_id):
		selected_item_id = ""
	if selected_item_id == "" and not visible_items.is_empty():
		selected_item_id = String(visible_items[0])
	var lines: Array[String] = []
	for item_id in visible_items:
		var item_def := ContentRegistry.get_definition("items", item_id)
		var display_name := _item_display_name(item_id, item_def)
		var kind := String(item_def.get("kind", "item"))
		var count := int(inventory_data.get(item_id, 0))
		var marker := " <" if item_id == selected_item_id else ""
		lines.append("%s x%d [%s]%s" % [display_name, count, kind, marker])
	if lines.is_empty():
		lines.append("No matching items")
	body_label.text = "[b]Gold[/b] %d\n[b]Equipment[/b] weapon=%s / trinket=%s\n[b]Filter[/b] %s / [b]Sort[/b] %s\n[b]Items[/b]\n%s" % [
		int(SaveService.load_slot(slot).get("resources", {}).get("gold", 0)),
		_equipped_item_name(String(equipment_data.get("weapon", ""))),
		_equipped_item_name(String(equipment_data.get("trinket", ""))),
		filter_mode,
		sort_mode,
		"\n".join(lines)
	]
	_rebuild_actions(visible_items)
	var selected_def := ContentRegistry.get_definition("items", selected_item_id)
	if selected_def.is_empty():
		message_label.text = "Select an item."
	else:
		message_label.text = _item_summary(selected_item_id, selected_def)
	reward_label.text = _reward_summary()

func _rebuild_actions(visible_items: Array[String]) -> void:
	for child in action_box.get_children():
		child.queue_free()
	for item_id in visible_items:
		var item_def := ContentRegistry.get_definition("items", item_id)
		var select_button := Button.new()
		select_button.text = _item_display_name(item_id, item_def)
		select_button.pressed.connect(func() -> void:
			selected_item_id = item_id
			refresh()
		)
		action_box.add_child(select_button)
	if selected_item_id != "":
		var item_def := ContentRegistry.get_definition("items", selected_item_id)
		var equip_slot := String(item_def.get("equipSlot", ""))
		if equip_slot != "" and SaveService.is_item_identified(slot, selected_item_id):
			var equip_button := Button.new()
			equip_button.text = "Equip %s" % String(item_def.get("name", selected_item_id))
			equip_button.pressed.connect(func() -> void:
				var result := SaveService.equip_item(slot, selected_item_id)
				message_label.text = String(result.get("message", ""))
				refresh()
			)
			action_box.add_child(equip_button)
		elif equip_slot != "":
			var info := Label.new()
			info.text = "Identify this relic before equipping."
			action_box.add_child(info)
	for equip_slot in ["weapon", "trinket"]:
		var equipped_item_id := String(SaveService.equipment(slot).get(equip_slot, ""))
		if equipped_item_id == "":
			continue
		var unequip_button := Button.new()
		unequip_button.text = "Unequip %s" % _equipped_item_name(equipped_item_id)
		unequip_button.pressed.connect(func() -> void:
			var result := SaveService.unequip_item(slot, equip_slot)
			message_label.text = String(result.get("message", ""))
			refresh()
		)
		action_box.add_child(unequip_button)

func _visible_item_ids(inventory_data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for item_id_variant in inventory_data.keys():
		var item_id := String(item_id_variant)
		var item_def := ContentRegistry.get_definition("items", item_id)
		if not _matches_search(item_id, item_def):
			continue
		if not _matches_filter(item_def):
			continue
		result.append(item_id)
	result.sort_custom(func(a: String, b: String) -> bool:
		return _compare_items(a, b, inventory_data)
	)
	return result

func _matches_search(item_id: String, item_def: Dictionary) -> bool:
	if search_query == "":
		return true
	var haystacks := [
		_item_display_name(item_id, item_def).to_lower(),
		String(item_def.get("name", item_id)).to_lower(),
		String(item_def.get("kind", "")).to_lower()
	]
	for text in haystacks:
		if text.contains(search_query):
			return true
	return false

func _matches_filter(item_def: Dictionary) -> bool:
	match filter_mode:
		"consumable", "key", "quest", "supply":
			return String(item_def.get("kind", "")) == filter_mode
		"equippable":
			return String(item_def.get("equipSlot", "")) != ""
	return true

func _compare_items(a: String, b: String, inventory_data: Dictionary) -> bool:
	var a_def := ContentRegistry.get_definition("items", a)
	var b_def := ContentRegistry.get_definition("items", b)
	match sort_mode:
		"quantity":
			var a_qty := int(inventory_data.get(a, 0))
			var b_qty := int(inventory_data.get(b, 0))
			if a_qty == b_qty:
				return _item_display_name(a, a_def) < _item_display_name(b, b_def)
			return a_qty > b_qty
		"kind":
			var a_kind := String(a_def.get("kind", ""))
			var b_kind := String(b_def.get("kind", ""))
			if a_kind == b_kind:
				return _item_display_name(a, a_def) < _item_display_name(b, b_def)
			return a_kind < b_kind
		"price":
			var a_price := int(a_def.get("price", 0))
			var b_price := int(b_def.get("price", 0))
			if a_price == b_price:
				return _item_display_name(a, a_def) < _item_display_name(b, b_def)
			return a_price > b_price
	return _item_display_name(a, a_def) < _item_display_name(b, b_def)

func _item_display_name(item_id: String, item_def: Dictionary) -> String:
	if not SaveService.is_item_identified(slot, item_id):
		var unknown_name := String(item_def.get("unknownName", "Unknown %s" % item_def.get("kind", "Item")))
		return unknown_name
	return String(item_def.get("name", item_id))

func _equipped_item_name(item_id: String) -> String:
	if item_id == "":
		return "-"
	var item_def := ContentRegistry.get_definition("items", item_id)
	return _item_display_name(item_id, item_def)

func _item_summary(item_id: String, item_def: Dictionary) -> String:
	if item_def.is_empty():
		return "Select an item."
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % _item_display_name(item_id, item_def))
	lines.append("kind: %s / price: %d" % [String(item_def.get("kind", "item")), int(item_def.get("price", 0))])
	if SaveService.is_item_identified(slot, item_id):
		if String(item_def.get("description", "")).strip_edges() != "":
			lines.append(String(item_def.get("description", "")))
		var equip_slot := String(item_def.get("equipSlot", ""))
		if equip_slot != "":
			lines.append("equip: %s" % equip_slot)
			lines.append(_compare_against_equipped(item_id, item_def, equip_slot))
		if int(item_def.get("powerBonus", 0)) != 0:
			lines.append("power bonus: %+d" % int(item_def.get("powerBonus", 0)))
		if String(item_def.get("resistBonus", "")).strip_edges() != "":
			lines.append("resist: %s" % String(item_def.get("resistBonus", "")))
		if String(item_def.get("curseStatus", "")).strip_edges() != "":
			lines.append("curse: %s" % String(item_def.get("curseStatus", "")))
	else:
		lines.append("This relic has not been identified.")
	return "\n".join(lines)

func _compare_against_equipped(item_id: String, item_def: Dictionary, equip_slot: String) -> String:
	var equipped_item_id := String(SaveService.equipment(slot).get(equip_slot, ""))
	if equipped_item_id == "":
		return "compare: empty slot"
	if equipped_item_id == item_id:
		return "compare: already equipped"
	var equipped_def := ContentRegistry.get_definition("items", equipped_item_id)
	var compare_lines: Array[String] = []
	compare_lines.append("compare vs %s" % _item_display_name(equipped_item_id, equipped_def))
	compare_lines.append("power %+d -> %+d" % [int(equipped_def.get("powerBonus", 0)), int(item_def.get("powerBonus", 0))])
	compare_lines.append("resist %s -> %s" % [
		String(equipped_def.get("resistBonus", "-")),
		String(item_def.get("resistBonus", "-"))
	])
	return " / ".join(compare_lines)

func _reward_summary() -> String:
	var rows := SaveService.recent_rewards(slot)
	if rows.is_empty():
		return "[b]Recent Rewards[/b]\nNo recent rewards."
	var lines: Array[String] = ["[b]Recent Rewards[/b]"]
	for row in rows:
		lines.append("- %s: %s" % [String(row.get("label", row.get("source", "reward"))), String(row.get("summary", ""))])
	return "\n".join(lines)

func _close() -> void:
	if close_callback.is_valid():
		close_callback.call()
	queue_free()

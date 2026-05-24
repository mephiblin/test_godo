extends Control

var slot := 1
var placement: Dictionary = {}
var close_callback: Callable
var message_label: RichTextLabel
var action_box: VBoxContainer
var active_service: Dictionary = {}
var active_dialogue_step_id := ""

func configure(target_slot: int, target_placement: Dictionary, callback: Callable) -> Control:
	slot = target_slot
	placement = target_placement.duplicate(true)
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
	panel.offset_left = 180
	panel.offset_top = 120
	panel.custom_minimum_size = Vector2(520, 320)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var title := Label.new()
	title.text = _service_title()
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)

	message_label = RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.custom_minimum_size = Vector2(480, 120)
	layout.add_child(message_label)

	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 8)
	layout.add_child(action_box)

	_build_actions()

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_overlay)
	layout.add_child(close_button)

	_refresh_message(_service_intro())

func _build_actions() -> void:
	for child in action_box.get_children():
		child.queue_free()
	if _dialogue_active():
		_build_dialogue_actions()
		return
	if _show_npc_service_menu():
		_build_npc_service_menu()
		return
	match _current_service_type():
		"quest_board":
			var board_summary := QuestService.quest_board_summary(slot)
			for offer in board_summary.get("offers", []):
				if typeof(offer) != TYPE_DICTIONARY:
					continue
				var offer_row: Dictionary = offer
				var accept_button := Button.new()
				accept_button.text = "Accept %s (%d gold)" % [
					String(offer_row.get("name", offer_row.get("id", ""))),
					int(offer_row.get("rewardGold", 0))
				]
				accept_button.disabled = bool(board_summary.get("hasActiveQuest", false))
				var quest_id := String(offer_row.get("id", ""))
				accept_button.pressed.connect(func() -> void:
					_accept_quest(quest_id)
				)
				action_box.add_child(accept_button)
				var offer_label := Label.new()
				offer_label.text = "%s -> %s" % [
					String(offer_row.get("note", "")),
					String(offer_row.get("targetMonsterName", offer_row.get("targetMonsterId", "")))
				]
				action_box.add_child(offer_label)

			var reward_button := Button.new()
			reward_button.text = "Claim Reward"
			reward_button.pressed.connect(_claim_reward)
			reward_button.disabled = not bool(board_summary.get("claimable", false))
			action_box.add_child(reward_button)

			var refresh_button := Button.new()
			refresh_button.text = "Refresh Board"
			refresh_button.disabled = bool(board_summary.get("hasActiveQuest", false))
			refresh_button.pressed.connect(_refresh_quest_board)
			action_box.add_child(refresh_button)
			if not active_service.is_empty():
				_add_back_button()
		"healer", "heal":
			var heal_button := Button.new()
			heal_button.text = "Heal Party"
			heal_button.pressed.connect(_heal_party)
			action_box.add_child(heal_button)
			if not active_service.is_empty():
				_add_back_button()
		"trade":
			var vendor_id := _service_vendor_id()
			var vendor_def := ContentRegistry.get_definition("vendors", vendor_id)
			for item_id_variant in vendor_def.get("items", []):
				var item_id := String(item_id_variant)
				var item_def := ContentRegistry.get_definition("items", item_id)
				if item_def.is_empty():
					continue
				var price := int(item_def.get("price", vendor_def.get("price", 0)))
				var buy_button := Button.new()
				buy_button.text = "Buy %s (%d gold)" % [String(item_def.get("name", item_id)), price]
				buy_button.pressed.connect(func() -> void:
					_buy_vendor_item(item_id)
				)
				action_box.add_child(buy_button)
			if not active_service.is_empty():
				_add_back_button()
		"skill_shop":
			var vendor_id := _service_vendor_id()
			var vendor_def := ContentRegistry.get_definition("vendors", vendor_id)
			var stock := ShopService.ensure_skill_shop_stock(slot, vendor_id, vendor_def)
			if stock.is_empty():
				var empty_label := Label.new()
				empty_label.text = "No skills available."
				action_box.add_child(empty_label)
			for row in stock:
				if typeof(row) != TYPE_DICTIONARY:
					continue
				var buy_button := Button.new()
				var skill_id := String(row.get("skillId", ""))
				var skill_name := String(row.get("name", skill_id))
				var price := int(row.get("price", 0))
				buy_button.text = "Buy %s (%d gold)" % [skill_name, price]
				buy_button.pressed.connect(func() -> void:
					_buy_skill(skill_id)
				)
				action_box.add_child(buy_button)
			var refresh_button := Button.new()
			refresh_button.text = "Refresh Stock"
			refresh_button.pressed.connect(_refresh_skill_shop)
			action_box.add_child(refresh_button)
			if not active_service.is_empty():
				_add_back_button()
		"quest":
			var info_label := Label.new()
			info_label.text = "Quest notes ready."
			action_box.add_child(info_label)
			if String(placement.get("questId", "")) != "":
				var accept_button := Button.new()
				accept_button.text = "Accept Quest"
				accept_button.pressed.connect(_accept_quest)
				action_box.add_child(accept_button)
				var reward_button := Button.new()
				reward_button.text = "Claim Reward"
				reward_button.pressed.connect(_claim_reward)
				action_box.add_child(reward_button)
			for seed_variant in ContentRegistry.get_definition("npcs", String(placement.get("npcId", ""))).get("questSeeds", []):
				if typeof(seed_variant) != TYPE_DICTIONARY:
					continue
				var seed: Dictionary = seed_variant
				var seed_id := String(seed.get("id", ""))
				if seed_id == "":
					continue
				var offer := QuestService.describe_quest_seed_offer(slot, String(placement.get("npcId", "")), seed_id)
				var accept_seed := Button.new()
				accept_seed.text = "Accept %s" % String(seed.get("title", seed_id))
				accept_seed.pressed.connect(func() -> void:
					_accept_quest_seed(seed_id)
				)
				accept_seed.disabled = not bool(offer.get("available", false))
				action_box.add_child(accept_seed)
				var claim_seed := Button.new()
				claim_seed.text = "Claim %s Reward" % String(seed.get("title", seed_id))
				claim_seed.pressed.connect(func() -> void:
					_claim_quest_seed_reward(seed_id)
				)
				claim_seed.disabled = not bool(offer.get("claimable", false))
				action_box.add_child(claim_seed)
			_add_back_button()
		"fight":
			var fight_button := Button.new()
			fight_button.text = String(active_service.get("label", "Fight"))
			fight_button.pressed.connect(_start_fight_service)
			action_box.add_child(fight_button)
			var avoid_button := Button.new()
			avoid_button.text = String(active_service.get("avoidLabel", "Avoid"))
			avoid_button.pressed.connect(_avoid_fight_service)
			action_box.add_child(avoid_button)
			_add_back_button()

func _build_npc_service_menu() -> void:
	for service_state in NpcService.describe_services_for_slot(slot, String(placement.get("npcId", ""))):
		var service: Dictionary = service_state.get("service", {})
		var button := Button.new()
		button.text = String(service.get("label", service.get("type", "Service")))
		button.disabled = not bool(service_state.get("available", false))
		button.pressed.connect(func() -> void:
			_select_service(service)
		)
		action_box.add_child(button)
		var reason := String(service_state.get("reason", ""))
		if reason != "":
			var reason_label := Label.new()
			reason_label.text = reason
			reason_label.modulate = Color(0.78, 0.67, 0.49)
			action_box.add_child(reason_label)

func _build_dialogue_actions() -> void:
	var result := NpcService.resolve_dialogue_step(active_service.get("dialogue", {}), active_dialogue_step_id)
	if not bool(result.get("ok", false)):
		_refresh_message(String(result.get("message", "Dialogue error.")))
		_reset_to_root()
		return
	var step: Dictionary = result.get("step", {})
	for index in range(step.get("choices", []).size()):
		var choice: Dictionary = step.get("choices", [])[index]
		var button := Button.new()
		button.text = String(choice.get("label", "Continue"))
		button.pressed.connect(func() -> void:
			_choose_dialogue(index)
		)
		action_box.add_child(button)
	_add_back_button()

func _select_service(service: Dictionary) -> void:
	active_service = service.duplicate(true)
	active_dialogue_step_id = ""
	match String(active_service.get("type", "")):
		"talk":
			var dialogue_result := NpcService.start_dialogue(active_service)
			if bool(dialogue_result.get("ok", false)) and dialogue_result.has("stepId"):
				active_dialogue_step_id = String(dialogue_result.get("stepId", ""))
				_build_actions()
				_refresh_message(_dialogue_message(dialogue_result.get("step", {}), String(active_service.get("note", ""))))
			else:
				_refresh_message(String(dialogue_result.get("message", active_service.get("note", "Nothing to say."))))
				_reset_to_root()
		"identify":
			var identify_result := NpcService.identify_item(slot, String(placement.get("npcId", "")), active_service)
			_refresh_message(String(identify_result.get("message", "")))
			_reset_to_root()
		"recruit":
			var recruit_result := NpcService.recruit_companion(slot, String(placement.get("npcId", "")), active_service)
			_refresh_message(String(recruit_result.get("message", "")))
			_reset_to_root()
		"quest":
			_build_actions()
			_refresh_message(_quest_notes_text())
		"fight":
			_build_actions()
			_refresh_message(_service_intro())
		"route_info":
			var route_result := NpcService.inspect_route(slot, active_service)
			_refresh_message(String(route_result.get("message", "Missing route information.")))
			_reset_to_root()
		"ending_report":
			var ending_result := NpcService.inspect_ending(slot, active_service)
			_refresh_message(String(ending_result.get("message", "Missing ending report.")))
			_reset_to_root()
		_:
			_build_actions()
			_refresh_message(_service_intro())

func _choose_dialogue(choice_index: int) -> void:
	var result := NpcService.choose_dialogue(active_service, active_dialogue_step_id, choice_index)
	if not bool(result.get("ok", false)):
		_refresh_message(String(result.get("message", "Dialogue error.")))
		_reset_to_root()
		return
	if bool(result.get("done", false)):
		_refresh_message(String(result.get("note", "The conversation ends.")))
		_reset_to_root()
		return
	active_dialogue_step_id = String(result.get("stepId", ""))
	_refresh_message(_dialogue_message(result.get("step", {}), String(result.get("fromChoice", {}).get("note", ""))))
	_build_actions()

func _accept_quest(quest_id: String = "") -> void:
	var resolved_quest_id := quest_id
	if resolved_quest_id == "":
		resolved_quest_id = String(placement.get("questId", ""))
	var result := QuestService.accept_quest(slot, resolved_quest_id)
	_build_actions()
	_refresh_message(String(result.get("message", "")))

func _claim_reward() -> void:
	var result := QuestService.claim_reward(slot)
	_build_actions()
	_refresh_message(String(result.get("message", "")))

func _refresh_quest_board() -> void:
	QuestService.refresh_board(slot)
	_build_actions()
	_refresh_message("Refreshed quest board offers.")

func _accept_quest_seed(quest_seed_id: String) -> void:
	var result := QuestService.accept_quest_seed(slot, String(placement.get("npcId", "")), quest_seed_id)
	_refresh_message(String(result.get("message", "")))

func _claim_quest_seed_reward(quest_seed_id: String) -> void:
	var result := QuestService.claim_quest_seed_reward(slot, String(placement.get("npcId", "")), quest_seed_id)
	_refresh_message(String(result.get("message", "")))

func _heal_party() -> void:
	var data: Dictionary = SaveService.load_slot(slot)
	var resources: Dictionary = data.get("resources", {})
	var gold := int(resources.get("gold", 0))
	var cost := _service_cost(10)
	if gold < cost:
		_refresh_message("Not enough gold to heal.")
		return
	var party_state: Dictionary = data.get("partyState", {})
	var front: Dictionary = party_state.get("front", {})
	resources["gold"] = gold - cost
	front["hp"] = int(front.get("maxHp", 20))
	var cure_status := String(active_service.get("cureStatus", ""))
	if cure_status != "":
		var statuses: Array = front.get("statuses", [])
		statuses.erase(cure_status)
		front["statuses"] = statuses
	party_state["front"] = front
	data["resources"] = resources
	data["partyState"] = party_state
	SaveService.save_slot(slot, data)
	_refresh_message("Party healed for %d gold." % cost)

func _buy_skill(skill_id: String) -> void:
	var result := ShopService.buy_skill(slot, String(placement.get("vendorId", "")), skill_id)
	if bool(result.get("ok", false)):
		_build_actions()
	_refresh_message(String(result.get("message", "")))

func _refresh_skill_shop() -> void:
	var vendor_id := _service_vendor_id()
	var vendor_def := ContentRegistry.get_definition("vendors", vendor_id)
	ShopService.reroll_skill_shop_stock(slot, vendor_id, vendor_def)
	_build_actions()
	_refresh_message("Refreshed skill stock.")

func _buy_vendor_item(item_id: String) -> void:
	var result := ShopService.buy_vendor_item(slot, _service_vendor_id(), item_id, 1)
	_refresh_message(String(result.get("message", "")))

func _start_fight_service() -> void:
	var save_data: Dictionary = SaveService.load_slot(slot)
	var runtime: Dictionary = save_data.get("runtime", {})
	var context := NpcService.build_fight_context(
		slot,
		String(placement.get("npcId", "")),
		active_service,
		String(save_data.get("mode", GameApp.MODE_DUNGEON)),
		String(runtime.get("mapId", "dungeon_floor_01"))
	)
	if context.is_empty():
		_refresh_message("Missing encounter definition.")
		return
	_close_overlay()
	GameApp.enter_combat(context)

func _avoid_fight_service() -> void:
	var result := NpcService.avoid_fight(slot, String(placement.get("npcId", "")), active_service)
	_refresh_message(String(result.get("message", "")))

func _refresh_message(prefix: String) -> void:
	var data: Dictionary = SaveService.load_slot(slot)
	var quest_state: Dictionary = data.get("quest", {})
	var resources: Dictionary = data.get("resources", {})
	var companion: Dictionary = data.get("companion", {})
	var npc_state: Dictionary = data.get("npcState", {})
	var quest_seed_states: Dictionary = data.get("questSeeds", {})
	var stock_text := ""
	if _current_service_type() == "skill_shop":
		var stock_lines: Array[String] = []
		for row in ShopService.current_skill_shop_stock(slot, _service_vendor_id()):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			stock_lines.append("%s (%d)" % [String(row.get("name", row.get("skillId", ""))), int(row.get("price", 0))])
		stock_text = "\n[b]Stock[/b] %s" % ", ".join(stock_lines) if not stock_lines.is_empty() else "\n[b]Stock[/b] none"
	elif _current_service_type() == "trade":
		var vendor_def := ContentRegistry.get_definition("vendors", _service_vendor_id())
		var item_lines: Array[String] = []
		for item_id_variant in vendor_def.get("items", []):
			var item_id := String(item_id_variant)
			var item_def := ContentRegistry.get_definition("items", item_id)
			if item_def.is_empty():
				continue
			item_lines.append("%s (%d)" % [String(item_def.get("name", item_id)), int(item_def.get("price", 0))])
		stock_text = "\n[b]Goods[/b] %s" % ", ".join(item_lines) if not item_lines.is_empty() else "\n[b]Goods[/b] none"
	elif _current_service_type() == "quest_board":
		var offer_lines: Array[String] = []
		for offer in QuestService.quest_board_summary(slot).get("offers", []):
			if typeof(offer) != TYPE_DICTIONARY:
				continue
			var offer_row: Dictionary = offer
			offer_lines.append("%s -> %s (%d gold)" % [
				String(offer_row.get("name", offer_row.get("id", ""))),
				String(offer_row.get("targetMonsterName", offer_row.get("targetMonsterId", ""))),
				int(offer_row.get("rewardGold", 0))
			])
		stock_text = "\n[b]Board Offers[/b] %s" % "\n".join(offer_lines) if not offer_lines.is_empty() else "\n[b]Board Offers[/b] none"
	var identified_items: Dictionary = npc_state.get("identifiedItems", {})
	var base_text := "%s\n\n%s\n\n[b]Gold[/b] %d\n[b]Quest[/b] %s / %s\n[b]Quest Seeds[/b] %s\n[b]Skills[/b] %s\n[b]Companion[/b] %s\n[b]Identified[/b] %s" % [
		prefix,
		_service_body(),
		int(resources.get("gold", 0)),
		String(quest_state.get("name", "none")),
		String(quest_state.get("status", "none")),
		str(quest_seed_states),
		str(data.get("knownSkills", [])),
		String(companion.get("name", "none")),
		str(identified_items.keys())
	]
	message_label.text = base_text + stock_text

func _close_overlay() -> void:
	if close_callback.is_valid():
		close_callback.call()
	queue_free()

func smoke_select_service_type(service_type: String) -> void:
	if not _show_npc_service_menu():
		return
	for service_state in NpcService.describe_services_for_slot(slot, String(placement.get("npcId", ""))):
		var service: Dictionary = service_state.get("service", {})
		if String(service.get("type", "")) != service_type:
			continue
		if not bool(service_state.get("available", false)):
			return
		_select_service(service)
		return

func _service_title() -> String:
	var npc := ContentRegistry.get_definition("npcs", String(placement.get("npcId", "")))
	return String(npc.get("name", placement.get("label", "Service")))

func _service_intro() -> String:
	var npc := ContentRegistry.get_definition("npcs", String(placement.get("npcId", "")))
	if not active_service.is_empty() and String(active_service.get("note", "")).strip_edges() != "":
		return String(active_service.get("note", ""))
	var description := String(npc.get("description", "Choose a service."))
	return description if description != "" else "Choose a service."

func _service_body() -> String:
	var npc := ContentRegistry.get_definition("npcs", String(placement.get("npcId", "")))
	var vendor := ContentRegistry.get_definition("vendors", _service_vendor_id())
	var lines: Array[String] = []
	if String(npc.get("log", "")) != "":
		lines.append(String(npc.get("log", "")))
	if not active_service.is_empty() and String(active_service.get("note", "")).strip_edges() != "":
		lines.append(String(active_service.get("note", "")))
	if String(vendor.get("summary", "")) != "":
		lines.append(String(vendor.get("summary", "")))
	return "\n".join(lines)

func _service_cost(fallback: int) -> int:
	if not active_service.is_empty():
		var cost_row: Dictionary = active_service.get("cost", {})
		if not cost_row.is_empty():
			return int(cost_row.get("gold", fallback))
	var vendor := ContentRegistry.get_definition("vendors", _service_vendor_id())
	return int(vendor.get("price", vendor.get("cost", {}).get("gold", fallback)))

func _show_npc_service_menu() -> bool:
	return String(placement.get("type", "")) == "npc_service" and active_service.is_empty() and not _dialogue_active()

func _current_service_type() -> String:
	return String(active_service.get("type", placement.get("type", "")))

func _service_vendor_id() -> String:
	return String(active_service.get("vendorId", placement.get("vendorId", "")))

func _dialogue_active() -> bool:
	return active_dialogue_step_id != ""

func _add_back_button() -> void:
	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_reset_to_root)
	action_box.add_child(back_button)

func _reset_to_root() -> void:
	active_service.clear()
	active_dialogue_step_id = ""
	_build_actions()

func _dialogue_message(step: Dictionary, suffix: String = "") -> String:
	var lines: Array[String] = []
	if String(step.get("title", "")).strip_edges() != "":
		lines.append("[b]%s[/b]" % String(step.get("title", "")))
	if String(step.get("text", "")).strip_edges() != "":
		lines.append(String(step.get("text", "")))
	if suffix.strip_edges() != "":
		lines.append(suffix)
	return "\n\n".join(lines)

func _quest_notes_text() -> String:
	var npc := ContentRegistry.get_definition("npcs", String(placement.get("npcId", "")))
	var lines: Array[String] = []
	lines.append("progression: %d" % QuestService.progression_bosses_defeated(slot))
	for hook in npc.get("questHooks", []):
		if typeof(hook) == TYPE_DICTIONARY and QuestService.hook_visible_for_slot(slot, hook) and String(hook.get("note", "")).strip_edges() != "":
			lines.append("- %s" % String(hook.get("note", "")))
	for seed in npc.get("questSeeds", []):
		if typeof(seed) != TYPE_DICTIONARY:
			continue
		var seed_id := String(seed.get("id", ""))
		var offer := QuestService.describe_quest_seed_offer(slot, String(placement.get("npcId", "")), seed_id)
		if not bool(offer.get("available", false)) and not bool(offer.get("claimable", false)) and String(offer.get("state", {}).get("status", "")) == "" and String(offer.get("reason", "")) == "Progression requirement not met.":
			continue
		lines.append("[b]%s[/b]" % String(seed.get("title", seed.get("id", "Quest Seed"))))
		if String(seed.get("note", "")).strip_edges() != "":
			lines.append(String(seed.get("note", "")))
		var quest_seed_state: Dictionary = offer.get("state", {})
		lines.append("status: %s" % String(quest_seed_state.get("status", "none")))
		if String(offer.get("reason", "")).strip_edges() != "":
			lines.append("gate: %s" % String(offer.get("reason", "")))
	return "\n".join(lines) if not lines.is_empty() else "No additional quest notes."

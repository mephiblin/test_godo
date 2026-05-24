extends Node

func list_services(npc_id: String) -> Array[Dictionary]:
	var npc_def := ContentRegistry.get_definition("npcs", npc_id)
	var result: Array[Dictionary] = []
	for row in npc_def.get("services", []):
		if typeof(row) == TYPE_DICTIONARY:
			result.append(row)
	return result

func list_services_for_slot(slot: int, npc_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for service_state in describe_services_for_slot(slot, npc_id):
		if bool(service_state.get("available", false)):
			result.append(service_state.get("service", {}))
	return result

func describe_services_for_slot(slot: int, npc_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for service in list_services(npc_id):
		var reason := _service_lock_reason(slot, npc_id, service)
		result.append({
			"service": service,
			"available": reason == "",
			"reason": reason
	})
	return result

func inspect_route(slot: int, service_def: Dictionary = {}) -> Dictionary:
	var placement := _find_route_placement(service_def, slot)
	if placement.is_empty():
		return {"ok": false, "message": "Missing route placement."}
	var blocked_message := _route_block_message_for_slot(slot, placement)
	var is_open := blocked_message == ""
	var note_key := "openNote" if is_open else "blockedNote"
	var note := String(service_def.get(note_key, ""))
	var target_map_id := String(placement.get("targetMapId", ""))
	var route_label := String(placement.get("label", placement.get("id", "Route")))
	var summary := "%s -> %s [%s]" % [
		route_label,
		target_map_id,
		"open" if is_open else "locked"
	]
	var lines: Array[String] = [summary]
	if blocked_message != "":
		lines.append(blocked_message)
	if note != "":
		lines.append(note)
	return {
		"ok": true,
		"open": is_open,
		"message": "\n".join(lines),
		"placement": placement,
		"blockedMessage": blocked_message
	}

func inspect_ending(slot: int, service_def: Dictionary = {}) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var meta: Dictionary = data.get("meta", {})
	var flags: Dictionary = data.get("flags", {})
	var quest_seeds: Dictionary = data.get("questSeeds", {})
	var front: Dictionary = data.get("partyState", {}).get("front", {})
	var resources: Dictionary = data.get("resources", {})
	var lines: Array[String] = []
	var cleared := bool(meta.get("campaignCleared", false)) or bool(flags.get("campaignCleared", false))
	if not cleared:
		lines.append("The final expedition record is still incomplete.")
	else:
		lines.append("[b]%s[/b]" % String(meta.get("endingTitle", "Expedition Cleared")))
		lines.append("Cleared at %s." % String(meta.get("clearedAt", meta.get("updatedAt", ""))))
	lines.append(String(service_def.get("note", "")))
	lines.append("Quest seeds: mural=%s, black_water=%s" % [
		String(quest_seeds.get("quest_seed_black_mural", {}).get("status", "none")),
		String(quest_seeds.get("quest_seed_black_water_vow", {}).get("status", "none"))
	])
	lines.append("Front HP %d/%d  status %s" % [
		int(front.get("hp", 0)),
		int(front.get("maxHp", 0)),
		str(front.get("statuses", []))
	])
	lines.append("Gold %d  XP %d" % [
		int(resources.get("gold", 0)),
		int(data.get("partyState", {}).get("partyXp", 0))
	])
	lines.append("Companion %s" % String(data.get("companion", {}).get("name", "none")))
	return {
		"ok": true,
		"cleared": cleared,
		"message": "\n".join(lines)
	}

func identify_item(slot: int, npc_id: String, service_def: Dictionary = {}, preferred_item_id: String = "") -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var cost := int(service_def.get("cost", {}).get("gold", 0))
	var resources: Dictionary = data.get("resources", {})
	var gold := int(resources.get("gold", 0))
	if gold < cost:
		return {"ok": false, "message": "Not enough gold to identify."}
	var npc_state := _ensure_npc_state(data)
	var identified_items := _ensure_nested_dictionary(npc_state, "identifiedItems")
	var inventory_data: Dictionary = data.get("inventory", {})
	var item_id := preferred_item_id
	if item_id == "" or not inventory_data.has(item_id) or bool(identified_items.get(item_id, false)):
		item_id = _first_unidentified_item_id(inventory_data, identified_items)
	if item_id == "":
		return {"ok": false, "message": "No unidentified relic in inventory."}
	var item_def := ContentRegistry.get_definition("items", item_id)
	resources["gold"] = gold - cost
	data["resources"] = resources
	identified_items[item_id] = true
	npc_state[npc_id] = {
		"lastService": "identify",
		"updatedAt": Time.get_datetime_string_from_system()
	}
	data["npcState"] = npc_state
	SaveService.save_slot(slot, data)
	var messages: Array[String] = ["%s identified %s." % [npc_id, String(item_def.get("name", item_id))]]
	if String(item_def.get("curseStatus", "")).strip_edges() != "":
		messages.append("The relic carries %s." % String(item_def.get("curseStatus", "")))
	return {
		"ok": true,
		"message": " ".join(messages),
		"itemId": item_id
	}

func recruit_companion(slot: int, npc_id: String, service_def: Dictionary = {}) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var npc_state := _ensure_npc_state(data)
	var npc_row: Dictionary = npc_state.get(npc_id, {})
	if bool(npc_row.get("recruited", false)):
		return {"ok": false, "message": "Companion already recruited."}
	var existing_companion: Dictionary = data.get("companion", {})
	if not existing_companion.is_empty():
		return {"ok": false, "message": "A companion is already traveling with the party."}
	var profile: Dictionary = service_def.get("companionProfile", {})
	if profile.is_empty():
		return {"ok": false, "message": "Missing companion profile."}
	var class_id := _class_id_from_index(int(profile.get("classIndex", 0)))
	var companion := {
		"name": String(profile.get("name", "Companion")),
		"classId": class_id,
		"backgroundId": "outcast",
		"sourceNpcId": npc_id,
		"note": String(profile.get("note", ""))
	}
	data["companion"] = companion
	var party: Dictionary = data.get("party", {})
	var members: Array = party.get("members", [])
	members.append(companion)
	party["members"] = members
	data["party"] = party
	npc_state[npc_id] = {
		"recruited": true,
		"updatedAt": Time.get_datetime_string_from_system()
	}
	data["npcState"] = npc_state
	SaveService.save_slot(slot, data)
	return {
		"ok": true,
		"message": "%s joined the expedition." % String(profile.get("name", "Companion")),
		"companion": companion
	}

func avoid_fight(slot: int, npc_id: String, service_def: Dictionary = {}) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var avoid_cost := int(service_def.get("avoidCost", {}).get("gold", 0))
	var resources: Dictionary = data.get("resources", {})
	var gold := int(resources.get("gold", 0))
	if gold < avoid_cost:
		return {"ok": false, "message": "Not enough gold to avoid the fight."}
	resources["gold"] = gold - avoid_cost
	data["resources"] = resources
	var flags: Dictionary = data.get("flags", {})
	var avoid_flag := String(service_def.get("avoidFlag", ""))
	if avoid_flag != "":
		flags[avoid_flag] = true
	data["flags"] = flags
	var npc_state := _ensure_npc_state(data)
	npc_state[npc_id] = {
		"lastService": "avoid_fight",
		"updatedAt": Time.get_datetime_string_from_system()
	}
	data["npcState"] = npc_state
	SaveService.save_slot(slot, data)
	return {"ok": true, "message": String(service_def.get("avoidLog", "Avoided the fight."))}

func build_fight_context(slot: int, npc_id: String, service_def: Dictionary = {}, return_route: String = GameApp.MODE_DUNGEON, return_map_id: String = "dungeon_floor_01") -> Dictionary:
	var encounter_id := String(service_def.get("encounterId", ""))
	var encounter := ContentRegistry.get_definition("encounters", encounter_id)
	if encounter.is_empty():
		return {}
	var enemies: Array = encounter.get("enemies", [])
	var primary_monster_id := ""
	if not enemies.is_empty() and typeof(enemies[0]) == TYPE_DICTIONARY:
		primary_monster_id = String(enemies[0].get("monsterId", ""))
	var victory_flag := String(service_def.get("victoryFlag", ""))
	if victory_flag == "":
		victory_flag = "npc_fight_%s_cleared" % npc_id
	return {
		"slot": slot,
		"npc_id": npc_id,
		"monster_instance_id": "npc_fight:%s" % npc_id,
		"monster_id": primary_monster_id,
		"monster_name": String(encounter.get("name", service_def.get("label", "NPC Fight"))),
		"return_route": return_route,
		"return_map_id": return_map_id,
		"victory_flag": victory_flag
	}

func start_dialogue(service_def: Dictionary = {}) -> Dictionary:
	var dialogue: Dictionary = service_def.get("dialogue", {})
	if dialogue.is_empty():
		return {"ok": false, "message": String(service_def.get("note", "Nothing to say."))}
	return resolve_dialogue_step(dialogue, String(dialogue.get("entryStepId", "")))

func choose_dialogue(service_def: Dictionary, step_id: String, choice_index: int) -> Dictionary:
	var dialogue: Dictionary = service_def.get("dialogue", {})
	if dialogue.is_empty():
		return {"ok": false, "message": "Missing dialogue definition."}
	var step_result := resolve_dialogue_step(dialogue, step_id)
	if not bool(step_result.get("ok", false)):
		return step_result
	var step: Dictionary = step_result.get("step", {})
	var choices: Array = step.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "message": "Invalid dialogue choice."}
	var choice: Dictionary = choices[choice_index]
	var next_step_id := String(choice.get("nextStepId", ""))
	if next_step_id == "":
		return {
			"ok": true,
			"done": true,
			"note": String(choice.get("note", "")),
			"choice": choice,
			"step": step
		}
	var next_result := resolve_dialogue_step(dialogue, next_step_id)
	next_result["fromChoice"] = choice
	return next_result

func resolve_dialogue_step(dialogue: Dictionary, step_id: String) -> Dictionary:
	if step_id == "":
		return {"ok": false, "message": "Missing dialogue entry step."}
	for step_variant in dialogue.get("steps", []):
		if typeof(step_variant) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_variant
		if String(step.get("id", "")) == step_id:
			return {"ok": true, "step": step, "stepId": step_id}
	return {"ok": false, "message": "Missing dialogue step %s." % step_id}

func _first_unidentified_item_id(inventory_data: Dictionary, identified_items: Dictionary) -> String:
	for item_id_variant in inventory_data.keys():
		var item_id := String(item_id_variant)
		if bool(identified_items.get(item_id, false)):
			continue
		var item_def := ContentRegistry.get_definition("items", item_id)
		var item_kind := String(item_def.get("kind", ""))
		if item_kind in ["artifact", "quest", "key"]:
			return item_id
	return ""

func _class_id_from_index(class_index: int) -> String:
	var classes: Array[Dictionary] = ContentRegistry.list_definitions("classes")
	if class_index >= 0 and class_index < classes.size():
		var class_def: Dictionary = classes[class_index]
		return String(class_def.get("id", "wanderer"))
	return "wanderer"

func _ensure_npc_state(data: Dictionary) -> Dictionary:
	if not data.has("npcState") or typeof(data.get("npcState")) != TYPE_DICTIONARY:
		data["npcState"] = {}
	return data["npcState"]

func _ensure_nested_dictionary(parent: Dictionary, key: String) -> Dictionary:
	if not parent.has(key) or typeof(parent.get(key)) != TYPE_DICTIONARY:
		parent[key] = {}
	return parent[key]

func _service_available(slot: int, npc_id: String, service_def: Dictionary) -> bool:
	return _service_lock_reason(slot, npc_id, service_def) == ""

func _service_lock_reason(slot: int, npc_id: String, service_def: Dictionary) -> String:
	var service_type := String(service_def.get("type", ""))
	var required_flag := String(service_def.get("requiredFlag", ""))
	if required_flag != "":
		var data_for_flag: Dictionary = SaveService.load_slot(slot)
		if not bool(data_for_flag.get("flags", {}).get(required_flag, false)):
			return "Requires flag %s." % required_flag
	var required_bosses := int(service_def.get("bossesDefeatedAtLeast", -1))
	if required_bosses >= 0 and QuestService.progression_bosses_defeated(slot) < required_bosses:
		return "Requires progression %d." % required_bosses
	var required_seed_id := String(service_def.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		var required_seed_status := String(service_def.get("requiredQuestSeedStatus", "active"))
		var seed_state: Dictionary = QuestService.quest_seed_states(slot).get(required_seed_id, {})
		if String(seed_state.get("status", "")) != required_seed_status:
			return "Requires quest seed %s = %s." % [required_seed_id, required_seed_status]
	if service_type == "fight":
		var data: Dictionary = SaveService.load_slot(slot)
		var flags: Dictionary = data.get("flags", {})
		var avoid_flag := String(service_def.get("avoidFlag", ""))
		var victory_flag := String(service_def.get("victoryFlag", ""))
		if victory_flag == "":
			victory_flag = "npc_fight_%s_cleared" % npc_id
		if (avoid_flag != "" and bool(flags.get(avoid_flag, false))) or bool(flags.get(victory_flag, false)):
			return "Already resolved."
	if service_type == "recruit":
		var data: Dictionary = SaveService.load_slot(slot)
		if not data.get("companion", {}).is_empty():
			return "Companion slot already occupied."
	return ""

func _find_route_placement(service_def: Dictionary, slot: int) -> Dictionary:
	var map_id := String(service_def.get("mapId", ""))
	if map_id == "":
		map_id = String(SaveService.load_slot(slot).get("runtime", {}).get("mapId", ""))
	if map_id == "":
		return {}
	var map_data := ContentRegistry.get_map(map_id)
	if map_data.is_empty():
		return {}
	var target_placement_id := String(service_def.get("targetPlacementId", ""))
	var target_map_id := String(service_def.get("targetMapId", ""))
	for placement_variant in map_data.get("placements", []):
		if typeof(placement_variant) != TYPE_DICTIONARY:
			continue
		var placement: Dictionary = placement_variant
		if target_placement_id != "" and String(placement.get("id", "")) == target_placement_id:
			return placement
		if target_map_id != "" and String(placement.get("targetMapId", "")) == target_map_id:
			return placement
	return {}

func _route_block_message_for_slot(slot: int, placement: Dictionary) -> String:
	var slot_data: Dictionary = SaveService.load_slot(slot)
	var required_flag := String(placement.get("requiredFlag", ""))
	if required_flag != "" and not bool(slot_data.get("flags", {}).get(required_flag, false)):
		return String(placement.get("blockedMessage", "The route is still sealed."))
	var required_bosses := int(placement.get("bossesDefeatedAtLeast", 0))
	if required_bosses > 0 and QuestService.progression_bosses_defeated(slot) < required_bosses:
		return String(placement.get("blockedMessage", "Requires progression %d." % required_bosses))
	var required_quest_statuses: Array = placement.get("requiredQuestStatuses", [])
	if not required_quest_statuses.is_empty():
		var quest_status := String(QuestService.current_quest(slot).get("status", "none"))
		if not required_quest_statuses.has(quest_status):
			return String(placement.get("blockedMessage", "The route is still sealed."))
	var required_seed_id := String(placement.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		var required_seed_status := String(placement.get("requiredQuestSeedStatus", "rewarded"))
		var seed_status := String(QuestService.quest_seed_states(slot).get(required_seed_id, {}).get("status", ""))
		if seed_status != required_seed_status:
			return String(placement.get("blockedMessage", "The route is still sealed."))
	return ""

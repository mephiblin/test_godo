extends Node

func apply_event(slot: int, event_id: String, event_def: Dictionary = {}) -> Dictionary:
	if event_def.is_empty():
		event_def = ContentRegistry.get_definition("events", event_id)
	if event_def.is_empty():
		return {"ok": false, "messages": ["Missing event %s." % event_id]}
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "messages": ["Missing save slot %d." % slot]}
	var messages: Array[String] = []
	var changed := false
	for effect in _resolve_event_effects(data, event_def):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var result := _apply_effect(data, effect)
		changed = changed or bool(result.get("changed", false))
		for message in result.get("messages", []):
			messages.append(String(message))
	if changed:
		SaveService.save_slot(slot, data)
	return {
		"ok": true,
		"messages": messages,
		"data": data
	}

func _resolve_event_effects(data: Dictionary, event_def: Dictionary) -> Array:
	var resolved: Array = []
	var entry_step_id := String(event_def.get("entryStepId", ""))
	if entry_step_id == "":
		return event_def.get("effects", [])
	var visited := {}
	var current_step_id := entry_step_id
	while current_step_id != "" and not visited.has(current_step_id):
		visited[current_step_id] = true
		var step := _find_event_step(event_def, current_step_id)
		if step.is_empty():
			break
		for effect in step.get("effects", []):
			resolved.append(effect)
		if step.has("branches"):
			var next_branch := _pick_branch(data, step.get("branches", []))
			if next_branch.is_empty():
				break
			current_step_id = String(next_branch.get("nextStepId", ""))
			continue
		if step.has("choices"):
			var next_choice := _pick_choice(data, step.get("choices", []))
			if next_choice.is_empty():
				break
			for effect in next_choice.get("effects", []):
				resolved.append(effect)
			current_step_id = String(next_choice.get("nextStepId", ""))
			continue
		break
	if resolved.is_empty():
		return event_def.get("effects", [])
	return resolved

func _apply_effect(data: Dictionary, effect: Dictionary) -> Dictionary:
	var kind := String(effect.get("kind", ""))
	var messages: Array[String] = []
	var changed := false
	match kind:
		"log":
			messages.append(String(effect.get("message", "")))
		"heal_party":
			var amount := maxi(int(effect.get("amount", 0)), 0)
			var party_state := _ensure_dictionary(data, "partyState")
			var front := _ensure_dictionary(party_state, "front")
			var max_hp := maxi(int(front.get("maxHp", 20)), 1)
			var hp := clampi(int(front.get("hp", max_hp)) + amount, 0, max_hp)
			front["maxHp"] = max_hp
			front["hp"] = hp
			changed = true
			messages.append("Party recovered %d HP." % amount)
		"damage_front":
			var amount := maxi(int(effect.get("amount", 0)), 0)
			var min_hp := maxi(int(effect.get("minHp", 0)), 0)
			var party_state := _ensure_dictionary(data, "partyState")
			var front := _ensure_dictionary(party_state, "front")
			var max_hp := maxi(int(front.get("maxHp", 20)), 1)
			var hp: int = maxi(min_hp, int(front.get("hp", max_hp)) - amount)
			front["maxHp"] = max_hp
			front["hp"] = hp
			changed = true
			messages.append("Front line took %d damage." % amount)
		"add_status_front":
			var party_state := _ensure_dictionary(data, "partyState")
			var front := _ensure_dictionary(party_state, "front")
			var statuses: Array = front.get("statuses", [])
			var status := String(effect.get("status", ""))
			if _is_status_resisted(data, status):
				messages.append("Front line resisted status %s." % status)
				return {"changed": changed, "messages": messages}
			if status != "" and not statuses.has(status):
				statuses.append(status)
				front["statuses"] = statuses
				changed = true
			if status != "":
				messages.append("Front line gained status %s." % status)
		"cure_status_party":
			var party_state := _ensure_dictionary(data, "partyState")
			var front := _ensure_dictionary(party_state, "front")
			var statuses: Array = front.get("statuses", [])
			var status := String(effect.get("status", ""))
			if status == "":
				return {"changed": changed, "messages": messages}
			if statuses.has(status):
				statuses.erase(status)
				front["statuses"] = statuses
				changed = true
			messages.append("Party cleared status %s." % status)
		"consume_resource":
			var resources := _ensure_dictionary(data, "resources")
			var resource := String(effect.get("resource", ""))
			var amount := maxi(int(effect.get("amount", 0)), 0)
			if resource != "":
				resources[resource] = maxi(int(resources.get(resource, 0)) - amount, 0)
				changed = true
				messages.append("Consumed %s x%d." % [resource, amount])
		"restore_resource":
			var resources := _ensure_dictionary(data, "resources")
			var resource := String(effect.get("resource", ""))
			var amount := maxi(int(effect.get("amount", 0)), 0)
			if resource != "":
				resources[resource] = maxi(int(resources.get(resource, 0)) + amount, 0)
				changed = true
				messages.append("Restored %s x%d." % [resource, amount])
		"grant_item":
			var item_id := String(effect.get("itemId", ""))
			var quantity := maxi(int(effect.get("quantity", 1)), 1)
			if item_id != "":
				var inventory := _ensure_dictionary(data, "inventory")
				inventory[item_id] = int(inventory.get(item_id, 0)) + quantity
				_push_recent_reward(data, {
					"source": "event",
					"label": String(effect.get("label", effect.get("kind", "event"))),
					"items": ["%s x%d" % [item_id, quantity]],
					"summary": "Event reward %s x%d" % [item_id, quantity],
					"recordedAt": Time.get_datetime_string_from_system()
				})
				changed = true
				messages.append("Granted %s x%d." % [item_id, quantity])
		"set_flag":
			var flags := _ensure_dictionary(data, "flags")
			var flag := String(effect.get("flag", ""))
			if flag != "":
				flags[flag] = effect.get("value", true)
				changed = true
				messages.append("Set flag %s." % flag)
		"set_quest_seed_state":
			var quest_seed_id := String(effect.get("questSeedId", ""))
			var status := String(effect.get("status", ""))
			if quest_seed_id != "" and status != "":
				var quest_seeds := _ensure_dictionary(data, "questSeeds")
				var state: Dictionary = quest_seeds.get(quest_seed_id, {"id": quest_seed_id})
				state["status"] = status
				state["updatedAt"] = Time.get_datetime_string_from_system()
				quest_seeds[quest_seed_id] = state
				QuestService.set_quest_seed_state(int(data.get("slot", 0)), quest_seed_id, status)
				changed = true
				messages.append("Quest seed %s -> %s." % [quest_seed_id, status])
		"grant_xp_party":
			var amount := maxi(int(effect.get("amount", 0)), 0)
			var party_state := _ensure_dictionary(data, "partyState")
			party_state["partyXp"] = int(party_state.get("partyXp", 0)) + amount
			changed = true
			messages.append("Party gained %d XP." % amount)
		"mark_done":
			pass
	return {
		"changed": changed,
		"messages": messages
	}

func _ensure_dictionary(parent: Dictionary, key: String) -> Dictionary:
	if not parent.has(key) or typeof(parent.get(key)) != TYPE_DICTIONARY:
		parent[key] = {}
	return parent[key]

func _find_event_step(event_def: Dictionary, step_id: String) -> Dictionary:
	for step_variant in event_def.get("steps", []):
		if typeof(step_variant) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_variant
		if String(step.get("id", "")) == step_id:
			return step
	return {}

func _pick_branch(data: Dictionary, branches: Array) -> Dictionary:
	for branch_variant in branches:
		if typeof(branch_variant) != TYPE_DICTIONARY:
			continue
		var branch: Dictionary = branch_variant
		if _conditions_match(data, branch):
			return branch
	return {}

func _pick_choice(data: Dictionary, choices: Array) -> Dictionary:
	for choice_variant in choices:
		if typeof(choice_variant) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_variant
		if _conditions_match(data, choice):
			return choice
	return {}

func _conditions_match(data: Dictionary, row: Dictionary) -> bool:
	var required_flag := String(row.get("requiredFlag", ""))
	if required_flag != "" and not bool(data.get("flags", {}).get(required_flag, false)):
		return false
	var required_seed_id := String(row.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		var seed_state: Dictionary = data.get("questSeeds", {}).get(required_seed_id, {})
		var required_status := String(row.get("requiredQuestSeedStatus", ""))
		if required_status != "" and String(seed_state.get("status", "")) != required_status:
			return false
	return true

func _is_status_resisted(data: Dictionary, status: String) -> bool:
	if status == "":
		return false
	var equipment: Dictionary = data.get("equipment", {})
	for equip_slot in equipment.keys():
		var item_id := String(equipment.get(equip_slot, ""))
		if item_id == "":
			continue
		var item_def := ContentRegistry.get_definition("items", item_id)
		if String(item_def.get("resistBonus", "")) == status:
			return true
	return false

func _push_recent_reward(data: Dictionary, entry: Dictionary) -> void:
	var meta := _ensure_dictionary(data, "meta")
	var rewards: Array = meta.get("recentRewards", [])
	rewards.push_front(entry.duplicate(true))
	while rewards.size() > 8:
		rewards.pop_back()
	meta["recentRewards"] = rewards

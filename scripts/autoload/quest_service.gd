extends Node

const QUEST_BOARD_OFFER_COUNT := 3

func current_quest(slot: int) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	return data.get("quest", {})

func quest_seed_states(slot: int) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	return data.get("questSeeds", {})

func progression_bosses_defeated(slot: int) -> int:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return 0
	var score := 0
	var flags: Dictionary = data.get("flags", {})
	if bool(flags.get("quest_seed_black_mural_rewarded", false)):
		score += 1
	if bool(flags.get("quest_seed_black_water_vow_rewarded", false)):
		score += 1
	for monster_instance_id in data.get("runtime", {}).get("fieldMonsters", {}).keys():
		var state: Dictionary = data.get("runtime", {}).get("fieldMonsters", {}).get(monster_instance_id, {})
		if not bool(state.get("defeated", false)):
			continue
		var monster_id := String(state.get("monsterId", ""))
		if monster_id == "":
			continue
		var monster_def := ContentRegistry.get_definition("monsters", monster_id)
		if bool(monster_def.get("boss", false)):
			score += 1
	return score

func hook_visible_for_slot(slot: int, hook_row: Dictionary) -> bool:
	var required_bosses := int(hook_row.get("bossesDefeatedAtLeast", 0))
	return progression_bosses_defeated(slot) >= required_bosses

func describe_quest_seed_offer(slot: int, npc_id: String, quest_seed_id: String) -> Dictionary:
	var seed := _find_quest_seed(npc_id, quest_seed_id)
	if seed.is_empty():
		return {
			"id": quest_seed_id,
			"available": false,
			"claimable": false,
			"state": {},
			"reason": "Missing quest seed definition."
		}
	var states: Dictionary = quest_seed_states(slot)
	var state: Dictionary = states.get(quest_seed_id, {})
	var status := String(state.get("status", ""))
	if not hook_visible_for_slot(slot, seed):
		return {
			"id": quest_seed_id,
			"available": false,
			"claimable": false,
			"state": state,
			"reason": "Progression requirement not met."
		}
	if status == "completed":
		return {
			"id": quest_seed_id,
			"available": false,
			"claimable": true,
			"state": state,
			"reason": ""
		}
	if status in ["active", "rewarded"]:
		return {
			"id": quest_seed_id,
			"available": false,
			"claimable": false,
			"state": state,
			"reason": "Quest seed already %s." % status
		}
	var data: Dictionary = SaveService.load_slot(slot)
	var required_flag := String(seed.get("requiredFlag", ""))
	if required_flag != "" and not bool(data.get("flags", {}).get(required_flag, false)):
		return {
			"id": quest_seed_id,
			"available": false,
			"claimable": false,
			"state": state,
			"reason": "Required flag %s is missing." % required_flag
		}
	return {
		"id": quest_seed_id,
		"available": true,
		"claimable": false,
		"state": state,
		"reason": ""
	}

func board_offers(slot: int) -> Array[Dictionary]:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return []
	var board_state: Dictionary = data.get("questBoardState", {})
	var offers: Array = board_state.get("offers", [])
	if offers.is_empty():
		return refresh_board(slot)
	var result: Array[Dictionary] = []
	for offer_variant in offers:
		if typeof(offer_variant) != TYPE_DICTIONARY:
			continue
		result.append((offer_variant as Dictionary).duplicate(true))
	return result

func refresh_board(slot: int) -> Array[Dictionary]:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return []
	var board_state: Dictionary = data.get("questBoardState", {})
	var refresh_count := int(board_state.get("refreshCount", 0))
	var all_quests := ContentRegistry.list_definitions("quests")
	all_quests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	var offers: Array[Dictionary] = []
	if not all_quests.is_empty():
		var start_index := posmod(slot + refresh_count, all_quests.size())
		for offset in range(mini(QUEST_BOARD_OFFER_COUNT, all_quests.size())):
			var quest_def: Dictionary = all_quests[(start_index + offset) % all_quests.size()]
			var monster_def := ContentRegistry.get_definition("monsters", String(quest_def.get("targetMonsterId", "")))
			offers.append({
				"id": String(quest_def.get("id", "")),
				"name": String(quest_def.get("name", "")),
				"note": String(quest_def.get("note", "")),
				"targetMonsterId": String(quest_def.get("targetMonsterId", "")),
				"targetMonsterName": String(monster_def.get("name", quest_def.get("targetMonsterId", ""))),
				"rewardGold": int(quest_def.get("rewardGold", 0))
			})
	board_state["refreshCount"] = refresh_count + 1
	board_state["offers"] = offers
	data["questBoardState"] = board_state
	SaveService.save_slot(slot, data)
	return offers

func quest_board_summary(slot: int) -> Dictionary:
	var quest_state := current_quest(slot)
	return {
		"offers": board_offers(slot),
		"quest": quest_state,
		"hasActiveQuest": String(quest_state.get("status", "")) in ["accepted", "complete_ready"],
		"claimable": String(quest_state.get("status", "")) == "complete_ready"
	}

func accept_quest(slot: int, quest_id: String) -> Dictionary:
	var quest_def := ContentRegistry.get_definition("quests", quest_id)
	if quest_def.is_empty():
		return {"ok": false, "message": "Missing quest definition."}
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var quest_state: Dictionary = data.get("quest", {})
	if String(quest_state.get("status", "")) in ["accepted", "complete_ready"]:
		return {"ok": false, "message": "Quest already accepted."}
	data["quest"] = {
		"id": quest_id,
		"status": "accepted",
		"targetMonsterId": String(quest_def.get("targetMonsterId", "")),
		"rewardGold": int(quest_def.get("rewardGold", 0)),
		"name": String(quest_def.get("name", quest_id))
	}
	var board_state: Dictionary = data.get("questBoardState", {})
	var offers: Array = board_state.get("offers", [])
	for index in range(offers.size()):
		if typeof(offers[index]) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offers[index]
		if String(offer.get("id", "")) == quest_id:
			offers.remove_at(index)
			break
	board_state["offers"] = offers
	data["questBoardState"] = board_state
	SaveService.save_slot(slot, data)
	return {"ok": true, "message": "Accepted quest: %s" % quest_def.get("name", quest_id)}

func on_monster_defeated(slot: int, monster_id: String) -> void:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return
	var quest_state: Dictionary = data.get("quest", {})
	if String(quest_state.get("targetMonsterId", "")) != monster_id:
		return
	if String(quest_state.get("status", "")) == "accepted":
		quest_state["status"] = "complete_ready"
		data["quest"] = quest_state
		SaveService.save_slot(slot, data)

func claim_reward(slot: int) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var quest_state: Dictionary = data.get("quest", {})
	if String(quest_state.get("status", "")) != "complete_ready":
		return {"ok": false, "message": "Quest reward not ready."}
	var reward_gold := int(quest_state.get("rewardGold", 0))
	var resources: Dictionary = data.get("resources", {})
	resources["gold"] = int(resources.get("gold", 0)) + reward_gold
	data["resources"] = resources
	quest_state["status"] = "claimed"
	data["quest"] = quest_state
	SaveService.save_slot(slot, data)
	SaveService.append_recent_reward(slot, {
		"source": "quest",
		"label": String(quest_state.get("name", "quest")),
		"gold": reward_gold,
		"summary": "Quest reward +%d gold" % reward_gold
	})
	return {
		"ok": true,
		"message": "Claimed %d gold from %s." % [reward_gold, quest_state.get("name", "quest")]
	}

func accept_quest_seed(slot: int, npc_id: String, quest_seed_id: String) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var seed := _find_quest_seed(npc_id, quest_seed_id)
	if seed.is_empty():
		return {"ok": false, "message": "Missing quest seed definition."}
	var quest_seeds: Dictionary = data.get("questSeeds", {})
	var existing: Dictionary = quest_seeds.get(quest_seed_id, {})
	var existing_status := String(existing.get("status", ""))
	if existing_status in ["active", "completed", "rewarded"]:
		return {"ok": false, "message": "Quest seed already in progress."}
	var required_flag := String(seed.get("requiredFlag", ""))
	if required_flag != "" and not bool(data.get("flags", {}).get(required_flag, false)):
		return {"ok": false, "message": "Required flag %s is missing." % required_flag}
	var state := {
		"id": quest_seed_id,
		"npcId": npc_id,
		"title": String(seed.get("title", quest_seed_id)),
		"status": "active",
		"grantFlag": String(seed.get("grantFlag", "")),
		"updatedAt": Time.get_datetime_string_from_system()
	}
	quest_seeds[quest_seed_id] = state
	data["questSeeds"] = quest_seeds
	var flags: Dictionary = data.get("flags", {})
	if String(seed.get("grantFlag", "")).strip_edges() != "":
		flags[String(seed.get("grantFlag", ""))] = true
	data["flags"] = flags
	SaveService.save_slot(slot, data)
	return {"ok": true, "message": "Accepted quest seed: %s" % String(seed.get("title", quest_seed_id)), "state": state}

func set_quest_seed_state(slot: int, quest_seed_id: String, status: String) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var quest_seeds: Dictionary = data.get("questSeeds", {})
	var state: Dictionary = quest_seeds.get(quest_seed_id, {"id": quest_seed_id})
	state["status"] = status
	state["updatedAt"] = Time.get_datetime_string_from_system()
	quest_seeds[quest_seed_id] = state
	data["questSeeds"] = quest_seeds
	SaveService.save_slot(slot, data)
	return {"ok": true, "message": "Quest seed %s -> %s." % [quest_seed_id, status], "state": state}

func claim_quest_seed_reward(slot: int, npc_id: String, quest_seed_id: String) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var seed := _find_quest_seed(npc_id, quest_seed_id)
	if seed.is_empty():
		return {"ok": false, "message": "Missing quest seed definition."}
	var quest_seeds: Dictionary = data.get("questSeeds", {})
	var state: Dictionary = quest_seeds.get(quest_seed_id, {})
	if String(state.get("status", "")) != "completed":
		return {"ok": false, "message": "Quest seed reward not ready."}
	var rewards: Dictionary = seed.get("rewards", {})
	var resources: Dictionary = data.get("resources", {})
	resources["gold"] = int(resources.get("gold", 0)) + int(rewards.get("gold", 0))
	data["resources"] = resources
	var inventory_data: Dictionary = data.get("inventory", {})
	for item_row in rewards.get("items", []):
		if typeof(item_row) != TYPE_DICTIONARY:
			continue
		var item_id := String(item_row.get("itemId", ""))
		if item_id == "":
			continue
		inventory_data[item_id] = int(inventory_data.get(item_id, 0)) + maxi(int(item_row.get("quantity", 1)), 1)
	data["inventory"] = inventory_data
	var party_state: Dictionary = data.get("partyState", {})
	party_state["partyXp"] = int(party_state.get("partyXp", 0)) + int(rewards.get("xp", 0))
	data["partyState"] = party_state
	var flags: Dictionary = data.get("flags", {})
	if String(rewards.get("flag", "")).strip_edges() != "":
		flags[String(rewards.get("flag", ""))] = true
	data["flags"] = flags
	state["status"] = "rewarded"
	state["updatedAt"] = Time.get_datetime_string_from_system()
	quest_seeds[quest_seed_id] = state
	data["questSeeds"] = quest_seeds
	SaveService.save_slot(slot, data)
	var item_summaries: Array[String] = []
	for item_row in rewards.get("items", []):
		if typeof(item_row) != TYPE_DICTIONARY:
			continue
		var item_id := String(item_row.get("itemId", ""))
		if item_id == "":
			continue
		item_summaries.append("%s x%d" % [item_id, maxi(int(item_row.get("quantity", 1)), 1)])
	var summary_parts: Array[String] = []
	var reward_gold := int(rewards.get("gold", 0))
	var reward_xp := int(rewards.get("xp", 0))
	if reward_gold > 0:
		summary_parts.append("+%d gold" % reward_gold)
	if reward_xp > 0:
		summary_parts.append("+%d xp" % reward_xp)
	if not item_summaries.is_empty():
		summary_parts.append(", ".join(item_summaries))
	SaveService.append_recent_reward(slot, {
		"source": "quest_seed",
		"label": String(seed.get("title", quest_seed_id)),
		"gold": reward_gold,
		"xp": reward_xp,
		"items": item_summaries,
		"summary": "Quest seed reward %s" % " / ".join(summary_parts)
	})
	return {"ok": true, "message": "Claimed quest seed reward: %s" % String(seed.get("title", quest_seed_id)), "state": state}

func _find_quest_seed(npc_id: String, quest_seed_id: String) -> Dictionary:
	var npc := ContentRegistry.get_definition("npcs", npc_id)
	for seed_variant in npc.get("questSeeds", []):
		if typeof(seed_variant) != TYPE_DICTIONARY:
			continue
		var seed: Dictionary = seed_variant
		if String(seed.get("id", "")) == quest_seed_id:
			return seed
	return {}

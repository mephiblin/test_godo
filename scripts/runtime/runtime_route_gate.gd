extends RefCounted

var scene_ref: Node

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func route_block_message(placement: Dictionary) -> String:
	var current_slot := int(scene_ref.get("current_slot"))
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var required_flag := String(placement.get("requiredFlag", ""))
	if required_flag != "" and not bool(slot_data.get("flags", {}).get(required_flag, false)):
		return String(placement.get("blockedMessage", "The route is still sealed."))
	var required_bosses := int(placement.get("bossesDefeatedAtLeast", 0))
	if required_bosses > 0 and QuestService.progression_bosses_defeated(current_slot) < required_bosses:
		return String(placement.get("blockedMessage", "Requires progression %d." % required_bosses))
	var required_quest_statuses: Array = placement.get("requiredQuestStatuses", [])
	if not required_quest_statuses.is_empty():
		var quest_status := String(QuestService.current_quest(current_slot).get("status", "none"))
		if not required_quest_statuses.has(quest_status):
			return String(placement.get("blockedMessage", "The route is still sealed."))
	var required_seed_id := String(placement.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		var required_seed_status := String(placement.get("requiredQuestSeedStatus", "rewarded"))
		var seed_status := String(QuestService.quest_seed_states(current_slot).get(required_seed_id, {}).get("status", ""))
		if seed_status != required_seed_status:
			return String(placement.get("blockedMessage", "The route is still sealed."))
	return ""

func should_mark_campaign_clear(placement: Dictionary) -> bool:
	if String(placement.get("endingFlag", "")).strip_edges() != "":
		return true
	var map_data: Dictionary = scene_ref.get("map_data")
	if String(map_data.get("id", "")) != "dungeon_floor_03":
		return false
	if String(placement.get("targetRoute", "")) != GameApp.MODE_TOWN:
		return false
	var slot_data: Dictionary = SaveService.load_slot(int(scene_ref.get("current_slot")))
	return bool(slot_data.get("flags", {}).get("blind_priest_cleared", false))

func resolved_campaign_clear_title(placement: Dictionary) -> String:
	var title := String(placement.get("endingTitle", ""))
	if title != "":
		return title
	var map_data: Dictionary = scene_ref.get("map_data")
	if String(map_data.get("id", "")) == "dungeon_floor_03":
		return "Blind Priest Defeated"
	return "Expedition Cleared"

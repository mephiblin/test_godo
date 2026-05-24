extends Node

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3
const SAVE_SCHEMA_VERSION := 2

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_dir()))

func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		var inspection := inspect_slot(slot)
		var data: Dictionary = inspection.get("data", {})
		result.append({
			"slot": slot,
			"exists": bool(inspection.get("exists", false)),
			"blocked": bool(inspection.get("blocked", false)),
			"messages": inspection.get("messages", []),
			"name": data.get("slotName", "Empty Slot %d" % slot),
			"meta": data.get("meta", {}),
			"mode": data.get("mode", "title"),
			"mapId": data.get("runtime", {}).get("mapId", ""),
			"saveVersion": int(data.get("saveVersion", 0)),
			"contentVersion": int(data.get("contentVersion", 0))
		})
	return result

func build_default_session(slot: int, profile: Dictionary = {}) -> Dictionary:
	var player_name := String(profile.get("name", "Conan"))
	var class_id := String(profile.get("classId", "wanderer"))
	var background_id := String(profile.get("backgroundId", "outcast"))
	var start_supply := String(profile.get("startSupply", "camp_kit"))
	var class_def: Dictionary = ContentRegistry.get_definition("classes", class_id)
	var background_def: Dictionary = ContentRegistry.get_definition("backgrounds", background_id)
	var supply_def: Dictionary = ContentRegistry.get_definition("start_supplies", start_supply)
	var base_gold: int = int(class_def.get("baseGold", 50))
	var bonus_gold: int = int(background_def.get("bonusGold", 0)) + int(supply_def.get("bonusGold", 0))
	var opening_gold: int = maxi(base_gold + bonus_gold, 0)
	return {
		"slot": slot,
		"slotName": String(profile.get("slotName", "%s Expedition" % player_name)),
		"saveVersion": SAVE_SCHEMA_VERSION,
		"contentVersion": int(ContentRegistry.get_manifest().get("contentVersion", 0)),
		"party": {
			"members": [
				{
					"name": player_name,
					"classId": class_id,
					"backgroundId": background_id
				}
			]
		},
		"companion": {},
		"player": {
			"name": player_name,
			"classId": class_id,
			"backgroundId": background_id,
			"startSupply": start_supply
		},
		"meta": {
			"playtimeSeconds": 0,
			"lastState": "town",
			"partySummary": "%s / %s" % [player_name, class_def.get("name", class_id)],
			"updatedAt": Time.get_datetime_string_from_system(),
			"campaignCleared": false,
			"endingTitle": "",
			"clearedAt": "",
			"defeatCount": 0,
			"lastDefeat": {},
			"recentRewards": []
		},
		"mode": "town",
		"resources": {
			"gold": opening_gold,
			"food": 3,
			"water": 3,
			"torch": 5
		},
		"inventory": {
			start_supply: 1,
			"healing_tonic": 1
		},
		"equipment": {
			"weapon": "",
			"trinket": ""
		},
		"knownSkills": ["basic_strike"],
		"partyState": {
			"front": {
				"hp": 20,
				"maxHp": 20,
				"statuses": []
			},
			"partyXp": 0
		},
		"shopState": {},
		"npcState": {},
		"questBoardState": {
			"refreshCount": 0,
			"offers": []
		},
		"questSeeds": {},
		"flags": {},
		"quest": {},
		"runtimeMaps": {},
		"floorState": {},
		"visitedMapIds": ["town_square"],
		"runtime": {
			"mapId": "town_square",
			"dungeonSource": GameApp.DUNGEON_SOURCE_COMPILED,
			"playerCell": [2, 5],
			"facing": 0,
			"fieldMonsters": {},
			"discoveredSecrets": {},
			"unlockedDoors": {},
			"claimedLoot": {},
			"visitedCells": {},
			"log": ["New expedition started."]
		}
	}

func create_default_session(slot: int, profile: Dictionary = {}) -> Dictionary:
	var data := build_default_session(slot, profile)
	save_slot(slot, data)
	return data

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [_save_dir(), slot]

func slot_temp_path(slot: int) -> String:
	return "%s.tmp" % slot_path(slot)

func slot_backup_path(slot: int) -> String:
	return "%s.bak" % slot_path(slot)

func load_slot(slot: int) -> Dictionary:
	var inspection := inspect_slot(slot)
	if not bool(inspection.get("exists", false)):
		return {}
	if bool(inspection.get("blocked", false)):
		return {}
	return inspection.get("data", {})

func inspect_slot(slot: int) -> Dictionary:
	var raw_data := _read_slot_file(slot)
	if raw_data.is_empty():
		return {
			"slot": slot,
			"exists": false,
			"blocked": false,
			"messages": [],
			"migrated": false,
			"data": {}
		}
	var result := migrate_slot_data(raw_data, slot)
	var data: Dictionary = result.get("data", {})
	if bool(result.get("ok", false)) and bool(result.get("migrated", false)):
		save_slot(slot, data)
	return {
		"slot": slot,
		"exists": true,
		"blocked": not bool(result.get("ok", false)),
		"messages": result.get("messages", []),
		"migrated": bool(result.get("migrated", false)),
		"data": data
	}

func _read_slot_file(slot: int) -> Dictionary:
	for candidate in [slot_path(slot), slot_temp_path(slot), slot_backup_path(slot)]:
		var parsed := _read_json_dictionary(candidate)
		if not parsed.is_empty():
			return parsed
	return {}

func migrate_slot_data(raw_data: Dictionary, slot: int = 0) -> Dictionary:
	var data: Dictionary = raw_data.duplicate(true)
	var messages: Array[String] = []
	var migrated := false
	var save_version := int(data.get("saveVersion", 0))
	if save_version > SAVE_SCHEMA_VERSION:
		return {
			"ok": false,
			"messages": ["Save schema %d is newer than runtime schema %d." % [save_version, SAVE_SCHEMA_VERSION]],
			"migrated": false,
			"data": data
		}
	var current_content_version := int(ContentRegistry.get_manifest().get("contentVersion", 0))
	var save_content_version := int(data.get("contentVersion", 0))
	if current_content_version > 0 and save_content_version > current_content_version:
		return {
			"ok": false,
			"messages": ["Save content version %d is newer than runtime content version %d." % [save_content_version, current_content_version]],
			"migrated": false,
			"data": data
		}

	if slot > 0 and int(data.get("slot", 0)) != slot:
		data["slot"] = slot
		migrated = true
	if String(data.get("slotName", "")).strip_edges() == "":
		var player_name := String(data.get("player", {}).get("name", "Conan"))
		data["slotName"] = "%s Expedition" % player_name
		migrated = true

	var player := _ensure_dictionary(data, "player")
	var player_name_value := String(player.get("name", "Conan"))
	if String(player.get("name", "")).strip_edges() == "":
		player["name"] = player_name_value
		migrated = true
	if String(player.get("classId", "")).strip_edges() == "":
		player["classId"] = "wanderer"
		migrated = true
	if String(player.get("backgroundId", "")).strip_edges() == "":
		player["backgroundId"] = "outcast"
		migrated = true
	if String(player.get("startSupply", "")).strip_edges() == "":
		player["startSupply"] = "camp_kit"
		migrated = true

	var party := _ensure_dictionary(data, "party")
	if not party.has("members") or typeof(party.get("members")) != TYPE_ARRAY:
		party["members"] = [player.duplicate(true)]
		migrated = true
	if not data.has("companion") or typeof(data.get("companion")) != TYPE_DICTIONARY:
		data["companion"] = {}
		migrated = true
	if not data.has("questBoardState") or typeof(data.get("questBoardState")) != TYPE_DICTIONARY:
		data["questBoardState"] = {
			"refreshCount": 0,
			"offers": []
		}
		migrated = true

	var meta := _ensure_dictionary(data, "meta")
	if not meta.has("playtimeSeconds"):
		meta["playtimeSeconds"] = 0
		migrated = true
	if String(meta.get("lastState", "")).strip_edges() == "":
		meta["lastState"] = String(data.get("mode", "title"))
		migrated = true
	if String(meta.get("partySummary", "")).strip_edges() == "":
		meta["partySummary"] = "%s / %s" % [player_name_value, String(player.get("classId", "wanderer"))]
		migrated = true
	if String(meta.get("updatedAt", "")).strip_edges() == "":
		meta["updatedAt"] = Time.get_datetime_string_from_system()
		migrated = true
	if not meta.has("campaignCleared"):
		meta["campaignCleared"] = false
		migrated = true
	if not meta.has("defeatCount"):
		meta["defeatCount"] = 0
		migrated = true
	if not meta.has("lastDefeat") or typeof(meta.get("lastDefeat")) != TYPE_DICTIONARY:
		meta["lastDefeat"] = {}
		migrated = true
	if String(meta.get("endingTitle", "")).strip_edges() == "":
		meta["endingTitle"] = ""
		migrated = true
	if String(meta.get("clearedAt", "")).strip_edges() == "":
		meta["clearedAt"] = ""
		migrated = true
	if not meta.has("recentRewards") or typeof(meta.get("recentRewards")) != TYPE_ARRAY:
		meta["recentRewards"] = []
		migrated = true

	if String(data.get("mode", "")).strip_edges() == "":
		data["mode"] = String(meta.get("lastState", "town"))
		migrated = true

	var resources := _ensure_dictionary(data, "resources")
	if not resources.has("gold"):
		resources["gold"] = 0
		migrated = true
	for key in ["food", "water", "torch"]:
		if not resources.has(key):
			resources[key] = 0
			migrated = true
	if not data.has("inventory") or typeof(data.get("inventory")) != TYPE_DICTIONARY:
		data["inventory"] = {}
		migrated = true
	if not data.has("equipment") or typeof(data.get("equipment")) != TYPE_DICTIONARY:
		data["equipment"] = {"weapon": "", "trinket": ""}
		migrated = true
	var equipment := _ensure_dictionary(data, "equipment")
	for key in ["weapon", "trinket"]:
		if not equipment.has(key):
			equipment[key] = ""
			migrated = true
	if not data.has("knownSkills") or typeof(data.get("knownSkills")) != TYPE_ARRAY:
		data["knownSkills"] = ["basic_strike"]
		migrated = true
	if not data.has("partyState") or typeof(data.get("partyState")) != TYPE_DICTIONARY:
		data["partyState"] = {"front": {"hp": 20, "maxHp": 20, "statuses": []}, "partyXp": 0}
		migrated = true
	var party_state := _ensure_dictionary(data, "partyState")
	var front := _ensure_dictionary(party_state, "front")
	if not front.has("hp"):
		front["hp"] = 20
		migrated = true
	if not front.has("maxHp"):
		front["maxHp"] = 20
		migrated = true
	if not front.has("statuses") or typeof(front.get("statuses")) != TYPE_ARRAY:
		front["statuses"] = []
		migrated = true
	if not party_state.has("partyXp"):
		party_state["partyXp"] = 0
		migrated = true
	if not data.has("shopState") or typeof(data.get("shopState")) != TYPE_DICTIONARY:
		data["shopState"] = {}
		migrated = true
	if not data.has("npcState") or typeof(data.get("npcState")) != TYPE_DICTIONARY:
		data["npcState"] = {}
		migrated = true
	if not data.has("questSeeds") or typeof(data.get("questSeeds")) != TYPE_DICTIONARY:
		data["questSeeds"] = {}
		migrated = true
	if not data.has("flags") or typeof(data.get("flags")) != TYPE_DICTIONARY:
		data["flags"] = {}
		migrated = true
	if not data.has("quest") or typeof(data.get("quest")) != TYPE_DICTIONARY:
		data["quest"] = {}
		migrated = true
	if not data.has("runtimeMaps") or typeof(data.get("runtimeMaps")) != TYPE_DICTIONARY:
		data["runtimeMaps"] = {}
		migrated = true
	if not data.has("floorState") or typeof(data.get("floorState")) != TYPE_DICTIONARY:
		data["floorState"] = {}
		migrated = true
	if not data.has("visitedMapIds") or typeof(data.get("visitedMapIds")) != TYPE_ARRAY:
		data["visitedMapIds"] = []
		migrated = true

	var runtime := _ensure_dictionary(data, "runtime")
	if String(runtime.get("mapId", "")).strip_edges() == "":
		runtime["mapId"] = "town_square"
		migrated = true
	if String(runtime.get("dungeonSource", "")).strip_edges() == "":
		runtime["dungeonSource"] = GameApp.DUNGEON_SOURCE_COMPILED
		migrated = true
	if not runtime.has("playerCell") or typeof(runtime.get("playerCell")) != TYPE_ARRAY:
		runtime["playerCell"] = [2, 5]
		migrated = true
	if not runtime.has("facing"):
		runtime["facing"] = 0
		migrated = true
	for key in ["fieldMonsters", "discoveredSecrets", "unlockedDoors", "claimedLoot", "visitedCells"]:
		if not runtime.has(key) or typeof(runtime.get(key)) != TYPE_DICTIONARY:
			runtime[key] = {}
			migrated = true
	if not runtime.has("log") or typeof(runtime.get("log")) != TYPE_ARRAY:
		runtime["log"] = []
		migrated = true

	if save_version < SAVE_SCHEMA_VERSION:
		messages.append("Migrated save schema %d -> %d." % [save_version, SAVE_SCHEMA_VERSION])
		data["saveVersion"] = SAVE_SCHEMA_VERSION
		migrated = true
	if save_content_version <= 0 and current_content_version > 0:
		data["contentVersion"] = current_content_version
		messages.append("Assigned runtime content version %d to legacy save." % current_content_version)
		migrated = true
	elif current_content_version > 0 and save_content_version < current_content_version:
		data["contentVersion"] = current_content_version
		messages.append("Advanced save content version %d -> %d." % [save_content_version, current_content_version])
		migrated = true

	return {
		"ok": true,
		"messages": messages,
		"migrated": migrated,
		"data": data
	}

func save_slot(slot: int, data: Dictionary) -> void:
	data["slot"] = slot
	if not data.has("meta"):
		data["meta"] = {}
	data["saveVersion"] = int(data.get("saveVersion", SAVE_SCHEMA_VERSION))
	data["contentVersion"] = int(data.get("contentVersion", ContentRegistry.get_manifest().get("contentVersion", 0)))
	data["meta"]["updatedAt"] = Time.get_datetime_string_from_system()
	_atomic_write_slot(slot, JSON.stringify(data, "\t"))

func delete_slot(slot: int) -> void:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func rename_slot(slot: int, new_name: String) -> void:
	var data := load_slot(slot)
	if data.is_empty():
		return
	data["slotName"] = new_name
	save_slot(slot, data)

func slot_summary(slot: int) -> Dictionary:
	var inspection := inspect_slot(slot)
	var data: Dictionary = inspection.get("data", {})
	if data.is_empty():
		return {}
	return {
		"slotName": data.get("slotName", ""),
		"playerName": data.get("player", {}).get("name", ""),
		"classId": data.get("player", {}).get("classId", ""),
		"backgroundId": data.get("player", {}).get("backgroundId", ""),
		"startSupply": data.get("player", {}).get("startSupply", ""),
		"gold": int(data.get("resources", {}).get("gold", 0)),
		"inventory": data.get("inventory", {}),
		"mode": data.get("mode", "title"),
		"dungeonSource": data.get("runtime", {}).get("dungeonSource", GameApp.DUNGEON_SOURCE_COMPILED),
		"saveVersion": int(data.get("saveVersion", 0)),
		"contentVersion": int(data.get("contentVersion", 0)),
		"blocked": bool(inspection.get("blocked", false)),
		"messages": inspection.get("messages", []),
		"lastState": data.get("meta", {}).get("lastState", "title"),
		"playtimeSeconds": float(data.get("meta", {}).get("playtimeSeconds", 0.0)),
		"campaignCleared": bool(data.get("meta", {}).get("campaignCleared", false)),
		"endingTitle": String(data.get("meta", {}).get("endingTitle", "")),
		"clearedAt": String(data.get("meta", {}).get("clearedAt", "")),
		"defeatCount": int(data.get("meta", {}).get("defeatCount", 0)),
		"lastDefeat": data.get("meta", {}).get("lastDefeat", {})
	}

func mark_campaign_clear(slot: int, ending_title: String = "", clear_map_id: String = "") -> void:
	var data := load_slot(slot)
	if data.is_empty():
		return
	var meta := _ensure_dictionary(data, "meta")
	meta["campaignCleared"] = true
	if ending_title.strip_edges() != "":
		meta["endingTitle"] = ending_title
	if String(meta.get("clearedAt", "")).strip_edges() == "":
		meta["clearedAt"] = Time.get_datetime_string_from_system()
	if clear_map_id.strip_edges() != "":
		meta["clearMapId"] = clear_map_id
	data["meta"] = meta
	var flags := _ensure_dictionary(data, "flags")
	flags["campaignCleared"] = true
	data["flags"] = flags
	save_slot(slot, data)

func record_defeat(slot: int, summary: Dictionary, return_to_title: bool = false) -> Dictionary:
	var data := load_slot(slot)
	if data.is_empty():
		return {}
	var resources := _ensure_dictionary(data, "resources")
	var gold_before := int(resources.get("gold", 0))
	var gold_penalty := mini(gold_before, maxi(int(round(gold_before * 0.2)), 10))
	if gold_before <= 0:
		gold_penalty = 0
	resources["gold"] = maxi(gold_before - gold_penalty, 0)
	data["resources"] = resources
	var party_state := _ensure_dictionary(data, "partyState")
	var front := _ensure_dictionary(party_state, "front")
	front["hp"] = 1
	front["maxHp"] = maxi(int(front.get("maxHp", 20)), 1)
	party_state["front"] = front
	data["partyState"] = party_state
	var meta := _ensure_dictionary(data, "meta")
	meta["defeatCount"] = int(meta.get("defeatCount", 0)) + 1
	meta["lastDefeat"] = {
		"enemyName": String(summary.get("enemyName", "Unknown Enemy")),
		"mapId": String(summary.get("mapId", "")),
		"goldPenalty": gold_penalty,
		"returnedTo": "title" if return_to_title else "town",
		"recordedAt": Time.get_datetime_string_from_system()
	}
	meta["lastState"] = "title" if return_to_title else "town"
	data["meta"] = meta
	var runtime := _ensure_dictionary(data, "runtime")
	runtime["mapId"] = "town_square"
	runtime["playerCell"] = [2, 5]
	runtime["facing"] = 0
	var log: Array = runtime.get("log", [])
	log.append("Recovered after defeat by %s." % String(summary.get("enemyName", "Unknown Enemy")))
	runtime["log"] = log
	data["runtime"] = runtime
	data["mode"] = "title" if return_to_title else "town"
	save_slot(slot, data)
	return meta["lastDefeat"]

func inventory(slot: int) -> Dictionary:
	var data := load_slot(slot)
	return data.get("inventory", {})

func equipment(slot: int) -> Dictionary:
	var data := load_slot(slot)
	return data.get("equipment", {})

func known_skills(slot: int) -> Array[String]:
	var data := load_slot(slot)
	var result: Array[String] = []
	for skill_id_variant in data.get("knownSkills", []):
		var skill_id := String(skill_id_variant)
		if skill_id != "":
			result.append(skill_id)
	if result.is_empty():
		result.append("basic_strike")
	return result

func front_state(slot: int) -> Dictionary:
	var data := load_slot(slot)
	return data.get("partyState", {}).get("front", {})

func update_front_state(slot: int, hp: int, max_hp: int = -1, statuses: Array = []) -> void:
	var data := load_slot(slot)
	if data.is_empty():
		return
	var party_state := _ensure_dictionary(data, "partyState")
	var front := _ensure_dictionary(party_state, "front")
	var resolved_max_hp := maxi(int(front.get("maxHp", 20)), 1)
	if max_hp > 0:
		resolved_max_hp = maxi(max_hp, 1)
	front["maxHp"] = resolved_max_hp
	front["hp"] = clampi(hp, 0, resolved_max_hp)
	if not statuses.is_empty():
		front["statuses"] = statuses.duplicate()
	party_state["front"] = front
	data["partyState"] = party_state
	save_slot(slot, data)

func add_inventory_item(slot: int, item_id: String, count: int = 1) -> void:
	var data := load_slot(slot)
	if data.is_empty():
		return
	var inventory_data: Dictionary = data.get("inventory", {})
	inventory_data[item_id] = int(inventory_data.get(item_id, 0)) + count
	data["inventory"] = inventory_data
	save_slot(slot, data)

func recent_rewards(slot: int) -> Array[Dictionary]:
	var data := load_slot(slot)
	var result: Array[Dictionary] = []
	for row in data.get("meta", {}).get("recentRewards", []):
		if typeof(row) == TYPE_DICTIONARY:
			result.append((row as Dictionary).duplicate(true))
	return result

func append_recent_reward(slot: int, entry: Dictionary) -> void:
	var data := load_slot(slot)
	if data.is_empty():
		return
	var meta := _ensure_dictionary(data, "meta")
	var rewards: Array = meta.get("recentRewards", [])
	var normalized := entry.duplicate(true)
	normalized["recordedAt"] = Time.get_datetime_string_from_system()
	rewards.push_front(normalized)
	while rewards.size() > 8:
		rewards.pop_back()
	meta["recentRewards"] = rewards
	data["meta"] = meta
	save_slot(slot, data)

func has_inventory_item(slot: int, item_id: String, count: int = 1) -> bool:
	return int(inventory(slot).get(item_id, 0)) >= count

func consume_inventory_item(slot: int, item_id: String, count: int = 1) -> bool:
	var data := load_slot(slot)
	if data.is_empty():
		return false
	var inventory_data: Dictionary = data.get("inventory", {})
	var current := int(inventory_data.get(item_id, 0))
	if current < count:
		return false
	inventory_data[item_id] = current - count
	if int(inventory_data[item_id]) <= 0:
		inventory_data.erase(item_id)
	data["inventory"] = inventory_data
	save_slot(slot, data)
	return true

func is_item_identified(slot: int, item_id: String) -> bool:
	var data := load_slot(slot)
	return bool(data.get("npcState", {}).get("identifiedItems", {}).get(item_id, false))

func equip_item(slot: int, item_id: String) -> Dictionary:
	var data := load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	if not has_inventory_item(slot, item_id, 1):
		return {"ok": false, "message": "Item is not in inventory."}
	if not is_item_identified(slot, item_id):
		return {"ok": false, "message": "Item must be identified before equipping."}
	var item_def := ContentRegistry.get_definition("items", item_id)
	var equip_slot := String(item_def.get("equipSlot", ""))
	if equip_slot == "":
		return {"ok": false, "message": "Item cannot be equipped."}
	var equipment_data: Dictionary = data.get("equipment", {})
	var previous_item_id := String(equipment_data.get(equip_slot, ""))
	if previous_item_id == item_id:
		return {"ok": false, "message": "Item is already equipped."}
	var previous_def := ContentRegistry.get_definition("items", previous_item_id)
	if previous_item_id != "" and String(previous_def.get("curseStatus", "")) != "":
		return {"ok": false, "message": "%s is cursed and cannot be removed." % String(previous_def.get("name", previous_item_id))}
	equipment_data[equip_slot] = item_id
	data["equipment"] = equipment_data
	var curse_status := String(item_def.get("curseStatus", ""))
	if curse_status != "":
		var party_state: Dictionary = data.get("partyState", {})
		var front: Dictionary = party_state.get("front", {})
		var statuses: Array = front.get("statuses", [])
		if not statuses.has(curse_status):
			statuses.append(curse_status)
		front["statuses"] = statuses
		party_state["front"] = front
		data["partyState"] = party_state
	save_slot(slot, data)
	return {"ok": true, "message": "Equipped %s." % String(item_def.get("name", item_id)), "slot": equip_slot}

func unequip_item(slot: int, equip_slot: String) -> Dictionary:
	var data := load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var equipment_data: Dictionary = data.get("equipment", {})
	var item_id := String(equipment_data.get(equip_slot, ""))
	if item_id == "":
		return {"ok": false, "message": "Nothing is equipped in %s." % equip_slot}
	var item_def := ContentRegistry.get_definition("items", item_id)
	var curse_status := String(item_def.get("curseStatus", ""))
	if curse_status != "":
		return {"ok": false, "message": "%s is cursed and cannot be removed." % String(item_def.get("name", item_id))}
	equipment_data[equip_slot] = ""
	data["equipment"] = equipment_data
	save_slot(slot, data)
	return {"ok": true, "message": "Unequipped %s." % String(item_def.get("name", item_id)), "slot": equip_slot}

func update_runtime(slot: int, runtime_data: Dictionary, mode: String) -> void:
	var data := load_slot(slot)
	if data.is_empty():
		return
	data["runtime"] = runtime_data
	data["mode"] = mode
	data["meta"]["lastState"] = mode
	save_slot(slot, data)

func mark_monster_state(slot: int, monster_id: String, defeated: bool) -> void:
	var data := load_slot(slot)
	if data.is_empty():
		return
	var runtime: Dictionary = data.get("runtime", {})
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	var existing: Dictionary = field_monsters.get(monster_id, {})
	existing["defeated"] = defeated
	existing["updatedAt"] = Time.get_datetime_string_from_system()
	if String(existing.get("monsterId", "")).strip_edges() == "":
		existing["monsterId"] = monster_id
	field_monsters[monster_id] = existing
	runtime["fieldMonsters"] = field_monsters
	data["runtime"] = runtime
	save_slot(slot, data)

func _ensure_dictionary(parent: Dictionary, key: String) -> Dictionary:
	if not parent.has(key) or typeof(parent.get(key)) != TYPE_DICTIONARY:
		parent[key] = {}
	return parent[key]

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	if text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _save_dir() -> String:
	var save_namespace := _save_namespace()
	if save_namespace == "":
		return SAVE_DIR
	return "%s/%s" % [SAVE_DIR, save_namespace]

func _save_namespace() -> String:
	var cmd_args := OS.get_cmdline_user_args()
	var smoke_enabled := OS.get_environment("CONAN_DOT_SMOKE") == "1" or "--smoke" in cmd_args
	var explicit_namespace := String(OS.get_environment("CONAN_DOT_SAVE_NAMESPACE"))
	if explicit_namespace.strip_edges() != "":
		return _sanitize_namespace(explicit_namespace)
	if OS.get_environment("CONAN_DOT_DOMAIN_SMOKE") == "1":
		return "smoke_domain"
	if OS.get_environment("CONAN_DOT_SAVE_MIGRATION_SMOKE") == "1":
		return "smoke_save_migration"
	if OS.get_environment("CONAN_DOT_CONTENT_IMPORT_SMOKE") == "1":
		return "smoke_content_import"
	if OS.get_environment("CONAN_DOT_BENCHMARK_SMOKE") == "1":
		return "smoke_benchmark"
	if smoke_enabled:
		var output_dir := String(OS.get_environment("CONAN_DOT_OUTPUT_DIR"))
		if output_dir.strip_edges() != "":
			return "smoke_%s" % _sanitize_namespace(output_dir.get_file())
		return "smoke_visual"
	return ""

func _sanitize_namespace(value: String) -> String:
	var result := ""
	for char_code in value.to_ascii_buffer():
		var c := char(char_code)
		var lower_code := char_code + 32 if char_code >= 65 and char_code <= 90 else char_code
		if (lower_code >= 97 and lower_code <= 122) or (char_code >= 48 and char_code <= 57):
			result += char(lower_code)
		elif c in [".", "-", "_"]:
			result += "_"
	return result.strip_edges().trim_suffix("_").trim_prefix("_")

func _atomic_write_slot(slot: int, text: String) -> void:
	var final_path := slot_path(slot)
	var temp_path := slot_temp_path(slot)
	var backup_path := slot_backup_path(slot)
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		push_warning("Failed to open temp save path: %s" % temp_path)
		return
	temp_file.store_string(text)
	temp_file.flush()
	temp_file = null
	var final_abs := ProjectSettings.globalize_path(final_path)
	var temp_abs := ProjectSettings.globalize_path(temp_path)
	var backup_abs := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(final_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_abs)
		DirAccess.rename_absolute(final_abs, backup_abs)
	var rename_err := DirAccess.rename_absolute(temp_abs, final_abs)
	if rename_err != OK:
		push_warning("Failed to promote temp save %s -> %s (%s)." % [temp_path, final_path, error_string(rename_err)])
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(final_path):
			DirAccess.rename_absolute(backup_abs, final_abs)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_abs)
		return
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_abs)

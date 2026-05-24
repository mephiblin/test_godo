extends RefCounted

var scene_ref: Node

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func visited_keys_for_map(runtime: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var visited_cells: Dictionary = runtime.get("visitedCells", {})
	var map_data: Dictionary = scene_ref.get("map_data")
	var default_map_id := String(scene_ref.get("default_map_id"))
	var prefix := "%s:" % String(map_data.get("id", default_map_id))
	for key in visited_cells.keys():
		var cell_key := String(key)
		if cell_key.begins_with(prefix) and bool(visited_cells.get(key, false)):
			result.append(cell_key.substr(prefix.length()))
	return result

func visible_minimap_placements(runtime: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var map_data: Dictionary = scene_ref.get("map_data")
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
	var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
	var claimed_loot: Dictionary = runtime.get("claimedLoot", {})
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var placement_id := String(placement.get("id", ""))
		var placement_type := String(placement.get("type", ""))
		if placement_type == "field_monster":
			var field_state: Dictionary = field_monsters.get(placement_id, {})
			if bool(field_state.get("defeated", false)):
				continue
			if String(scene_ref.call("_field_ai_behavior", placement)) == "ambush" and not bool(field_state.get("revealed", false)):
				continue
		if placement_type == "secret_door" and not bool(discovered_secrets.get(placement_id, false)):
			continue
		if placement_type == "locked_door" and bool(unlocked_doors.get(placement_id, false)):
			continue
		if placement_type == "loot" and bool(claimed_loot.get(placement_id, false)):
			continue
		var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement, runtime)
		var row := {
			"id": placement_id,
			"type": placement_type,
			"position": [cell.x, cell.y]
		}
		if placement_type in ["gate", "stairs"]:
			var blocked_message := String(scene_ref.call("_route_block_message", placement))
			row["routeBlocked"] = blocked_message != ""
			row["blockedMessage"] = blocked_message
			row["targetMapId"] = String(placement.get("targetMapId", ""))
			row["targetRoute"] = String(placement.get("targetRoute", ""))
		result.append(row)
	return result

func route_state_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var map_data: Dictionary = scene_ref.get("map_data")
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var placement_type := String(placement.get("type", ""))
		if placement_type not in ["gate", "stairs"]:
			continue
		var pos: Array = placement.get("position", [0, 0])
		var blocked_message := String(scene_ref.call("_route_block_message", placement))
		result.append({
			"id": String(placement.get("id", "")),
			"type": placement_type,
			"label": String(placement.get("label", placement.get("id", ""))),
			"position": [int(pos[0]), int(pos[1])],
			"targetMapId": String(placement.get("targetMapId", "")),
			"targetRoute": String(placement.get("targetRoute", "")),
			"blocked": blocked_message != "",
			"blockedMessage": blocked_message
		})
	return result

func field_monster_snapshot(runtime: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var map_data: Dictionary = scene_ref.get("map_data")
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		var state: Dictionary = runtime.get("fieldMonsters", {}).get(placement_id, {})
		var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement, runtime)
		result.append({
			"id": placement_id,
			"monsterId": String(state.get("monsterId", placement.get("monsterId", placement_id))),
			"aiState": String(state.get("aiState", "idle")),
			"currentCell": [cell.x, cell.y],
			"startCell": state.get("startCell", placement.get("position", [0, 0])),
			"fieldAi": scene_ref.call("_field_ai_config", placement),
			"lastKnownPlayerCell": state.get("lastKnownPlayerCell", placement.get("position", [0, 0])),
			"revealed": bool(state.get("revealed", String(scene_ref.call("_field_ai_behavior", placement)) != "ambush")),
			"defeated": bool(state.get("defeated", false))
		})
	return result

func field_monster_state_summary(runtime: Dictionary) -> String:
	var rows: Array[String] = []
	for row in field_monster_snapshot(runtime):
		if bool(row.get("defeated", false)):
			continue
		var cell: Array = row.get("currentCell", [0, 0])
		rows.append("%s:%s@%d,%d" % [
			String(row.get("monsterId", row.get("id", ""))),
			String(row.get("aiState", "idle")),
			int(cell[0]),
			int(cell[1])
		])
	if rows.is_empty():
		return "-"
	return ", ".join(rows)

func route_summary() -> String:
	var route_entries := route_state_entries()
	if route_entries.is_empty():
		return "-"
	var labels: Array[String] = []
	for entry in route_entries:
		labels.append("%s:%s" % [
			String(entry.get("label", entry.get("id", ""))),
			"locked" if bool(entry.get("blocked", false)) else "open"
		])
	return ", ".join(labels)

func quest_target_keys() -> Array[String]:
	var result: Array[String] = []
	var current_slot := int(scene_ref.get("current_slot"))
	var map_data: Dictionary = scene_ref.get("map_data")
	var quest_state := QuestService.current_quest(current_slot)
	var quest_status := String(quest_state.get("status", ""))
	if quest_status not in ["accepted", "complete_ready"]:
		return result
	var target_monster_id := String(quest_state.get("targetMonsterId", ""))
	if target_monster_id == "":
		return result
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_monster_id := String(placement.get("monsterId", placement.get("id", "")))
		if placement_monster_id != target_monster_id and String(placement.get("id", "")) != target_monster_id:
			continue
		var pos: Array = placement.get("position", [0, 0])
		result.append("%d,%d" % [int(pos[0]), int(pos[1])])
	return result

func quest_turn_in_keys() -> Array[String]:
	var result: Array[String] = []
	var current_slot := int(scene_ref.get("current_slot"))
	var map_data: Dictionary = scene_ref.get("map_data")
	var quest_state := QuestService.current_quest(current_slot)
	if String(quest_state.get("status", "")) != "complete_ready":
		return result
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var placement_type := String(placement.get("type", ""))
		if placement_type not in ["quest_board", "npc_service"]:
			continue
		var pos: Array = placement.get("position", [0, 0])
		result.append("%d,%d" % [int(pos[0]), int(pos[1])])
	return result

func quest_seed_objective_keys() -> Array[String]:
	var result: Array[String] = []
	var current_slot := int(scene_ref.get("current_slot"))
	var quest_seeds := QuestService.quest_seed_states(current_slot)
	for quest_seed_id in quest_seeds.keys():
		var state: Dictionary = quest_seeds.get(quest_seed_id, {})
		var status := String(state.get("status", ""))
		if status not in ["active", "completed"]:
			continue
		var npc_id := String(state.get("npcId", ""))
		var seed_def := find_quest_seed_definition(npc_id, String(quest_seed_id))
		if seed_def.is_empty():
			continue
		if status == "active":
			result.append_array(placement_keys_for_event(String(seed_def.get("completeEventId", ""))))
		else:
			result.append_array(placement_keys_for_npc(npc_id))
	return result

func find_quest_seed_definition(npc_id: String, quest_seed_id: String) -> Dictionary:
	if npc_id == "" or quest_seed_id == "":
		return {}
	var npc_def := ContentRegistry.get_definition("npcs", npc_id)
	for seed_variant in npc_def.get("questSeeds", []):
		if typeof(seed_variant) != TYPE_DICTIONARY:
			continue
		var seed: Dictionary = seed_variant
		if String(seed.get("id", "")) == quest_seed_id:
			return seed
	return {}

func placement_keys_for_event(event_id: String) -> Array[String]:
	var result: Array[String] = []
	if event_id == "":
		return result
	var map_data: Dictionary = scene_ref.get("map_data")
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		if String(placement.get("eventId", "")) != event_id:
			continue
		var pos: Array = placement.get("position", [0, 0])
		result.append("%d,%d" % [int(pos[0]), int(pos[1])])
	return result

func placement_keys_for_npc(npc_id: String) -> Array[String]:
	var result: Array[String] = []
	if npc_id == "":
		return result
	var map_data: Dictionary = scene_ref.get("map_data")
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		if String(placement.get("npcId", "")) != npc_id:
			continue
		var pos: Array = placement.get("position", [0, 0])
		result.append("%d,%d" % [int(pos[0]), int(pos[1])])
	return result

extends RefCounted

func move_forward(scene: Node) -> void:
	if _is_ready(scene):
		scene.call("_try_forward_move")

func cycle_town_focus(scene: Node, step: int) -> void:
	if _is_ready(scene):
		scene.call("_cycle_town_focus", step)

func accept_quest(scene: Node) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("type", "")) == "quest_board":
			QuestService.accept_quest(_slot(scene), String(placement.get("questId", "")))
			scene.call("_log", "Smoke accepted quest.")
			return

func accept_quest_seed(scene: Node) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("npcId", "")) != "npc_scholar":
			continue
		var result := QuestService.accept_quest_seed(_slot(scene), "npc_scholar", "quest_seed_black_mural")
		if bool(result.get("ok", false)):
			scene.call("_log", "Smoke accepted quest seed.")
		return

func route_dungeon(scene: Node) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("type", "")) == "gate":
			scene.call("_route_from_placement", placement)
			return

func route_to_map(scene: Node, target_map_id: String) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("targetMapId", "")) != target_map_id:
			continue
		if String(placement.get("type", "")) in ["gate", "stairs"]:
			scene.call("_route_from_placement", placement)
			return

func route_probe(scene: Node, target_map_id: String) -> Dictionary:
	if not _is_ready(scene):
		return {"ok": false, "blockedMessage": "Scene is not ready.", "targetMapId": target_map_id}
	for placement in _placements(scene):
		if String(placement.get("targetMapId", "")) != target_map_id:
			continue
		if String(placement.get("type", "")) not in ["gate", "stairs"]:
			continue
		var blocked_message := String(scene.call("_route_block_message", placement))
		if blocked_message != "":
			return {
				"ok": false,
				"blockedMessage": blocked_message,
				"targetMapId": target_map_id
			}
		return {
			"ok": true,
			"blockedMessage": "",
			"targetMapId": target_map_id
		}
	return {"ok": false, "blockedMessage": "Missing route placement.", "targetMapId": target_map_id}

func field_monster_ai_probe(scene: Node, monster_id: String) -> Dictionary:
	if not _is_ready(scene):
		return {"ok": false}
	var slot := _slot(scene)
	var slot_before: Dictionary = SaveService.load_slot(slot).duplicate(true)
	var matches: Array[Dictionary] = []
	for placement in _placements(scene):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("monsterId", placement.get("id", ""))) != monster_id:
			continue
		matches.append(placement)
	var target_placement: Dictionary = {}
	for placement in matches:
		if _field_ai_behavior(scene, placement) == "ambush":
			target_placement = placement
			break
	if target_placement.is_empty() and not matches.is_empty():
		target_placement = matches[0]
	if target_placement.is_empty():
		return {"ok": false}
	var before_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var placement_id := String(target_placement.get("id", ""))
	var before_state: Dictionary = before_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	var ai_config := _field_ai_config(scene, target_placement)
	var before_cell: Vector2i = scene.get("player_cell")
	scene.call("_tick_field_monsters")
	var after_patrol_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var after_patrol: Dictionary = after_patrol_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	var target_cell := _placement_runtime_cell(scene, target_placement, before_runtime)
	scene.set("player_cell", target_cell + Vector2i(0, 2))
	scene.call("_tick_field_monsters")
	var after_approach_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var after_approach: Dictionary = after_approach_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	scene.set("player_cell", target_cell + Vector2i(0, 6))
	scene.call("_tick_field_monsters")
	var after_give_up_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var after_give_up: Dictionary = after_give_up_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	for _i in range(4):
		scene.call("_tick_field_monsters")
	var after_return_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var after_return: Dictionary = after_return_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	scene.set("player_cell", before_cell)
	SaveService.save_slot(slot, slot_before)
	scene.call("_persist_runtime")
	return {
		"ok": true,
		"fieldAi": ai_config,
		"before": before_state,
		"afterPatrol": after_patrol,
		"afterApproach": after_approach,
		"afterGiveUp": after_give_up,
		"afterReturn": after_return
	}

func field_monster_group_alert_probe(scene: Node, monster_id: String) -> Dictionary:
	if not _is_ready(scene):
		return {"ok": false}
	var slot := _slot(scene)
	var slot_before: Dictionary = SaveService.load_slot(slot).duplicate(true)
	var source_matches: Array[Dictionary] = []
	for placement in _placements(scene):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("monsterId", placement.get("id", ""))) != monster_id:
			continue
		source_matches.append(placement)
	var source_placement: Dictionary = {}
	for placement in source_matches:
		if _field_ai_behavior(scene, placement) == "ambush":
			source_placement = placement
			break
	if source_placement.is_empty() and not source_matches.is_empty():
		source_placement = source_matches[0]
	if source_placement.is_empty():
		return {"ok": false, "reason": "no_source"}
	var group_id := _field_alert_group_id(scene, source_placement)
	if group_id == "":
		return {"ok": false, "reason": "no_group"}
	var ally_placement: Dictionary = {}
	for placement in _placements(scene):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("id", "")) == String(source_placement.get("id", "")):
			continue
		if _field_alert_group_id(scene, placement) == group_id:
			ally_placement = placement
			break
	if ally_placement.is_empty():
		return {"ok": false, "reason": "no_ally"}
	var before_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var source_id := String(source_placement.get("id", ""))
	var ally_id := String(ally_placement.get("id", ""))
	var source_before: Dictionary = before_runtime.get("fieldMonsters", {}).get(source_id, {}).duplicate(true)
	var ally_before: Dictionary = before_runtime.get("fieldMonsters", {}).get(ally_id, {}).duplicate(true)
	var before_cell: Vector2i = scene.get("player_cell")
	var source_cell := _placement_runtime_cell(scene, source_placement, before_runtime)
	scene.set("player_cell", _probe_cell_near(scene, source_cell, 2))
	scene.call("_tick_field_monsters")
	var after_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var source_after: Dictionary = after_runtime.get("fieldMonsters", {}).get(source_id, {}).duplicate(true)
	var ally_after: Dictionary = after_runtime.get("fieldMonsters", {}).get(ally_id, {}).duplicate(true)
	scene.set("player_cell", before_cell)
	SaveService.save_slot(slot, slot_before)
	scene.call("_persist_runtime")
	return {
		"ok": true,
		"groupId": group_id,
		"sourceId": source_id,
		"allyId": ally_id,
		"sourceEncounterId": String(source_placement.get("encounterId", "")),
		"allyEncounterId": String(ally_placement.get("encounterId", "")),
		"sourceAlertGroup": String(_field_ai_config(scene, source_placement).get("alertGroup", "")),
		"allyAlertGroup": String(_field_ai_config(scene, ally_placement).get("alertGroup", "")),
		"sourceBefore": source_before,
		"sourceAfter": source_after,
		"allyBefore": ally_before,
		"allyAfter": ally_after
	}

func field_monster_los_probe(scene: Node, monster_id: String) -> Dictionary:
	if not _is_ready(scene):
		return {"ok": false}
	var slot := _slot(scene)
	var slot_before: Dictionary = SaveService.load_slot(slot).duplicate(true)
	var target_placement: Dictionary = {}
	for placement in _placements(scene):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("monsterId", placement.get("id", ""))) != monster_id:
			continue
		target_placement = placement
		break
	if target_placement.is_empty():
		return {"ok": false}
	var before_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var placement_id := String(target_placement.get("id", ""))
	var target_cell := _placement_runtime_cell(scene, target_placement, before_runtime)
	var before_cell: Vector2i = scene.get("player_cell")
	scene.set("player_cell", target_cell + Vector2i(0, 4))
	scene.call("_tick_field_monsters")
	var blocked_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var blocked_state: Dictionary = blocked_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	scene.set("player_cell", target_cell + Vector2i(0, 1))
	scene.call("_tick_field_monsters")
	var heard_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var heard_state: Dictionary = heard_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	scene.set("player_cell", target_cell + Vector2i(0, 2))
	scene.call("_tick_field_monsters")
	var visible_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var visible_state: Dictionary = visible_runtime.get("fieldMonsters", {}).get(placement_id, {}).duplicate(true)
	scene.set("player_cell", before_cell)
	SaveService.save_slot(slot, slot_before)
	scene.call("_persist_runtime")
	return {
		"ok": true,
		"fieldAi": _field_ai_config(scene, target_placement),
		"blockedCell": [target_cell.x, target_cell.y + 4],
		"heardCell": [target_cell.x, target_cell.y + 1],
		"visibleCell": [target_cell.x, target_cell.y + 2],
		"blockedState": blocked_state,
		"heardState": heard_state,
		"visibleState": visible_state
	}

func field_monster_door_los_probe(scene: Node, monster_id: String, door_id: String) -> Dictionary:
	if not _is_ready(scene):
		return {"ok": false}
	var slot := _slot(scene)
	var slot_before: Dictionary = SaveService.load_slot(slot).duplicate(true)
	var target_placement: Dictionary = {}
	var door_placement: Dictionary = {}
	for placement in _placements(scene):
		var placement_id := String(placement.get("id", ""))
		if placement_id == door_id:
			door_placement = placement
		if String(placement.get("type", "")) == "field_monster" and String(placement.get("monsterId", placement.get("id", ""))) == monster_id:
			target_placement = placement
	if target_placement.is_empty() or door_placement.is_empty():
		return {"ok": false}
	var target_cell := _placement_runtime_cell(scene, target_placement)
	var before_cell: Vector2i = scene.get("player_cell")
	var locked_slot := SaveService.load_slot(slot)
	var locked_runtime: Dictionary = locked_slot.get("runtime", {})
	var reset_state := {
		"startCell": [target_cell.x, target_cell.y],
		"currentCell": [target_cell.x, target_cell.y],
		"monsterId": String(target_placement.get("monsterId", target_placement.get("id", ""))),
		"patrolIndex": 0,
		"warningCounter": 0,
		"lostSightCounter": 0,
		"lastKnownPlayerCell": [target_cell.x, target_cell.y],
		"revealed": _field_ai_behavior(scene, target_placement) != "ambush",
		"aiState": "patrolling" if _field_ai_behavior(scene, target_placement) == "patrol" else ("ambushing" if _field_ai_behavior(scene, target_placement) == "ambush" else "idle")
	}
	var locked_field_monsters: Dictionary = locked_runtime.get("fieldMonsters", {})
	locked_field_monsters[String(target_placement.get("id", ""))] = reset_state
	locked_runtime["fieldMonsters"] = locked_field_monsters
	var locked_unlocked_doors: Dictionary = locked_runtime.get("unlockedDoors", {})
	locked_unlocked_doors[door_id] = false
	locked_runtime["unlockedDoors"] = locked_unlocked_doors
	locked_slot["runtime"] = locked_runtime
	SaveService.save_slot(slot, locked_slot)
	scene.set("player_cell", target_cell + Vector2i(-2, 0))
	scene.call("_tick_field_monsters")
	var locked_runtime_after: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var locked_state: Dictionary = locked_runtime_after.get("fieldMonsters", {}).get(String(target_placement.get("id", "")), {}).duplicate(true)
	var unlocked_slot := SaveService.load_slot(slot)
	var unlocked_runtime: Dictionary = unlocked_slot.get("runtime", {})
	var unlocked_doors: Dictionary = unlocked_runtime.get("unlockedDoors", {})
	unlocked_doors[door_id] = true
	unlocked_runtime["unlockedDoors"] = unlocked_doors
	unlocked_slot["runtime"] = unlocked_runtime
	SaveService.save_slot(slot, unlocked_slot)
	scene.call("_tick_field_monsters")
	var unlocked_runtime_after: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var unlocked_state: Dictionary = unlocked_runtime_after.get("fieldMonsters", {}).get(String(target_placement.get("id", "")), {}).duplicate(true)
	scene.set("player_cell", before_cell)
	SaveService.save_slot(slot, slot_before)
	scene.call("_persist_runtime")
	return {
		"ok": true,
		"doorId": door_id,
		"blockedCell": [target_cell.x - 2, target_cell.y],
		"lockedState": locked_state,
		"unlockedState": unlocked_state
	}

func secret_door_blocking_probe(scene: Node, secret_id: String) -> Dictionary:
	if not _is_ready(scene):
		return {"ok": false}
	var slot := _slot(scene)
	var slot_before: Dictionary = SaveService.load_slot(slot).duplicate(true)
	var secret_placement: Dictionary = {}
	for placement in _placements(scene):
		if String(placement.get("id", "")) == secret_id:
			secret_placement = placement
			break
	if secret_placement.is_empty():
		return {"ok": false}
	var secret_cell := _placement_runtime_cell(scene, secret_placement)
	var before_cell: Vector2i = scene.get("player_cell")
	var before_facing := int(scene.get("facing"))
	scene.set("player_cell", secret_cell + Vector2i(0, 1))
	scene.set("facing", 3)
	var blocked_before := bool(scene.call("_is_blocked", secret_cell))
	scene.call("_discover_secret", secret_placement)
	var blocked_after := bool(scene.call("_is_blocked", secret_cell))
	scene.set("player_cell", before_cell)
	scene.set("facing", before_facing)
	SaveService.save_slot(slot, slot_before)
	scene.call("_persist_runtime")
	return {
		"ok": true,
		"secretId": secret_id,
		"cell": [secret_cell.x, secret_cell.y],
		"blockedBefore": blocked_before,
		"blockedAfter": blocked_after
	}

func secret_door_patrol_probe(scene: Node, monster_id: String, secret_id: String) -> Dictionary:
	if not _is_ready(scene):
		return {"ok": false}
	var slot := _slot(scene)
	var slot_before: Dictionary = SaveService.load_slot(slot).duplicate(true)
	var target_placement: Dictionary = {}
	var secret_placement: Dictionary = {}
	for placement in _placements(scene):
		if String(placement.get("id", "")) == secret_id:
			secret_placement = placement
		if String(placement.get("type", "")) == "field_monster" and String(placement.get("monsterId", placement.get("id", ""))) == monster_id:
			target_placement = placement
	if target_placement.is_empty() or secret_placement.is_empty():
		return {
			"ok": false,
			"reason": "missing_target_or_secret",
			"monsterId": monster_id,
			"secretId": secret_id
		}
	var start_cell := _placement_runtime_cell(scene, target_placement)
	var before_cell: Vector2i = scene.get("player_cell")
	var slot_data := SaveService.load_slot(slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	field_monsters[String(target_placement.get("id", ""))] = {
		"startCell": [start_cell.x, start_cell.y],
		"currentCell": [start_cell.x, start_cell.y],
		"monsterId": String(target_placement.get("monsterId", target_placement.get("id", ""))),
		"patrolIndex": 1,
		"warningCounter": 0,
		"lostSightCounter": 0,
		"lastKnownPlayerCell": [start_cell.x, start_cell.y],
		"revealed": true,
		"aiState": "patrolling"
	}
	runtime["fieldMonsters"] = field_monsters
	var discovered: Dictionary = runtime.get("discoveredSecrets", {})
	discovered[String(secret_placement.get("id", ""))] = false
	runtime["discoveredSecrets"] = discovered
	slot_data["runtime"] = runtime
	SaveService.save_slot(slot, slot_data)
	scene.set("player_cell", Vector2i(6, 1))
	scene.call("_tick_field_monsters")
	var blocked_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var blocked_state: Dictionary = blocked_runtime.get("fieldMonsters", {}).get(String(target_placement.get("id", "")), {}).duplicate(true)
	scene.call("_discover_secret", secret_placement)
	scene.call("_tick_field_monsters")
	var discovered_runtime: Dictionary = SaveService.load_slot(slot).get("runtime", {})
	var discovered_state: Dictionary = discovered_runtime.get("fieldMonsters", {}).get(String(target_placement.get("id", "")), {}).duplicate(true)
	scene.set("player_cell", before_cell)
	SaveService.save_slot(slot, slot_before)
	scene.call("_persist_runtime")
	return {
		"ok": true,
		"monsterId": monster_id,
		"secretId": secret_id,
		"blockedState": blocked_state,
		"discoveredState": discovered_state
	}

func enter_combat(scene: Node) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("type", "")) == "field_monster":
			scene.call("_enter_combat", placement)
			return

func enter_combat_by_monster(scene: Node, monster_id: String) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("type", "")) != "field_monster":
			continue
		if String(placement.get("monsterId", placement.get("id", ""))) != monster_id:
			continue
		scene.call("_enter_combat", placement)
		return

func trigger_blood_altar(scene: Node) -> void:
	trigger_event(scene, "event_blood_altar_unlock")

func trigger_event(scene: Node, event_id: String) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("eventId", "")) != event_id:
			continue
		scene.call("_trigger_event_placement", placement)
		scene.call("_log", "Smoke triggered %s." % event_id)
		return

func return_town(scene: Node) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("type", "")) != "stairs":
			continue
		if String(placement.get("targetRoute", "")) != GameApp.MODE_TOWN:
			continue
		if String(placement.get("endingFlag", "")) == "campaignCleared":
			scene.call("_route_from_placement", placement)
			return
	for placement in _placements(scene):
		if String(placement.get("type", "")) == "stairs" and String(placement.get("targetRoute", "")) == GameApp.MODE_TOWN:
			scene.call("_route_from_placement", placement)
			return

func claim_reward(scene: Node) -> void:
	if _is_ready(scene):
		QuestService.claim_reward(_slot(scene))
		scene.call("_log", "Smoke claimed quest reward.")

func claim_quest_seed_reward(scene: Node) -> void:
	if not _is_ready(scene):
		return
	var result := QuestService.claim_quest_seed_reward(_slot(scene), "npc_scholar", "quest_seed_black_mural")
	if bool(result.get("ok", false)):
		scene.call("_log", "Smoke claimed quest seed reward.")

func open_inventory(scene: Node) -> void:
	if _is_ready(scene):
		scene.call("_toggle_inventory_overlay")

func open_service_by_npc(scene: Node, npc_id: String) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("npcId", "")) != npc_id:
			continue
		scene.call("_open_service_overlay", placement)
		return

func open_service_by_type(scene: Node, service_type: String) -> void:
	if not _is_ready(scene):
		return
	for placement in _placements(scene):
		if String(placement.get("type", "")) != service_type:
			continue
		scene.call("_open_service_overlay", placement)
		return

func benchmark_snapshot(scene: Node) -> Dictionary:
	if not _is_ready(scene):
		return {}
	var slot := _slot(scene)
	var slot_data: Dictionary = SaveService.load_slot(slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var player_cell: Vector2i = scene.get("player_cell")
	var map_data: Dictionary = scene.get("map_data")
	return {
		"mapId": String(map_data.get("id", "")),
		"playerCell": [player_cell.x, player_cell.y],
		"facing": int(scene.get("facing")),
		"dungeonSource": GameApp.dungeon_runtime_source,
		"minimap": {
			"visitedKeys": scene.call("_visited_keys_for_map", runtime),
			"questStatus": String(QuestService.current_quest(slot).get("status", "none")),
			"questTargetKeys": scene.call("_quest_target_keys"),
			"rewardTurnInKeys": scene.call("_quest_turn_in_keys"),
			"questSeedObjectiveKeys": scene.call("_quest_seed_objective_keys")
		}
	}

func _is_ready(scene: Node) -> bool:
	return scene != null and scene.has_method("_route_from_placement") and scene.get("map_data") is Dictionary

func _probe_cell_near(scene: Node, origin: Vector2i, preferred_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = [
		origin + Vector2i(0, preferred_distance),
		origin + Vector2i(0, -preferred_distance),
		origin + Vector2i(preferred_distance, 0),
		origin + Vector2i(-preferred_distance, 0),
		origin + Vector2i(0, 1),
		origin + Vector2i(0, -1),
		origin + Vector2i(1, 0),
		origin + Vector2i(-1, 0)
	]
	for cell in candidates:
		if not bool(scene.call("_cell_hard_blocked", cell)):
			return cell
	return origin

func _placements(scene: Node) -> Array:
	var data: Dictionary = scene.get("map_data")
	return data.get("placements", [])

func _slot(scene: Node) -> int:
	return int(scene.get("current_slot"))

func _placement_runtime_cell(scene: Node, placement: Dictionary, runtime: Dictionary = {}) -> Vector2i:
	return scene.call("_placement_runtime_cell", placement, runtime)

func _field_ai_config(scene: Node, placement: Dictionary) -> Dictionary:
	return scene.call("_field_ai_config", placement)

func _field_ai_behavior(scene: Node, placement: Dictionary) -> String:
	return String(scene.call("_field_ai_behavior", placement))

func _field_alert_group_id(scene: Node, placement: Dictionary) -> String:
	return String(scene.call("_field_alert_group_id", placement))

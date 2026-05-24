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

func _placements(scene: Node) -> Array:
	var data: Dictionary = scene.get("map_data")
	return data.get("placements", [])

func _slot(scene: Node) -> int:
	return int(scene.get("current_slot"))

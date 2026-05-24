extends RefCounted

var scene_ref: Node

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func trigger_interaction_placement(placement: Dictionary) -> void:
	match String(placement.get("type", "")):
		"gate", "stairs":
			route_from_placement(placement)
		"field_monster":
			enter_combat(placement)
		"quest_board", "healer", "skill_shop", "trade", "npc_service":
			scene_ref.call("_open_service_overlay", placement)
		"event":
			trigger_event_placement(placement)
		"locked_door":
			try_unlock_door(placement)
		"secret_door":
			discover_secret(placement)
		"loot":
			collect_loot(placement)
		"rest":
			rest_at_placement(placement)
		"trap":
			trigger_trap(placement)
		_:
			scene_ref.call("_log", "Interacted with %s." % placement.get("label", "placement"))

func route_from_placement(placement: Dictionary) -> void:
	var blocked_message := String(scene_ref.call("_route_block_message", placement))
	if blocked_message != "":
		scene_ref.call("_log", blocked_message)
		return
	if bool(scene_ref.call("_should_mark_campaign_clear", placement)):
		SaveService.mark_campaign_clear(
			int(scene_ref.get("current_slot")),
			String(scene_ref.call("_resolved_campaign_clear_title", placement)),
			String(scene_ref.get("map_data").get("id", scene_ref.get("default_map_id")))
		)
	var target_route := String(placement.get("targetRoute", "town"))
	var target_map_id := String(placement.get("targetMapId", "town_square"))
	GameApp.current_mode = target_route
	SceneRouter.change_route(target_route, {
		"slot": int(scene_ref.get("current_slot")),
		"map_id": target_map_id,
		"dungeon_source": String(scene_ref.get("dungeon_source_mode"))
	})

func enter_combat(placement: Dictionary) -> void:
	var map_data: Dictionary = scene_ref.get("map_data")
	GameApp.enter_combat({
		"slot": int(scene_ref.get("current_slot")),
		"monster_instance_id": String(placement.get("id", "")),
		"monster_id": String(placement.get("monsterId", placement.get("id", ""))),
		"monster_name": String(placement.get("label", "Field Monster")),
		"return_route": String(scene_ref.get("route_name")),
		"return_map_id": String(map_data.get("id", scene_ref.get("default_map_id")))
	})

func trigger_event_placement(placement: Dictionary) -> void:
	var event_id := String(placement.get("eventId", ""))
	var event_def := ContentRegistry.get_definition("events", event_id)
	var result := EventService.apply_event(int(scene_ref.get("current_slot")), event_id, event_def)
	var messages: Array = result.get("messages", [])
	if messages.is_empty():
		scene_ref.call("_log", "Triggered %s." % placement.get("label", "event"))
	else:
		for message in messages:
			if String(message).strip_edges() != "":
				scene_ref.call("_log", String(message))

func try_unlock_door(placement: Dictionary) -> void:
	var current_slot := int(scene_ref.get("current_slot"))
	var key_item := String(placement.get("keyItemId", "rust_key"))
	if not SaveService.has_inventory_item(current_slot, key_item, 1):
		scene_ref.call("_log", "Door is locked. Missing %s." % key_item)
		return
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
	unlocked_doors[String(placement.get("id", ""))] = true
	runtime["unlockedDoors"] = unlocked_doors
	SaveService.update_runtime(current_slot, runtime, String(scene_ref.get("route_name")))
	scene_ref.call("_refresh_field_monsters")
	scene_ref.call("_log", "Unlocked %s." % placement.get("label", "door"))

func discover_secret(placement: Dictionary) -> void:
	var current_slot := int(scene_ref.get("current_slot"))
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var discovered: Dictionary = runtime.get("discoveredSecrets", {})
	if bool(discovered.get(String(placement.get("id", "")), false)):
		scene_ref.call("_log", "Secret already discovered.")
		return
	discovered[String(placement.get("id", ""))] = true
	runtime["discoveredSecrets"] = discovered
	SaveService.update_runtime(current_slot, runtime, String(scene_ref.get("route_name")))
	var contains_item := String(placement.get("containsItemId", ""))
	if contains_item != "":
		SaveService.add_inventory_item(current_slot, contains_item, 1)
	scene_ref.call("_log", "Discovered secret cache: %s." % placement.get("label", "secret"))
	scene_ref.call("_refresh_field_monsters")

func collect_loot(placement: Dictionary) -> void:
	var current_slot := int(scene_ref.get("current_slot"))
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	var runtime: Dictionary = slot_data.get("runtime", {})
	var claimed: Dictionary = runtime.get("claimedLoot", {})
	if bool(claimed.get(String(placement.get("id", "")), false)):
		scene_ref.call("_log", "Loot already claimed.")
		return
	claimed[String(placement.get("id", ""))] = true
	runtime["claimedLoot"] = claimed
	SaveService.update_runtime(current_slot, runtime, String(scene_ref.get("route_name")))
	var rewards := ContentRegistry.resolve_loot_items(String(placement.get("lootTableId", "")))
	if rewards.is_empty():
		rewards.append({
			"itemId": String(placement.get("itemId", "healing_tonic")),
			"quantity": 1
		})
	for reward in rewards:
		SaveService.add_inventory_item(current_slot, String(reward.get("itemId", "")), int(reward.get("quantity", 1)))
	var reward_summary: Array[String] = []
	for reward in rewards:
		reward_summary.append("%s x%d" % [reward.get("itemId", ""), int(reward.get("quantity", 1))])
	SaveService.append_recent_reward(current_slot, {
		"source": "loot",
		"label": String(placement.get("label", "loot")),
		"items": reward_summary,
		"summary": "Loot %s" % ", ".join(reward_summary)
	})
	scene_ref.call("_log", "Collected %s: %s." % [placement.get("label", "loot"), ", ".join(reward_summary)])
	scene_ref.call("_refresh_field_monsters")

func rest_at_placement(placement: Dictionary) -> void:
	var event_id := String(placement.get("eventId", ""))
	var event_def := ContentRegistry.get_definition("events", event_id)
	var result := EventService.apply_event(int(scene_ref.get("current_slot")), event_id, event_def)
	var messages: Array = result.get("messages", [])
	if messages.is_empty():
		scene_ref.call("_log", "Rested at %s." % placement.get("label", "camp"))
	else:
		for message in messages:
			if String(message).strip_edges() != "":
				scene_ref.call("_log", String(message))

func trigger_trap(placement: Dictionary) -> void:
	var event_id := String(placement.get("eventId", ""))
	var event_def := ContentRegistry.get_definition("events", event_id)
	var result := EventService.apply_event(int(scene_ref.get("current_slot")), event_id, event_def)
	var messages: Array = result.get("messages", [])
	if messages.is_empty():
		scene_ref.call("_log", "Trap triggered at %s." % placement.get("label", "trap"))
	else:
		for message in messages:
			if String(message).strip_edges() != "":
				scene_ref.call("_log", String(message))

func try_rest() -> void:
	var map_data: Dictionary = scene_ref.get("map_data")
	var player_cell: Vector2i = scene_ref.get("player_cell")
	for placement in map_data.get("placements", []):
		if String(placement.get("type", "")) == "rest":
			var pos: Array = placement.get("position", [0, 0])
			if Vector2i(pos[0], pos[1]) == player_cell:
				rest_at_placement(placement)
				return
	scene_ref.call("_log", "No rest point here.")

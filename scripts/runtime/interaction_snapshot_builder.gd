extends RefCounted

var scene_ref: Node

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func snapshot() -> Dictionary:
	var placement: Dictionary = scene_ref.call("_front_interaction_placement")
	var source := "front"
	var distance := 1
	var town_focus: RefCounted = scene_ref.get("town_focus_runtime")
	if placement.is_empty() and bool(scene_ref.call("_is_town_map")):
		placement = town_focus.call("selected_placement", 2) if town_focus != null else {}
		if not placement.is_empty():
			source = "selected"
		else:
			placement = town_focus.call("nearby_interaction_placement", 2) if town_focus != null else {}
			if not placement.is_empty():
				source = "nearby"
		if not placement.is_empty():
			var nearby_cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
			var player_cell: Vector2i = scene_ref.get("player_cell")
			distance = abs(nearby_cell.x - player_cell.x) + abs(nearby_cell.y - player_cell.y)
	if placement.is_empty():
		return {
			"available": false,
			"title": "앞에 상호작용 대상이 없다.",
			"detail": "시선을 돌리거나 한 칸 이동해 거점과 통로를 맞춘다."
		}
	var kind := String(placement.get("type", ""))
	var title := String(placement.get("label", placement.get("id", kind)))
	var action := "Space로 상호작용"
	var detail := ""
	var current_slot := int(scene_ref.get("current_slot"))
	var town_service_preview := String(town_focus.call("service_preview", placement, current_slot)) if town_focus != null else ""
	if source == "selected" and distance > 1:
		action = "Space로 접근"
	match kind:
		"quest_board":
			if action == "Space로 상호작용":
				action = "Space로 의뢰 확인"
			detail = "현재 보드 오퍼와 보상 전표를 확인한다.\n%s" % town_service_preview
		"healer":
			if action == "Space로 상호작용":
				action = "Space로 치료"
			detail = "전열 체력과 상태를 회복하는 서비스다.\n%s" % town_service_preview
		"skill_shop":
			if action == "Space로 상호작용":
				action = "Space로 기술 상점 열기"
			detail = "현재 재고와 리롤 가능한 기술 목록을 본다.\n%s" % town_service_preview
		"trade":
			if action == "Space로 상호작용":
				action = "Space로 거래"
			detail = "소모품과 잡화를 구매한다.\n%s" % town_service_preview
		"npc_service":
			if action == "Space로 상호작용":
				action = "Space로 대화"
			detail = "NPC 서비스와 대화 분기를 연다.\n%s" % town_service_preview
		"gate", "stairs":
			if action == "Space로 상호작용":
				action = "Space로 이동"
			var blocked_message: String = scene_ref.call("_route_block_message", placement)
			detail = route_affordance_detail(placement, blocked_message)
		"rest":
			if action == "Space로 상호작용":
				action = "Space로 휴식"
			detail = "짧은 휴식과 회복을 시도한다.\n%s" % town_service_preview
		"field_monster":
			action = "Space로 전투 진입"
			detail = field_monster_affordance_detail(placement)
		"event":
			action = "Space로 이벤트 조사"
			detail = event_affordance_detail(placement)
		"locked_door":
			action = "Space로 문 확인"
			detail = door_affordance_detail(placement)
		"secret_door":
			action = "Space로 비밀문 확인"
			detail = secret_affordance_detail(placement)
		"loot":
			action = "Space로 수집"
			detail = loot_affordance_detail(placement)
		"trap":
			action = "Space로 함정 접촉"
			detail = trap_affordance_detail(placement)
	var blocked := kind in ["gate", "stairs"] and String(scene_ref.call("_route_block_message", placement)) != ""
	return {
		"available": true,
		"id": String(placement.get("id", "")),
		"type": kind,
		"title": title,
		"action": action,
		"detail": detail,
		"blocked": blocked,
		"source": source,
		"distance": distance,
		"hint": String(town_focus.call("alignment_hint", placement, source, distance)) if town_focus != null else "",
		"selection": String(town_focus.call("focus_summary", placement, source)) if town_focus != null else "",
		"anchorCell": town_focus.call("anchor_snapshot", placement, source) if town_focus != null else [],
		"intent": intent_label(placement, source, distance),
		"nextStep": next_step_snapshot(placement, source),
		"guide": guide_text(placement, source, distance)
	}

func prompt_text() -> String:
	var interaction := snapshot()
	if not bool(interaction.get("available", false)):
		return String(interaction.get("title", ""))
	var suffix := String(interaction.get("action", ""))
	var hint := String(interaction.get("hint", ""))
	if hint != "":
		suffix += " / %s" % hint
	return "%s - %s" % [String(interaction.get("title", "")), suffix]

func next_step_snapshot(placement: Dictionary, source: String) -> Array:
	if placement.is_empty():
		return []
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var town_focus: RefCounted = scene_ref.get("town_focus_runtime")
	if bool(scene_ref.call("_is_town_map")) and source == "selected":
		var anchor: Vector2i = town_focus.call("interaction_anchor_cell", placement) if town_focus != null else player_cell
		var next_step: Vector2i = town_focus.call("next_step_toward", anchor) if town_focus != null else player_cell
		if next_step != player_cell:
			return [next_step.x, next_step.y]
	var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
	return [cell.x, cell.y]

func guide_text(placement: Dictionary, source: String, distance: int) -> String:
	var intent := intent_label(placement, source, distance)
	if source == "selected" and distance > 1:
		return "W/Space advances toward the selected hub."
	match intent:
		"route":
			var blocked: String = scene_ref.call("_route_block_message", placement)
			if blocked != "":
				return "Route is gated: satisfy the listed condition before using Space."
			return "Space travels to the linked map."
		"combat":
			return "Space starts combat; prepare skills/items before engaging."
		"event":
			return "Space resolves this event or hazard immediately."
		"door":
			return "Space checks the door; keys/secrets may change passability."
		"reward":
			return "Space collects loot and records it in recent rewards."
		"rest":
			return "Space rests here and applies the authored recovery event."
		"service":
			return "Space opens the NPC/service menu."
		_:
			return "Space interacts with the highlighted object."

func intent_label(placement: Dictionary, source: String, distance: int) -> String:
	var kind := String(placement.get("type", ""))
	if source == "selected" and distance > 1:
		return "approach"
	match kind:
		"gate", "stairs":
			return "route"
		"field_monster":
			return "combat"
		"event", "trap":
			return "event"
		"locked_door", "secret_door":
			return "door"
		"npc_service", "quest_board", "healer", "skill_shop", "trade":
			return "service"
		"loot":
			return "reward"
		"rest":
			return "rest"
		_:
			return "interact"

func objective_guide_snapshot() -> Dictionary:
	var current_slot := int(scene_ref.get("current_slot"))
	var quest_state := QuestService.current_quest(current_slot)
	var quest_status := String(quest_state.get("status", "none"))
	var title := "Explore"
	var detail := "Map unknowns, read nearby markers, and push toward open routes."
	var tone := "neutral"
	if quest_status == "accepted":
		title = "Quest Target"
		var target_monster_id := String(quest_state.get("targetMonsterId", ""))
		var monster_def := ContentRegistry.get_definition("monsters", target_monster_id)
		detail = "Find and defeat %s. Quest targets are marked on the minimap when visible." % String(monster_def.get("name", target_monster_id))
		tone = "danger"
	elif quest_status == "complete_ready":
		title = "Turn In Reward"
		detail = "Return to a quest board or eligible NPC service to claim the completed quest reward."
		tone = "reward"
	for route in scene_ref.call("_route_state_entries"):
		if typeof(route) != TYPE_DICTIONARY:
			continue
		if not bool(route.get("blocked", false)):
			continue
		var blocked_message := String(route.get("blockedMessage", ""))
		if blocked_message != "":
			detail += "\nGate: %s" % blocked_message
			break
	var active_seeds: Array[String] = []
	var quest_seeds := QuestService.quest_seed_states(current_slot)
	for seed_id in quest_seeds.keys():
		var state: Dictionary = quest_seeds.get(seed_id, {})
		if String(state.get("status", "")) == "active":
			active_seeds.append(String(state.get("title", seed_id)))
	if not active_seeds.is_empty():
		title = "Quest Seed"
		detail += "\nSeed: %s" % ", ".join(active_seeds)
		tone = "reward" if quest_status == "complete_ready" else "neutral"
	return {
		"title": title,
		"detail": detail,
		"tone": tone
	}

func route_affordance_detail(placement: Dictionary, blocked_message: String) -> String:
	var target_route := String(placement.get("targetRoute", ""))
	var target_map_id := String(placement.get("targetMapId", ""))
	var lines: Array[String] = []
	if blocked_message != "":
		lines.append("[color=#d89a6d]%s[/color]" % blocked_message)
	else:
		lines.append("[color=#9fd6a5]열림[/color] 다음 지역으로 이동한다.")
	if target_route != "" or target_map_id != "":
		lines.append("목적지: %s / %s" % [target_route, target_map_id])
	var required_flag := String(placement.get("requiredFlag", ""))
	if required_flag != "":
		lines.append("필요 flag: %s" % required_flag)
	var required_seed_id := String(placement.get("requiredQuestSeedId", ""))
	if required_seed_id != "":
		lines.append("필요 quest seed: %s = %s" % [required_seed_id, String(placement.get("requiredQuestSeedStatus", "rewarded"))])
	return "\n".join(lines)

func field_monster_affordance_detail(placement: Dictionary) -> String:
	var monster_id := String(placement.get("monsterId", placement.get("id", "")))
	var monster_def := ContentRegistry.get_definition("monsters", monster_id)
	var ai: Dictionary = scene_ref.call("_field_ai_config", placement)
	var profile: Dictionary = monster_def.get("combatProfile", {})
	var lines := [
		"전방 몬스터와 즉시 전투를 시작한다.",
		"대상: %s / encounter %s" % [String(monster_def.get("name", monster_id)), String(placement.get("encounterId", ""))],
		"AI: %s alert=%s faction=%s" % [String(ai.get("behavior", "guard")), String(ai.get("alertGroup", "")), String(ai.get("faction", ""))]
	]
	if not profile.is_empty():
		lines.append("전투 성향: %s" % String(profile.get("behavior", profile.get("role", "profile"))))
	return "\n".join(lines)

func event_affordance_detail(placement: Dictionary) -> String:
	var event_id := String(placement.get("eventId", ""))
	var event_def := ContentRegistry.get_definition("events", event_id)
	var entry_step := String(event_def.get("entryStepId", ""))
	var effect_count := int(event_def.get("effects", []).size())
	var step_count := int(event_def.get("steps", []).size())
	return "이벤트 정의와 분기를 실행한다.\n%s / entry %s / steps %d / effects %d" % [
		String(event_def.get("name", event_id)),
		entry_step if entry_step != "" else "direct",
		step_count,
		effect_count
	]

func door_affordance_detail(placement: Dictionary) -> String:
	var current_slot := int(scene_ref.get("current_slot"))
	var key_item := String(placement.get("keyItemId", ""))
	var has_key := key_item != "" and SaveService.inventory(current_slot).has(key_item)
	if key_item == "":
		return "잠금 상태와 차단 이유를 확인한다."
	return "잠긴 통로다.\n필요 열쇠: %s / 보유 %s" % [key_item, "yes" if has_key else "no"]

func secret_affordance_detail(placement: Dictionary) -> String:
	var contains_item := String(placement.get("containsItemId", ""))
	if contains_item != "":
		return "발견된 경우 통로와 보상이 열린다.\n단서 보상: %s" % contains_item
	return "발견된 경우에만 통로가 열린다."

func loot_affordance_detail(placement: Dictionary) -> String:
	var loot_table_id := String(placement.get("lootTableId", ""))
	var item_id := String(placement.get("itemId", ""))
	var parts: Array[String] = ["획득 가능한 보상이나 아이템을 챙긴다."]
	if loot_table_id != "":
		parts.append("loot table: %s" % loot_table_id)
	if item_id != "":
		parts.append("fallback item: %s" % item_id)
	return "\n".join(parts)

func trap_affordance_detail(placement: Dictionary) -> String:
	var event_id := String(placement.get("eventId", ""))
	var event_def := ContentRegistry.get_definition("events", event_id)
	var detection: Dictionary = event_def.get("detection", {})
	var disarm: Dictionary = event_def.get("disarm", {})
	var lines: Array[String] = ["주의하지 않으면 즉시 효과가 발동한다."]
	if not detection.is_empty():
		lines.append("탐지: %s DC %d" % [String(detection.get("check", "")), int(detection.get("difficulty", 0))])
	if not disarm.is_empty():
		lines.append("해제: %s DC %d" % [String(disarm.get("check", "")), int(disarm.get("difficulty", 0))])
	return "\n".join(lines)

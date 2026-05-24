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
			detail = scene_ref.call("_route_affordance_detail", placement, blocked_message)
		"rest":
			if action == "Space로 상호작용":
				action = "Space로 휴식"
			detail = "짧은 휴식과 회복을 시도한다.\n%s" % town_service_preview
		"field_monster":
			action = "Space로 전투 진입"
			detail = scene_ref.call("_field_monster_affordance_detail", placement)
		"event":
			action = "Space로 이벤트 조사"
			detail = scene_ref.call("_event_affordance_detail", placement)
		"locked_door":
			action = "Space로 문 확인"
			detail = scene_ref.call("_door_affordance_detail", placement)
		"secret_door":
			action = "Space로 비밀문 확인"
			detail = scene_ref.call("_secret_affordance_detail", placement)
		"loot":
			action = "Space로 수집"
			detail = scene_ref.call("_loot_affordance_detail", placement)
		"trap":
			action = "Space로 함정 접촉"
			detail = scene_ref.call("_trap_affordance_detail", placement)
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

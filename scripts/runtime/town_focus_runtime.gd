extends RefCounted

const DIRS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]

var scene_ref: Node
var target_ids: Array[String] = []
var focus_index := -1

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func selected_id() -> String:
	if focus_index < 0 or focus_index >= target_ids.size():
		return ""
	return target_ids[focus_index]

func refresh_targets() -> void:
	if not _scene_ready() or not bool(scene_ref.call("_is_town_map")):
		target_ids.clear()
		focus_index = -1
		return
	var previous_id := selected_id()
	target_ids.clear()
	var ranked: Array[Dictionary] = []
	for placement in scene_ref.get("map_data").get("placements", []):
		if not supports_proximity(placement):
			continue
		var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
		var player_cell: Vector2i = scene_ref.get("player_cell")
		var distance: int = abs(cell.x - player_cell.x) + abs(cell.y - player_cell.y)
		if distance > 2:
			continue
		ranked.append({
			"id": String(placement.get("id", "")),
			"distance": distance,
			"score": _direction_score(cell)
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("distance", 99)) != int(b.get("distance", 99)):
			return int(a.get("distance", 99)) < int(b.get("distance", 99))
		if int(a.get("score", 99)) != int(b.get("score", 99)):
			return int(a.get("score", 99)) < int(b.get("score", 99))
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	for entry in ranked:
		target_ids.append(String(entry.get("id", "")))
	if target_ids.is_empty():
		focus_index = -1
		return
	var restored_index := target_ids.find(previous_id)
	focus_index = restored_index if restored_index >= 0 else 0

func nearby_interaction_placement(max_distance: int) -> Dictionary:
	var best := {}
	var best_distance := 999
	if not _scene_ready():
		return best
	for placement in scene_ref.get("map_data").get("placements", []):
		if not supports_proximity(placement):
			continue
		var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
		var player_cell: Vector2i = scene_ref.get("player_cell")
		var distance: int = abs(cell.x - player_cell.x) + abs(cell.y - player_cell.y)
		if distance > max_distance:
			continue
		if distance < best_distance:
			best = placement
			best_distance = distance
	return best

func selected_placement(max_distance: int = -1) -> Dictionary:
	if not _scene_ready() or not bool(scene_ref.call("_is_town_map")):
		return {}
	var focus_id := selected_id()
	if focus_id == "":
		return {}
	for placement in scene_ref.get("map_data").get("placements", []):
		if String(placement.get("id", "")) != focus_id:
			continue
		if max_distance >= 0:
			var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
			var player_cell: Vector2i = scene_ref.get("player_cell")
			var distance: int = abs(cell.x - player_cell.x) + abs(cell.y - player_cell.y)
			if distance > max_distance:
				return {}
		return placement
	return {}

func supports_proximity(placement: Dictionary) -> bool:
	match String(placement.get("type", "")):
		"quest_board", "healer", "skill_shop", "trade", "npc_service", "rest":
			return true
		_:
			return false

func try_approach(placement: Dictionary) -> bool:
	if not _scene_ready():
		return false
	orient_toward(placement)
	var front_placement: Dictionary = scene_ref.call("_front_interaction_placement")
	if not front_placement.is_empty() and String(front_placement.get("id", "")) == String(placement.get("id", "")):
		return false
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var anchor := interaction_anchor_cell(placement)
	if anchor == player_cell:
		return false
	var next_step := next_step_toward(anchor)
	if next_step == player_cell:
		return false
	var label := String(placement.get("label", placement.get("id", "거점")))
	var direction := next_step - player_cell
	scene_ref.call("_log", "%s 쪽으로 다가간다." % label)
	scene_ref.call("_try_move", direction)
	orient_toward(placement)
	scene_ref.call("_refresh_interaction_focus")
	return true

func try_advance_path() -> bool:
	if not _scene_ready() or not bool(scene_ref.call("_is_town_map")):
		return false
	var placement := selected_placement(99)
	if placement.is_empty():
		return false
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var anchor := interaction_anchor_cell(placement)
	if anchor == player_cell:
		return false
	var next_step := next_step_toward(anchor)
	if next_step == player_cell:
		return false
	var label := String(placement.get("label", placement.get("id", "거점")))
	var direction := next_step - player_cell
	scene_ref.call("_log", "%s 경로를 따라 전진한다." % label)
	scene_ref.call("_try_move", direction)
	orient_toward(placement)
	scene_ref.call("_refresh_interaction_focus")
	return true

func interaction_anchor_cell(placement: Dictionary) -> Vector2i:
	var target: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var best := player_cell
	var best_distance := 999
	for dir in DIRS:
		var candidate: Vector2i = target + dir
		if candidate != player_cell and bool(scene_ref.call("_is_blocked", candidate)):
			continue
		var distance: int = abs(candidate.x - player_cell.x) + abs(candidate.y - player_cell.y)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func next_step_toward(anchor: Vector2i) -> Vector2i:
	var path := path_to_anchor(anchor)
	if path.size() < 2:
		return scene_ref.get("player_cell")
	return path[1]

func path_to_anchor(anchor: Vector2i) -> Array[Vector2i]:
	var player_cell: Vector2i = scene_ref.get("player_cell")
	if anchor == player_cell:
		return [player_cell]
	var queue: Array[Vector2i] = [player_cell]
	var came_from := {player_cell: player_cell}
	var found := false
	for _guard in range(4096):
		if queue.is_empty():
			break
		var current: Vector2i = queue.pop_front()
		if current == anchor:
			found = true
			break
		for dir in DIRS:
			var candidate: Vector2i = current + dir
			if came_from.has(candidate):
				continue
			if candidate != anchor and bool(scene_ref.call("_is_blocked", candidate)):
				continue
			came_from[candidate] = current
			queue.append(candidate)
	if not found:
		return [player_cell]
	var reversed_path: Array[Vector2i] = [anchor]
	var step: Vector2i = anchor
	while step != player_cell:
		step = came_from.get(step, player_cell)
		reversed_path.append(step)
	reversed_path.reverse()
	return reversed_path

func alignment_hint(placement: Dictionary, source: String, distance: int) -> String:
	if source == "front":
		return ""
	if source == "selected":
		var selected_hint := direction_hint(placement, distance)
		if selected_hint == "":
			return "선택한 거점 / Q,E 전환"
		return "선택한 거점 / %s / Q,E 전환" % selected_hint
	return direction_hint(placement, distance)

func direction_hint(placement: Dictionary, distance: int) -> String:
	var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var dx := cell.x - player_cell.x
	var dy := cell.y - player_cell.y
	var parts: Array[String] = []
	if dy < 0:
		parts.append("앞")
	elif dy > 0:
		parts.append("뒤")
	if dx > 0:
		parts.append("오른쪽")
	elif dx < 0:
		parts.append("왼쪽")
	var direction_label := " / ".join(parts)
	if distance <= 1:
		return "근처 상호작용"
	if direction_label == "":
		return "%d칸 거리" % distance
	return "%s %d칸" % [direction_label, distance]

func cycle_focus(step: int) -> void:
	refresh_targets()
	if target_ids.is_empty():
		scene_ref.call("_log", "근처에 고를 수 있는 거점이 없다.")
		scene_ref.call("_refresh_interaction_focus")
		return
	focus_index = posmod(focus_index + step, target_ids.size())
	var placement := selected_placement()
	orient_toward(placement)
	if not placement.is_empty():
		scene_ref.call("_log", "거점 선택: %s" % String(placement.get("label", placement.get("id", "거점"))))
	scene_ref.call("_refresh_interaction_focus")
	scene_ref.call("_persist_runtime")

func focus_summary(active_placement: Dictionary, source: String) -> String:
	if not _scene_ready() or not bool(scene_ref.call("_is_town_map")) or target_ids.is_empty():
		return ""
	var parts: Array[String] = []
	for idx in range(target_ids.size()):
		var placement_id := target_ids[idx]
		var marker := ">" if idx == focus_index else " "
		var label := placement_id
		if source == "front" and not active_placement.is_empty() and String(active_placement.get("id", "")) == placement_id:
			marker = "*"
		for placement in scene_ref.get("map_data").get("placements", []):
			if String(placement.get("id", "")) == placement_id:
				label = String(placement.get("label", placement_id))
				break
		parts.append("%s%s" % [marker, label])
	return "거점 %d/%d  %s" % [focus_index + 1, target_ids.size(), " · ".join(parts)]

func anchor_snapshot(placement: Dictionary, source: String) -> Array:
	if not _scene_ready() or not bool(scene_ref.call("_is_town_map")) or source not in ["selected", "nearby"]:
		return []
	var anchor := interaction_anchor_cell(placement)
	return [anchor.x, anchor.y]

func orient_toward(placement: Dictionary) -> void:
	if placement.is_empty():
		return
	var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var delta: Vector2i = cell - player_cell
	if delta == Vector2i.ZERO:
		return
	if abs(delta.x) >= abs(delta.y):
		scene_ref.set("facing", 1 if delta.x > 0 else 3)
	else:
		scene_ref.set("facing", 2 if delta.y > 0 else 0)
	scene_ref.call("_apply_player_transform")

func focus_snapshot() -> Dictionary:
	if not _scene_ready() or not bool(scene_ref.call("_is_town_map")):
		return {}
	var entries: Array[Dictionary] = []
	var selected := selected_placement(99)
	var selected_anchor := anchor_snapshot(selected, "selected")
	var next_step: Array = []
	var path_length := 0
	if not selected.is_empty():
		var path := path_to_anchor(interaction_anchor_cell(selected))
		path_length = maxi(path.size() - 1, 0)
		if path.size() >= 2:
			next_step = [path[1].x, path[1].y]
	var player_cell: Vector2i = scene_ref.get("player_cell")
	for idx in range(target_ids.size()):
		var placement_id := target_ids[idx]
		for placement in scene_ref.get("map_data").get("placements", []):
			if String(placement.get("id", "")) != placement_id:
				continue
			var cell: Vector2i = scene_ref.call("_placement_runtime_cell", placement)
			entries.append({
				"id": placement_id,
				"label": String(placement.get("label", placement_id)),
				"type": String(placement.get("type", "")),
				"selected": idx == focus_index,
				"distance": abs(cell.x - player_cell.x) + abs(cell.y - player_cell.y)
			})
			break
	return {
		"entries": entries,
		"selectedIndex": focus_index,
		"controls": "Q/E 전환, W/Space 이동, Space 상호작용",
		"selectedAnchor": selected_anchor,
		"nextStep": next_step,
		"pathLength": path_length
	}

func service_preview(placement: Dictionary, current_slot: int) -> String:
	var kind := String(placement.get("type", ""))
	match kind:
		"quest_board":
			var summary := QuestService.quest_board_summary(current_slot)
			var offers: Array = summary.get("offers", [])
			var labels: Array[String] = []
			for offer_variant in offers.slice(0, mini(2, offers.size())):
				if typeof(offer_variant) != TYPE_DICTIONARY:
					continue
				var offer: Dictionary = offer_variant
				labels.append("%s %dg" % [String(offer.get("targetMonsterName", offer.get("id", ""))), int(offer.get("rewardGold", 0))])
			return "오퍼 %d개%s" % [offers.size(), " | " + ", ".join(labels) if not labels.is_empty() else ""]
		"healer":
			return "전열 회복 / 상태 정리 / 여관 비용 5g"
		"skill_shop":
			var vendor_id := String(placement.get("vendorId", ""))
			var vendor_def := ContentRegistry.get_definition("vendors", vendor_id)
			var stock := ShopService.ensure_skill_shop_stock(current_slot, vendor_id, vendor_def)
			var stock_labels: Array[String] = []
			for row_variant in stock.slice(0, mini(2, stock.size())):
				if typeof(row_variant) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_variant
				stock_labels.append("%s %dg" % [String(row.get("name", row.get("skillId", ""))), int(row.get("price", 0))])
			return "기술 재고 %d개%s" % [stock.size(), " | " + ", ".join(stock_labels) if not stock_labels.is_empty() else ""]
		"trade":
			var vendor_trade := ContentRegistry.get_definition("vendors", String(placement.get("vendorId", "")))
			var item_labels: Array[String] = []
			for item_id_variant in vendor_trade.get("items", []).slice(0, mini(3, vendor_trade.get("items", []).size())):
				var item_id := String(item_id_variant)
				var item_def := ContentRegistry.get_definition("items", item_id)
				item_labels.append("%s %dg" % [String(item_def.get("name", item_id)), int(item_def.get("price", vendor_trade.get("price", 0)))])
			return "판매품 %s" % ", ".join(item_labels)
		"npc_service":
			var service_rows := NpcService.describe_services_for_slot(current_slot, String(placement.get("npcId", "")))
			var preview_rows: Array[String] = []
			for row_variant in service_rows.slice(0, mini(3, service_rows.size())):
				if typeof(row_variant) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_variant
				var service: Dictionary = row.get("service", {})
				var label := "%s:%s" % [String(service.get("type", "")), String(service.get("label", ""))]
				if not bool(row.get("available", false)):
					label += " (잠김)"
				preview_rows.append(label)
			return "서비스 %s" % " | ".join(preview_rows)
		"rest":
			return "캠프파이어에서 휴식 / 회복 시도"
		_:
			return ""

func _direction_score(cell: Vector2i) -> int:
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var target_dir: Vector2i = cell - player_cell
	var facing := int(scene_ref.get("facing"))
	var front_dir: Vector2i = DIRS[facing]
	if target_dir == front_dir:
		return 0
	if target_dir == -front_dir:
		return 3
	if target_dir.x == front_dir.y and target_dir.y == -front_dir.x:
		return 1
	if target_dir.x == -front_dir.y and target_dir.y == front_dir.x:
		return 2
	return 4

func _scene_ready() -> bool:
	return scene_ref != null and is_instance_valid(scene_ref)

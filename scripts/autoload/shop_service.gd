extends Node

func current_skill_shop_stock(slot: int, vendor_id: String) -> Array[Dictionary]:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return []
	var shop_state: Dictionary = data.get("shopState", {})
	var vendor_state: Dictionary = shop_state.get(vendor_id, {})
	var stock: Array[Dictionary] = []
	for row in vendor_state.get("stock", []):
		if typeof(row) == TYPE_DICTIONARY:
			stock.append(row)
	return stock

func ensure_skill_shop_stock(slot: int, vendor_id: String, vendor_def: Dictionary = {}) -> Array[Dictionary]:
	var existing := current_skill_shop_stock(slot, vendor_id)
	if not existing.is_empty():
		return existing
	return reroll_skill_shop_stock(slot, vendor_id, vendor_def)

func reroll_skill_shop_stock(slot: int, vendor_id: String, vendor_def: Dictionary = {}) -> Array[Dictionary]:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return []
	var shop_state: Dictionary = data.get("shopState", {})
	var vendor_state: Dictionary = shop_state.get(vendor_id, {})
	var reroll_count := int(vendor_state.get("rerollCount", 0))
	var stock_size := maxi(int(vendor_def.get("stockSize", 3)), 1)
	var candidate_ids: Array[String] = []
	var known_skills: Array = data.get("knownSkills", [])
	var vendor_skill_ids: Array = vendor_def.get("skillIds", [])
	if vendor_skill_ids.is_empty():
		for row in ContentRegistry.list_definitions("skills"):
			var row_id := String(row.get("id", ""))
			if row_id != "":
				vendor_skill_ids.append(row_id)
	for skill_id_variant in vendor_skill_ids:
		var skill_id := String(skill_id_variant)
		if skill_id == "" or known_skills.has(skill_id):
			continue
		var skill_def := ContentRegistry.get_definition("skills", skill_id)
		if skill_def.is_empty():
				continue
		candidate_ids.append(skill_id)
	candidate_ids.sort()
	var seed_input := "%s:%d:%d" % [vendor_id, slot, int(data.get("contentVersion", 0))]
	var offset := 0
	if not candidate_ids.is_empty():
		offset = (_stable_hash(seed_input) + reroll_count) % candidate_ids.size()
	var rotated_ids: Array[String] = []
	for index in range(candidate_ids.size()):
		rotated_ids.append(candidate_ids[(index + offset) % candidate_ids.size()])
	var picked_ids: Array[String] = []
	for skill_id in rotated_ids:
		if picked_ids.size() >= stock_size:
			break
		picked_ids.append(skill_id)
	var stock: Array[Dictionary] = []
	for skill_id in picked_ids:
		var skill_def := ContentRegistry.get_definition("skills", skill_id)
		stock.append({
			"skillId": skill_id,
			"name": String(skill_def.get("name", skill_id)),
			"price": int(skill_def.get("price", 20))
		})
	shop_state[vendor_id] = {
		"stock": stock,
		"updatedAt": Time.get_datetime_string_from_system(),
		"rerollCount": reroll_count + 1
	}
	data["shopState"] = shop_state
	SaveService.save_slot(slot, data)
	return stock

func buy_skill(slot: int, vendor_id: String, skill_id: String) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var shop_state: Dictionary = data.get("shopState", {})
	var vendor_state: Dictionary = shop_state.get(vendor_id, {})
	var stock: Array = vendor_state.get("stock", [])
	var target_row: Dictionary = {}
	var remove_index := -1
	for index in range(stock.size()):
		var row: Variant = stock[index]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if String(row.get("skillId", "")) == skill_id:
			target_row = row
			remove_index = index
			break
	if target_row.is_empty():
		return {"ok": false, "message": "Skill is not in current stock."}
	var known_skills: Array = data.get("knownSkills", [])
	if known_skills.has(skill_id):
		return {"ok": false, "message": "Skill already known."}
	var price := int(target_row.get("price", 0))
	var resources: Dictionary = data.get("resources", {})
	var gold := int(resources.get("gold", 0))
	if gold < price:
		return {"ok": false, "message": "Not enough gold to buy %s." % String(target_row.get("name", skill_id))}
	resources["gold"] = gold - price
	data["resources"] = resources
	known_skills.append(skill_id)
	data["knownSkills"] = known_skills
	if remove_index >= 0:
		stock.remove_at(remove_index)
	vendor_state["stock"] = stock
	shop_state[vendor_id] = vendor_state
	data["shopState"] = shop_state
	SaveService.save_slot(slot, data)
	return {
		"ok": true,
		"message": "Bought %s." % String(target_row.get("name", skill_id)),
		"skillId": skill_id,
		"kind": String(ContentRegistry.get_definition("skills", skill_id).get("kind", "attack"))
	}

func buy_vendor_item(slot: int, vendor_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	var data: Dictionary = SaveService.load_slot(slot)
	if data.is_empty():
		return {"ok": false, "message": "Missing save slot."}
	var vendor_def := ContentRegistry.get_definition("vendors", vendor_id)
	if vendor_def.is_empty():
		return {"ok": false, "message": "Missing vendor definition."}
	var item_ids: Array = vendor_def.get("items", [])
	if not item_ids.has(item_id):
		return {"ok": false, "message": "Vendor does not sell %s." % item_id}
	var item_def := ContentRegistry.get_definition("items", item_id)
	if item_def.is_empty():
		return {"ok": false, "message": "Missing item definition."}
	var unit_price := int(item_def.get("price", vendor_def.get("price", 0)))
	var total_price := maxi(quantity, 1) * unit_price
	var resources: Dictionary = data.get("resources", {})
	var gold := int(resources.get("gold", 0))
	if gold < total_price:
		return {"ok": false, "message": "Not enough gold to buy %s." % String(item_def.get("name", item_id))}
	resources["gold"] = gold - total_price
	data["resources"] = resources
	SaveService.save_slot(slot, data)
	SaveService.add_inventory_item(slot, item_id, maxi(quantity, 1))
	return {
		"ok": true,
		"message": "Bought %s x%d." % [String(item_def.get("name", item_id)), maxi(quantity, 1)]
	}

func _stable_hash(text: String) -> int:
	var hash := 5381
	for code in text.to_utf8_buffer():
		hash = int(((hash << 5) + hash) + int(code))
	return abs(hash)

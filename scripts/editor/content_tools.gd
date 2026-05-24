@tool
extends RefCounted

const MANIFEST_PATH := "res://data/source_json/content_manifest.json"
const IMPORTED_MANIFEST_PATH := "res://data/imported/content_build_manifest.json"
const IMPORTED_MAPS_DIR := "res://data/imported/maps"
const EDITABLE_KINDS := ["monsters", "skills", "items", "quests"]

static func manifest() -> Dictionary:
	return _load_json_dict(MANIFEST_PATH)

static func definition_paths() -> Dictionary:
	return manifest().get("definitions", {})

static func definition_kinds() -> Array[String]:
	var result: Array[String] = []
	for kind in definition_paths().keys():
		result.append(String(kind))
	result.sort()
	return result

static func list_map_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in manifest().get("maps", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		result.append((entry as Dictionary).duplicate(true))
	return result

static func map_entry(map_id: String) -> Dictionary:
	for entry in list_map_entries():
		if String(entry.get("id", "")) == map_id:
			return entry
	return {}

static func load_map_data(map_id: String) -> Dictionary:
	var entry := map_entry(map_id)
	if entry.is_empty():
		return {}
	return _load_json_dict(String(entry.get("path", "")))

static func save_map_data(map_id: String, new_data: Dictionary) -> Dictionary:
	var entry := map_entry(map_id)
	if entry.is_empty():
		return {"ok": false, "errors": ["Missing map %s." % map_id]}
	var maps := _load_manifest_maps()
	maps[map_id] = new_data
	var validation := _validate_maps_dictionary(maps)
	if not bool(validation.get("ok", false)):
		return validation
	var file := FileAccess.open(String(entry.get("path", "")), FileAccess.WRITE)
	file.store_string(JSON.stringify(new_data, "\t"))
	return {"ok": true, "errors": []}

static func list_map_placements(map_id: String) -> Array[Dictionary]:
	var map_data := load_map_data(map_id)
	var result: Array[Dictionary] = []
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		result.append((placement as Dictionary).duplicate(true))
	return result

static func load_definitions() -> Dictionary:
	var result := {}
	var paths := definition_paths()
	for kind in paths.keys():
		result[String(kind)] = _load_json_rows(String(paths.get(kind, "")))
	return result

static func validate_definitions(definitions: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var monsters_by_id := {}
	var items_by_id := {}
	var events_by_id := {}
	var vendors_by_id := {}
	var skills_by_id := {}
	var quests_by_id := {}
	var quest_seed_ids := {}
	for kind in definition_kinds():
		var seen := {}
		for row in definitions.get(kind, []):
			if typeof(row) != TYPE_DICTIONARY:
				errors.append("%s row is not a dictionary." % kind)
				continue
			var row_id := String(row.get("id", ""))
			if row_id == "":
				errors.append("%s row has empty id." % kind)
				continue
			if seen.has(row_id):
				errors.append("%s row duplicates id %s." % [kind, row_id])
			seen[row_id] = true
			if kind == "monsters":
				monsters_by_id[row_id] = row
			elif kind == "items":
				items_by_id[row_id] = row
			elif kind == "events":
				events_by_id[row_id] = row
			elif kind == "vendors":
				vendors_by_id[row_id] = row
			elif kind == "skills":
				skills_by_id[row_id] = row
			elif kind == "quests":
				quests_by_id[row_id] = row
	for quest in definitions.get("quests", []):
		var target := String(quest.get("targetMonsterId", ""))
		if target != "" and not monsters_by_id.has(target):
			errors.append("quest %s points to missing monster %s." % [quest.get("id", ""), target])
		var reward_item := String(quest.get("rewardItemId", ""))
		if reward_item != "" and not items_by_id.has(reward_item):
			errors.append("quest %s rewardItemId points to missing item %s." % [quest.get("id", ""), reward_item])
	for encounter in definitions.get("encounters", []):
		for enemy in encounter.get("enemies", []):
			if typeof(enemy) != TYPE_DICTIONARY:
				continue
			var monster_id := String(enemy.get("monsterId", ""))
			if monster_id != "" and not monsters_by_id.has(monster_id):
				errors.append("encounter %s points to missing monster %s." % [encounter.get("id", ""), monster_id])
	for vendor in definitions.get("vendors", []):
		for item_id in vendor.get("itemIds", []):
			if String(item_id) != "" and not items_by_id.has(String(item_id)):
				errors.append("vendor %s itemIds points to missing item %s." % [vendor.get("id", ""), item_id])
		for skill_id in vendor.get("skillIds", []):
			if String(skill_id) != "" and not skills_by_id.has(String(skill_id)):
				errors.append("vendor %s skillIds points to missing skill %s." % [vendor.get("id", ""), skill_id])
	for npc in definitions.get("npcs", []):
		for quest_seed in npc.get("questSeeds", []):
			if typeof(quest_seed) != TYPE_DICTIONARY:
				continue
			var quest_seed_id := String(quest_seed.get("id", ""))
			if quest_seed_id != "":
				quest_seed_ids[quest_seed_id] = true
	for npc in definitions.get("npcs", []):
		for service in npc.get("services", []):
			if typeof(service) != TYPE_DICTIONARY:
				continue
			var vendor_id := String(service.get("vendorId", ""))
			if vendor_id != "" and not vendors_by_id.has(vendor_id):
				errors.append("npc %s points to missing vendor %s." % [npc.get("id", ""), vendor_id])
			for skill_id in service.get("skillIds", []):
				if String(skill_id) != "" and not skills_by_id.has(String(skill_id)):
					errors.append("npc %s service skillIds points to missing skill %s." % [npc.get("id", ""), skill_id])
			var reward_items: Array = service.get("inventory", [])
			for item_id in reward_items:
				if String(item_id) != "" and not items_by_id.has(String(item_id)):
					errors.append("npc %s service inventory points to missing item %s." % [npc.get("id", ""), item_id])
			var opens_service: Dictionary = service.get("opensService", {})
			if not opens_service.is_empty():
				_validate_npc_opens_service(errors, String(npc.get("id", "")), opens_service, vendors_by_id, skills_by_id, items_by_id)
			var dialogue: Dictionary = service.get("dialogue", {})
			if not dialogue.is_empty():
				_validate_event_like_graph(errors, "npc %s service dialogue" % npc.get("id", ""), dialogue, items_by_id, quest_seed_ids)
			var fight_encounter_id := String(service.get("encounterId", ""))
			if fight_encounter_id != "" and _find_definition_row("encounters", fight_encounter_id).is_empty():
				errors.append("npc %s service points to missing encounter %s." % [npc.get("id", ""), fight_encounter_id])
		for quest_seed in npc.get("questSeeds", []):
			if typeof(quest_seed) != TYPE_DICTIONARY:
				continue
			var quest_seed_id := String(quest_seed.get("id", ""))
			var complete_event := String(quest_seed.get("completeEventId", ""))
			if complete_event != "" and not events_by_id.has(complete_event):
				errors.append("npc %s quest seed points to missing event %s." % [npc.get("id", ""), complete_event])
			var rewards: Dictionary = quest_seed.get("rewards", {})
			for reward_item in rewards.get("items", []):
				if typeof(reward_item) != TYPE_DICTIONARY:
					continue
				var reward_item_id := String(reward_item.get("itemId", ""))
				if reward_item_id != "" and not items_by_id.has(reward_item_id):
					errors.append("npc %s quest seed %s reward points to missing item %s." % [npc.get("id", ""), quest_seed_id, reward_item_id])
	for event in definitions.get("events", []):
		_validate_event_like_graph(errors, "event %s" % event.get("id", ""), event, items_by_id, quest_seed_ids)
	for loot_table in definitions.get("loot_tables", []):
		for item_id in _collect_item_ids(loot_table):
			if not items_by_id.has(item_id):
				errors.append("loot table %s points to missing item %s." % [loot_table.get("id", ""), item_id])
	return {
		"ok": errors.is_empty(),
		"errors": errors
	}

static func _validate_npc_opens_service(errors: Array[String], npc_id: String, opens_service: Dictionary, vendors_by_id: Dictionary, skills_by_id: Dictionary, items_by_id: Dictionary) -> void:
	var service_id := String(opens_service.get("serviceId", ""))
	if service_id == "":
		errors.append("npc %s opensService is missing serviceId." % npc_id)
	var vendor_id := String(opens_service.get("vendorId", ""))
	if vendor_id != "" and not vendors_by_id.has(vendor_id):
		errors.append("npc %s opensService points to missing vendor %s." % [npc_id, vendor_id])
	for skill_id in opens_service.get("skillIds", []):
		if String(skill_id) != "" and not skills_by_id.has(String(skill_id)):
			errors.append("npc %s opensService skillIds points to missing skill %s." % [npc_id, skill_id])
	for item_id in opens_service.get("itemIds", []):
		if String(item_id) != "" and not items_by_id.has(String(item_id)):
			errors.append("npc %s opensService itemIds points to missing item %s." % [npc_id, item_id])

static func _validate_event_like_graph(errors: Array[String], label: String, event_row: Dictionary, items_by_id: Dictionary, quest_seed_ids: Dictionary) -> void:
	var step_ids := {}
	for step in event_row.get("steps", []):
		if typeof(step) != TYPE_DICTIONARY:
			errors.append("%s has non-dictionary step." % label)
			continue
		var step_id := String(step.get("id", ""))
		if step_id == "":
			errors.append("%s has step with empty id." % label)
			continue
		if step_ids.has(step_id):
			errors.append("%s duplicates step id %s." % [label, step_id])
		step_ids[step_id] = true
	var entry_step_id := String(event_row.get("entryStepId", ""))
	if entry_step_id != "" and not step_ids.has(entry_step_id):
		errors.append("%s has broken entryStepId %s." % [label, entry_step_id])
	for effect in event_row.get("effects", []):
		if typeof(effect) == TYPE_DICTIONARY:
			_validate_event_effect(errors, label, effect, items_by_id, quest_seed_ids)
	for step in event_row.get("steps", []):
		if typeof(step) != TYPE_DICTIONARY:
			continue
		for effect in step.get("effects", []):
			if typeof(effect) == TYPE_DICTIONARY:
				_validate_event_effect(errors, "%s step %s" % [label, step.get("id", "")], effect, items_by_id, quest_seed_ids)
		for choice in step.get("choices", []):
			if typeof(choice) != TYPE_DICTIONARY:
				errors.append("%s step %s has non-dictionary choice." % [label, step.get("id", "")])
				continue
			var next_step_id := String(choice.get("nextStepId", ""))
			if next_step_id != "" and not step_ids.has(next_step_id):
				errors.append("%s step %s choice points to missing nextStepId %s." % [label, step.get("id", ""), next_step_id])
			var required_seed_id := String(choice.get("requiredQuestSeedId", ""))
			if required_seed_id != "" and not quest_seed_ids.has(required_seed_id):
				errors.append("%s step %s choice requires missing quest seed %s." % [label, step.get("id", ""), required_seed_id])
			for effect in choice.get("effects", []):
				if typeof(effect) == TYPE_DICTIONARY:
					_validate_event_effect(errors, "%s step %s choice" % [label, step.get("id", "")], effect, items_by_id, quest_seed_ids)

static func _validate_event_effect(errors: Array[String], label: String, effect: Dictionary, items_by_id: Dictionary, quest_seed_ids: Dictionary) -> void:
	var kind := String(effect.get("kind", ""))
	if kind == "":
		errors.append("%s has effect with empty kind." % label)
	if kind == "grant_item":
		var item_id := String(effect.get("itemId", ""))
		if item_id == "" or not items_by_id.has(item_id):
			errors.append("%s grant_item points to missing item %s." % [label, item_id])
	if kind == "set_quest_seed_state":
		var quest_seed_id := String(effect.get("questSeedId", ""))
		if quest_seed_id == "" or not quest_seed_ids.has(quest_seed_id):
			errors.append("%s set_quest_seed_state points to missing quest seed %s." % [label, quest_seed_id])

static func validate_maps() -> Dictionary:
	return _validate_maps_dictionary(_load_manifest_maps())

static func validate_maps_dictionary_for_tests(maps: Dictionary) -> Dictionary:
	return _validate_maps_dictionary(maps)

static func save_map_placement(map_id: String, placement_id: String, new_data: Dictionary) -> Dictionary:
	var entry := map_entry(map_id)
	if entry.is_empty():
		return {"ok": false, "errors": ["Missing map %s." % map_id]}
	var maps := _load_manifest_maps()
	if not maps.has(map_id):
		return {"ok": false, "errors": ["Missing map data for %s." % map_id]}
	var map_data: Dictionary = (maps[map_id] as Dictionary).duplicate(true)
	var placements: Array = map_data.get("placements", []).duplicate(true)
	var replaced := false
	for index in range(placements.size()):
		var placement: Dictionary = placements[index]
		if String(placement.get("id", "")) != placement_id:
			continue
		placements[index] = new_data
		replaced = true
		break
	if not replaced:
		placements.append(new_data)
	map_data["placements"] = placements
	maps[map_id] = map_data
	var validation := _validate_maps_dictionary(maps)
	if not bool(validation.get("ok", false)):
		return validation
	var file := FileAccess.open(String(entry.get("path", "")), FileAccess.WRITE)
	file.store_string(JSON.stringify(map_data, "\t"))
	return {"ok": true, "errors": []}

static func _load_manifest_maps() -> Dictionary:
	var maps: Dictionary = {}
	for entry in manifest().get("maps", []):
		var map_id := String(entry.get("id", ""))
		var path := String(entry.get("path", ""))
		var map_data := _load_json_dict(path)
		if map_id == "" or path == "" or map_data.is_empty():
			continue
		maps[map_id] = map_data
	return maps

static func _validate_maps_dictionary(maps: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var chunk_index := _definition_index("map_chunks")
	var profile_index := _definition_index("map_profiles")
	var object_theme_index := _definition_index("object_themes")
	var material_index := _definition_index("materials")
	for entry in manifest().get("maps", []):
		var map_id := String(entry.get("id", ""))
		var path := String(entry.get("path", ""))
		var map_data: Dictionary = maps.get(map_id, {})
		if map_id == "" or path == "" or map_data.is_empty():
			errors.append("map entry is missing id/path or file content.")
			continue
		var start: Array = map_data.get("start", [])
		var cells: Array = map_data.get("cells", [])
		if start.size() != 2 or cells.is_empty():
			errors.append("map %s has invalid start/cells." % map_id)
			continue
		var width := String(cells[0]).length()
		if width <= 0:
			errors.append("map %s has empty cell row width." % map_id)
			continue
		for row_index in range(cells.size()):
			var row_text := String(cells[row_index])
			if row_text.length() != width:
				errors.append("map %s row %d width %d does not match %d." % [map_id, row_index, row_text.length(), width])
			for token in row_text:
				if token not in [".", "#"]:
					errors.append("map %s row %d has unsupported cell token %s." % [map_id, row_index, token])
		if int(start[0]) < 0 or int(start[1]) < 0 or int(start[1]) >= cells.size() or int(start[0]) >= width:
			errors.append("map %s start is out of bounds." % map_id)
		elif String(cells[int(start[1])])[int(start[0])] == "#":
			errors.append("map %s start points to blocked cell." % map_id)
		var map_profile_id := String(map_data.get("mapProfileId", ""))
		if map_profile_id != "" and not profile_index.has(map_profile_id):
			errors.append("map %s points to missing map profile %s." % [map_id, map_profile_id])
		var object_theme_id := String(map_data.get("objectThemeId", ""))
		if object_theme_id != "" and not object_theme_index.has(object_theme_id):
			errors.append("map %s points to missing object theme %s." % [map_id, object_theme_id])
		for material_key in ["wallMaterialId", "ceilingMaterialId", "defaultFloorMaterialId"]:
			var material_id := String(map_data.get(material_key, ""))
			if material_id != "" and not material_index.has(material_id):
				errors.append("map %s points to missing material %s via %s." % [map_id, material_id, material_key])
		for chunk_id in map_data.get("sourceChunkIds", []):
			if String(chunk_id) != "" and not chunk_index.has(String(chunk_id)):
				errors.append("map %s points to missing source chunk %s." % [map_id, chunk_id])
	for map_id in maps.keys():
		var placement_map: Dictionary = maps[map_id]
		var placement_cells: Array = placement_map.get("cells", [])
		var placement_width := String(placement_cells[0]).length() if not placement_cells.is_empty() else 0
		for placement in maps[map_id].get("placements", []):
			var target_map_id := String(placement.get("targetMapId", ""))
			if target_map_id != "" and not maps.has(target_map_id):
				errors.append("map %s placement %s points to missing target map %s." % [map_id, placement.get("id", ""), target_map_id])
			var npc_id := String(placement.get("npcId", ""))
			if npc_id != "" and _find_definition_row("npcs", npc_id).is_empty():
				errors.append("map %s placement %s points to missing npc %s." % [map_id, placement.get("id", ""), npc_id])
			var event_id := String(placement.get("eventId", ""))
			if event_id != "" and _find_definition_row("events", event_id).is_empty():
				errors.append("map %s placement %s points to missing event %s." % [map_id, placement.get("id", ""), event_id])
			var loot_table_id := String(placement.get("lootTableId", ""))
			if loot_table_id != "" and _find_definition_row("loot_tables", loot_table_id).is_empty():
				errors.append("map %s placement %s points to missing loot table %s." % [map_id, placement.get("id", ""), loot_table_id])
			var field_ai: Dictionary = placement.get("fieldAi", {})
			if not field_ai.is_empty():
				for ai_key in ["approachRange", "chaseRange", "leashRange"]:
					if not field_ai.has(ai_key):
						errors.append("map %s placement %s fieldAi is missing %s." % [map_id, placement.get("id", ""), ai_key])
						continue
					var ai_value := int(field_ai.get(ai_key, -1))
					if ai_value < 0:
						errors.append("map %s placement %s fieldAi %s must be >= 0." % [map_id, placement.get("id", ""), ai_key])
				var hearing_range := int(field_ai.get("hearingRange", 1))
				if hearing_range < 0:
					errors.append("map %s placement %s fieldAi hearingRange must be >= 0." % [map_id, placement.get("id", "")])
				var behavior := String(field_ai.get("behavior", "guard"))
				if behavior not in ["guard", "patrol", "ambush"]:
					errors.append("map %s placement %s fieldAi behavior %s is unsupported." % [map_id, placement.get("id", ""), behavior])
				var warning_turns := int(field_ai.get("warningTurns", 0))
				if warning_turns < 0:
					errors.append("map %s placement %s fieldAi warningTurns must be >= 0." % [map_id, placement.get("id", "")])
				var wake_range := int(field_ai.get("wakeRange", 0))
				if wake_range < 0:
					errors.append("map %s placement %s fieldAi wakeRange must be >= 0." % [map_id, placement.get("id", "")])
				var lose_sight_turns := int(field_ai.get("loseSightTurns", 1))
				if lose_sight_turns < 0:
					errors.append("map %s placement %s fieldAi loseSightTurns must be >= 0." % [map_id, placement.get("id", "")])
				var alert_radius := int(field_ai.get("alertRadius", 0))
				if alert_radius < 0:
					errors.append("map %s placement %s fieldAi alertRadius must be >= 0." % [map_id, placement.get("id", "")])
				var patrol_points: Array = field_ai.get("patrolPoints", [])
				for patrol_index in range(patrol_points.size()):
					var patrol_point: Variant = patrol_points[patrol_index]
					if typeof(patrol_point) != TYPE_ARRAY or (patrol_point as Array).size() != 2:
						errors.append("map %s placement %s fieldAi patrolPoints[%d] must be [x, y]." % [map_id, placement.get("id", ""), patrol_index])
						continue
					var point: Array = patrol_point
					var patrol_x := int(point[0])
					var patrol_y := int(point[1])
					if patrol_y < 0 or patrol_y >= placement_cells.size() or patrol_x < 0 or patrol_x >= placement_width:
						errors.append("map %s placement %s fieldAi patrol point %d is out of bounds." % [map_id, placement.get("id", ""), patrol_index])
						continue
					if String(placement_cells[patrol_y])[patrol_x] == "#":
						errors.append("map %s placement %s fieldAi patrol point %d is blocked." % [map_id, placement.get("id", ""), patrol_index])
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"mapCount": maps.size()
	}

static func build_compiled_map_preview(map_id: String = "dungeon_floor_01") -> Dictionary:
	var manifest_maps: Array = manifest().get("maps", [])
	var map_data: Dictionary = {}
	for entry in manifest_maps:
		if String(entry.get("id", "")) == map_id:
			map_data = _load_json_dict(String(entry.get("path", "")))
			break
	if map_data.is_empty():
		return {"ok": false, "errors": ["Missing map %s." % map_id]}
	var profile := _find_definition_row("map_profiles", String(map_data.get("mapProfileId", "")))
	var chunks_by_id := _definition_index("map_chunks")
	var chunk_ids: Array = map_data.get("sourceChunkIds", [])
	var chunk_rows: Array[Dictionary] = []
	var errors: Array[String] = []
	for chunk_id in chunk_ids:
		var row: Dictionary = chunks_by_id.get(String(chunk_id), {})
		if row.is_empty():
			errors.append("Missing source chunk %s for %s." % [chunk_id, map_id])
			continue
		chunk_rows.append(row)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var width := maxi(int(ceil(sqrt(float(max(chunk_rows.size(), 1))))), 1)
	var chunk_grid_height := maxi(int(ceil(float(chunk_rows.size()) / float(width))), 1)
	var room_size: Dictionary = profile.get("gridRoomSize", {"width": 7, "height": 7})
	var chunk_cell_width := maxi(int(room_size.get("width", 7)), 1)
	var chunk_cell_height := maxi(int(room_size.get("height", 7)), 1)
	var preview_rows: Array[String] = []
	var chunk_layout: Array[Dictionary] = []
	var anchor_layout: Array[Dictionary] = []
	for row_index in range(int(ceil(float(chunk_rows.size()) / float(width)))):
		var tokens: Array[String] = []
		for col_index in range(width):
			var index := row_index * width + col_index
			if index >= chunk_rows.size():
				tokens.append("....")
				continue
			var chunk: Dictionary = chunk_rows[index]
			var open_sides: Array = chunk.get("openSides", [])
			var side_token := ""
			for side in open_sides.slice(0, mini(open_sides.size(), 2)):
				side_token += String(side).substr(0, 1).to_upper()
			var chunk_token := "%s%s" % [
				String(chunk.get("presetId", "??")).substr(0, 2).to_upper(),
				side_token
			]
			tokens.append(chunk_token)
			var cell_origin_x := col_index * chunk_cell_width
			var cell_origin_y := row_index * chunk_cell_height
			var layout_entry := {
				"id": String(chunk.get("id", "")),
				"presetId": String(chunk.get("presetId", "")),
				"layoutPos": [col_index, row_index],
				"cellRect": {
					"x": cell_origin_x,
					"y": cell_origin_y,
					"width": int(chunk.get("size", {}).get("width", chunk_cell_width)),
					"height": int(chunk.get("size", {}).get("height", chunk_cell_height))
				},
				"openSides": chunk.get("openSides", []),
				"doorSockets": chunk.get("doorSockets", []),
				"roleTags": chunk.get("roleTags", [])
			}
			chunk_layout.append(layout_entry)
			for anchor in chunk.get("anchors", []):
				if typeof(anchor) != TYPE_DICTIONARY:
					continue
				anchor_layout.append({
					"chunkId": String(chunk.get("id", "")),
					"id": String(anchor.get("id", "")),
					"kind": String(anchor.get("kind", "")),
					"x": cell_origin_x + int(anchor.get("x", 0)),
					"y": cell_origin_y + int(anchor.get("y", 0))
				})
		preview_rows.append(" ".join(tokens))
	var preview := {
		"ok": true,
		"mapId": map_id,
		"profileId": String(profile.get("id", map_data.get("mapProfileId", ""))),
		"profileName": String(profile.get("name", map_data.get("mapProfileId", ""))),
		"theme": String(map_data.get("themeId", profile.get("theme", ""))),
		"layout": profile.get("layout", {}),
		"chunkGrid": {
			"width": width,
			"height": chunk_grid_height,
			"cellWidth": chunk_cell_width,
			"cellHeight": chunk_cell_height
		},
		"targetModuleCount": int(profile.get("targetModuleCount", chunk_rows.size())),
		"sourceChunkIds": chunk_ids,
		"chunkSummaries": [],
		"chunkLayout": chunk_layout,
		"anchorLayout": anchor_layout,
		"previewRows": preview_rows
	}
	var generated_assembly := _build_generated_assembly(preview, map_data)
	preview["generatedCells"] = generated_assembly.get("cells", [])
	preview["generatedPlacements"] = generated_assembly.get("placements", [])
	preview["generatedStart"] = generated_assembly.get("start", map_data.get("start", [1, 1]))
	for chunk in chunk_rows:
		preview["chunkSummaries"].append({
			"id": String(chunk.get("id", "")),
			"presetId": String(chunk.get("presetId", "")),
			"openSides": chunk.get("openSides", []),
			"doorSockets": chunk.get("doorSockets", []),
			"roleTags": chunk.get("roleTags", [])
		})
	return preview

static func export_compiled_map_preview(map_id: String = "dungeon_floor_01", output_path: String = "") -> Dictionary:
	var preview := build_compiled_map_preview(map_id)
	if not bool(preview.get("ok", false)):
		return preview
	var final_output_path := output_path if output_path != "" else "res://output/%s_chunk_preview.json" % map_id
	if final_output_path != "":
		var file := FileAccess.open(final_output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(preview, "\t"))
			preview["outputPath"] = final_output_path
	return preview

static func save_definition_row(kind: String, row_id: String, new_data: Dictionary) -> Dictionary:
	var definitions := load_definitions()
	var rows: Array = definitions.get(kind, [])
	var replaced := false
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		if String(row.get("id", "")) == row_id:
			rows[index] = new_data
			replaced = true
			break
	if not replaced:
		rows.append(new_data)
	definitions[kind] = rows
	var validation := validate_definitions(definitions)
	if not validation["ok"]:
		return validation
	var paths := definition_paths()
	var path := String(paths.get(kind, ""))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	return {"ok": true, "errors": []}

static func export_manifest_report(output_path: String = "res://output/editor_manifest_report.json") -> Dictionary:
	var definitions := load_definitions()
	var validation := validate_definitions(definitions)
	var map_validation := validate_maps()
	var report := {
		"contentVersion": int(manifest().get("contentVersion", 0)),
		"validation": validation,
		"mapValidation": map_validation,
		"counts": {}
	}
	for kind in definition_kinds():
		report["counts"][kind] = definitions.get(kind, []).size()
	if output_path != "":
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
	return report

static func export_build_bundle() -> Dictionary:
	var definition_validation := validate_definitions(load_definitions())
	var map_validation := validate_maps()
	var errors: Array[String] = []
	errors.append_array(definition_validation.get("errors", []))
	errors.append_array(map_validation.get("errors", []))
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMPORTED_MAPS_DIR))
	var compiled_maps: Array = []
	for entry in manifest().get("maps", []):
		var map_id := String(entry.get("id", ""))
		var source_path := String(entry.get("path", ""))
		var map_data := _load_json_dict(source_path)
		var preview := build_compiled_map_preview(map_id)
		if bool(preview.get("ok", false)):
			map_data["compiledPreview"] = preview
		map_data["compiledFrom"] = source_path
		var target_path := "%s/%s.json" % [IMPORTED_MAPS_DIR, map_id]
		var map_file := FileAccess.open(target_path, FileAccess.WRITE)
		map_file.store_string(JSON.stringify(map_data, "\t"))
		compiled_maps.append({
			"id": map_id,
			"path": target_path,
			"sourcePath": source_path,
			"sourceHash": _file_content_hash(source_path),
			"kind": String(entry.get("kind", map_data.get("kind", "")))
		})
	var build_manifest := {
		"id": "%s-build" % manifest().get("id", "connan"),
		"buildVersion": Time.get_datetime_string_from_system(),
		"contentVersion": int(manifest().get("contentVersion", 0)),
		"definitions": definition_paths(),
		"compiledMaps": compiled_maps
	}
	var build_file := FileAccess.open(IMPORTED_MANIFEST_PATH, FileAccess.WRITE)
	build_file.store_string(JSON.stringify(build_manifest, "\t"))
	return {
		"ok": true,
		"errors": [],
		"compiledMaps": compiled_maps.size(),
		"manifestPath": IMPORTED_MANIFEST_PATH
	}

static func _load_json_dict(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func _file_content_hash(path: String) -> int:
	if path == "" or not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	return file.get_as_text().hash()

static func _load_json_array(path: String) -> Array:
	if path == "" or not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		var rows_from_array: Array = []
		for index in range(parsed.size()):
			var row: Variant = parsed[index]
			if typeof(row) != TYPE_DICTIONARY:
				continue
			rows_from_array.append(_normalize_row(row, str(index)))
		return rows_from_array
	if typeof(parsed) == TYPE_DICTIONARY:
		var rows: Array = []
		for key in parsed.keys():
			var row: Variant = parsed[key]
			if typeof(row) != TYPE_DICTIONARY:
				continue
			rows.append(_normalize_row(row, String(key)))
		return rows
	return []

static func _load_json_rows(path: String) -> Array:
	return _load_json_array(path)

static func _find_definition_row(kind: String, row_id: String) -> Dictionary:
	for row in _load_json_rows(String(definition_paths().get(kind, ""))):
		if typeof(row) == TYPE_DICTIONARY and String(row.get("id", "")) == row_id:
			return row
	return {}

static func _definition_index(kind: String) -> Dictionary:
	var result := {}
	for row in _load_json_rows(String(definition_paths().get(kind, ""))):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		result[String(row.get("id", ""))] = row
	return result

static func _build_generated_assembly(preview: Dictionary, map_data: Dictionary) -> Dictionary:
	var layout: Dictionary = preview.get("layout", {})
	var width := maxi(int(layout.get("width", map_data.get("size", [8, 8])[0])), 5)
	var height := maxi(int(layout.get("height", map_data.get("size", [8, 8])[1])), 5)
	var grid: Array = []
	for _y in range(height):
		var chars: Array[String] = []
		for _x in range(width):
			chars.append("#")
		grid.append(chars)
	var chunk_by_pos := {}
	for entry in preview.get("chunkLayout", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rect: Dictionary = entry.get("cellRect", {})
		var left := int(rect.get("x", 0))
		var top := int(rect.get("y", 0))
		var rect_width := maxi(int(rect.get("width", 1)), 1)
		var rect_height := maxi(int(rect.get("height", 1)), 1)
		for y in range(top + 1, mini(top + rect_height - 1, height - 1)):
			for x in range(left + 1, mini(left + rect_width - 1, width - 1)):
				grid[y][x] = "."
		var layout_pos: Array = entry.get("layoutPos", [0, 0])
		chunk_by_pos["%d,%d" % [int(layout_pos[0]), int(layout_pos[1])]] = entry
	for key in chunk_by_pos.keys():
		var chunk: Dictionary = chunk_by_pos[key]
		var layout_pos: Array = chunk.get("layoutPos", [0, 0])
		var gx := int(layout_pos[0])
		var gy := int(layout_pos[1])
		var rect: Dictionary = chunk.get("cellRect", {})
		var center_x := int(rect.get("x", 0)) + maxi(int(rect.get("width", 1)) / 2, 1)
		var center_y := int(rect.get("y", 0)) + maxi(int(rect.get("height", 1)) / 2, 1)
		if chunk.get("openSides", []).has("east"):
			var neighbor: Dictionary = chunk_by_pos.get("%d,%d" % [gx + 1, gy], {})
			if not neighbor.is_empty() and neighbor.get("openSides", []).has("west"):
				var target_rect: Dictionary = neighbor.get("cellRect", {})
				var target_x := int(target_rect.get("x", 0)) + maxi(int(target_rect.get("width", 1)) / 2, 1)
				for x in range(min(center_x, target_x), maxi(center_x, target_x) + 1):
					if center_y >= 0 and center_y < height and x >= 0 and x < width:
						grid[center_y][x] = "."
		if chunk.get("openSides", []).has("south"):
			var neighbor_down: Dictionary = chunk_by_pos.get("%d,%d" % [gx, gy + 1], {})
			if not neighbor_down.is_empty() and neighbor_down.get("openSides", []).has("north"):
				var target_rect_down: Dictionary = neighbor_down.get("cellRect", {})
				var target_y := int(target_rect_down.get("y", 0)) + maxi(int(target_rect_down.get("height", 1)) / 2, 1)
				for y in range(min(center_y, target_y), maxi(center_y, target_y) + 1):
					if y >= 0 and y < height and center_x >= 0 and center_x < width:
						grid[y][center_x] = "."
	var placements: Array[Dictionary] = []
	for anchor in preview.get("anchorLayout", []):
		if typeof(anchor) != TYPE_DICTIONARY:
			continue
		var anchor_kind := String(anchor.get("kind", ""))
		var placement := _generated_placement_for_anchor(anchor_kind, anchor)
		if not placement.is_empty():
			placements.append(placement)
	var generated_center_keys := {}
	for placement in placements:
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var pos: Array = placement.get("position", [0, 0])
		generated_center_keys["%d,%d" % [int(pos[0]), int(pos[1])]] = true
	for entry in preview.get("chunkLayout", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rect: Dictionary = entry.get("cellRect", {})
		var center_x := int(rect.get("x", 0)) + maxi(int(rect.get("width", 1)) / 2, 1)
		var center_y := int(rect.get("y", 0)) + maxi(int(rect.get("height", 1)) / 2, 1)
		var center_key := "%d,%d" % [center_x, center_y]
		if generated_center_keys.has(center_key):
			continue
		var role_tags: Array = entry.get("roleTags", [])
		var generated := _generated_placement_for_role_tags(role_tags, entry, center_x, center_y)
		if not generated.is_empty():
			placements.append(generated)
			generated_center_keys[center_key] = true
	if not preview.get("chunkLayout", []).is_empty():
		var start_chunk: Dictionary = preview.get("chunkLayout", [])[0]
		var start_rect: Dictionary = start_chunk.get("cellRect", {})
		var stairs_x := mini(int(start_rect.get("x", 0)) + 1, width - 2)
		var stairs_y := mini(int(start_rect.get("y", 0)) + 1, height - 2)
		placements.append({
			"id": "generated_%s_exit" % String(start_chunk.get("id", "chunk")),
			"type": "stairs",
			"label": "Generated Return Stairs",
			"position": [stairs_x, stairs_y],
			"targetRoute": "town",
			"targetMapId": "town_square"
		})
	var start: Array = map_data.get("start", [1, 1])
	if not preview.get("chunkLayout", []).is_empty():
		var first_chunk: Dictionary = preview.get("chunkLayout", [])[0]
		var first_rect: Dictionary = first_chunk.get("cellRect", {})
		start = [
			mini(int(first_rect.get("x", 0)) + 2, width - 2),
			mini(int(first_rect.get("y", 0)) + maxi(int(first_rect.get("height", 1)) - 2, 1), height - 2)
		]
	var cell_rows: Array[String] = []
	for row in grid:
		var row_text := ""
		for token in row:
			row_text += token
		cell_rows.append(row_text)
	return {
		"cells": cell_rows,
		"placements": placements,
		"start": start
	}

static func _generated_placement_for_anchor(anchor_kind: String, anchor: Dictionary) -> Dictionary:
	var x := int(anchor.get("x", 0))
	var y := int(anchor.get("y", 0))
	var alert_group := "generated_%s_group" % String(anchor.get("id", anchor_kind))
	match anchor_kind:
		"loot":
			return {
				"id": "generated_%s" % String(anchor.get("id", "loot")),
				"type": "loot",
				"label": "Generated Loot Cache",
				"position": [x, y],
				"lootTableId": "loot_dungeon_satchel",
				"itemId": "healing_tonic"
			}
		"boss_spawn", "encounter":
			return {
				"id": "generated_%s" % String(anchor.get("id", "encounter")),
				"type": "field_monster",
				"label": "Generated Encounter",
				"position": [x, y],
				"encounterId": "encounter_grave_robber",
				"blocking": true,
				"fieldAi": _generated_field_ai("grave_robber", x, y, 5, 2, 6, alert_group)
			}
		"event":
			return {
				"id": "generated_%s" % String(anchor.get("id", "event")),
				"type": "rest",
				"label": "Generated Event Shrine",
				"position": [x, y],
				"eventId": "event_shrine_healing_spring"
			}
		_:
			return {}

static func _generated_placement_for_role_tags(role_tags: Array, entry: Dictionary, x: int, y: int) -> Dictionary:
	if role_tags.has("combat") or role_tags.has("guard"):
		var monster_id := "slime_alpha" if String(entry.get("id", "")) == "rect_hall_ns" else "grave_robber"
		var alert_group := "generated_floor_guard_pair"
		var encounter_id := "encounter_serpent_guard" if monster_id == "slime_alpha" else "encounter_grave_robber"
		return {
			"id": "generated_%s_guard" % String(entry.get("id", "chunk")),
			"type": "field_monster",
			"label": "Generated Guard",
			"position": [x, y],
			"encounterId": encounter_id,
			"monsterId": monster_id,
			"blocking": true,
			"fieldAi": _generated_field_ai(monster_id, x, y, 4, 2, 5, alert_group)
		}
	if role_tags.has("reward") or role_tags.has("side_reward"):
		return {
			"id": "generated_%s_shrine" % String(entry.get("id", "chunk")),
			"type": "rest",
			"label": "Generated Shrine",
			"position": [x, y],
			"eventId": "event_shrine_healing_spring"
		}
	return {}

static func _generated_field_ai(monster_id: String, x: int, y: int, approach_range: int, chase_range: int, leash_range: int, alert_group: String = "") -> Dictionary:
	var config := {
		"behavior": "guard",
		"approachRange": approach_range,
		"chaseRange": chase_range,
		"hearingRange": 1,
		"leashRange": leash_range,
		"alertGroup": alert_group,
		"wakeRange": 0,
		"loseSightTurns": 1,
		"alertRadius": 0,
		"warningTurns": 0,
		"patrolPoints": []
	}
	if monster_id == "slime_alpha":
		config["behavior"] = "patrol"
		config["alertRadius"] = 8
		config["warningTurns"] = 1
		config["patrolPoints"] = [
			[x, y],
			[x + 1, y],
			[x + 1, maxi(y - 1, 1)],
			[x, maxi(y - 1, 1)]
		]
	elif monster_id == "grave_robber":
		config["behavior"] = "ambush"
		config["alertRadius"] = 8
		config["warningTurns"] = 1
		config["wakeRange"] = 2
	return config

static func _normalize_row(row: Variant, fallback_id: String) -> Dictionary:
	var normalized: Dictionary = (row as Dictionary).duplicate(true)
	var row_id := String(normalized.get("id", ""))
	if row_id == "":
		row_id = String(normalized.get("mapId", ""))
	if row_id == "":
		row_id = "floor_%s" % String(normalized.get("floor")) if normalized.has("floor") else fallback_id
	normalized["id"] = row_id
	return normalized

static func _collect_item_ids(value: Variant) -> Array[String]:
	var item_ids: Array[String] = []
	if typeof(value) == TYPE_DICTIONARY:
		var item_id := String((value as Dictionary).get("itemId", ""))
		if item_id != "":
			item_ids.append(item_id)
		for nested in (value as Dictionary).values():
			for nested_item_id in _collect_item_ids(nested):
				if not item_ids.has(nested_item_id):
					item_ids.append(nested_item_id)
	elif typeof(value) == TYPE_ARRAY:
		for nested in value:
			for nested_item_id in _collect_item_ids(nested):
				if not item_ids.has(nested_item_id):
					item_ids.append(nested_item_id)
	return item_ids

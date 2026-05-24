extends SceneTree

const ContentTools = preload("res://scripts/editor/content_tools.gd")

var failures: Array[String] = []
var passed_cases := 0

func _initialize() -> void:
	var definitions := ContentTools.load_definitions()
	var baseline := ContentTools.validate_definitions(definitions)
	_expect(bool(baseline.get("ok", false)), "baseline definitions must be valid before fixture checks")
	_probe_definition_fixtures(definitions)
	var maps := _load_manifest_maps()
	var map_baseline := ContentTools.validate_maps_dictionary_for_tests(maps)
	_expect(bool(map_baseline.get("ok", false)), "baseline maps must be valid before fixture checks")
	_probe_map_fixtures(maps)
	for failure in failures:
		print("VALIDATION_FIXTURE_FAIL %s" % failure)
	var ok := failures.is_empty()
	print("VALIDATION_FIXTURE ok=%s cases=%d" % [str(ok), passed_cases])
	quit(0 if ok else 1)

func _probe_definition_fixtures(definitions: Dictionary) -> void:
	_expect_definition_error(definitions, "broken quest reward item", func(copy: Dictionary) -> void:
		var quests: Array = copy.get("quests", [])
		var quest: Dictionary = quests[0].duplicate(true)
		quest["rewardItemId"] = "missing_fixture_item"
		quests[0] = quest
		copy["quests"] = quests
	, "rewardItemId points to missing item")
	_expect_definition_error(definitions, "broken event entryStepId", func(copy: Dictionary) -> void:
		var events: Array = copy.get("events", [])
		var event: Dictionary = events[0].duplicate(true)
		event["entryStepId"] = "missing_fixture_step"
		events[0] = event
		copy["events"] = events
	, "broken entryStepId")
	_expect_definition_error(definitions, "broken event choice next step", func(copy: Dictionary) -> void:
		var events: Array = copy.get("events", [])
		var event: Dictionary = events[0].duplicate(true)
		var steps: Array = event.get("steps", []).duplicate(true)
		var step: Dictionary = steps[0].duplicate(true)
		var choices: Array = step.get("choices", []).duplicate(true)
		if choices.is_empty():
			choices.append({"label": "fixture"})
		var choice: Dictionary = choices[0].duplicate(true)
		choice["nextStepId"] = "missing_fixture_next"
		choices[0] = choice
		step["choices"] = choices
		steps[0] = step
		event["steps"] = steps
		events[0] = event
		copy["events"] = events
	, "choice points to missing nextStepId")
	_expect_definition_error(definitions, "broken event grant item", func(copy: Dictionary) -> void:
		var events: Array = copy.get("events", [])
		var event: Dictionary = events[0].duplicate(true)
		event["effects"] = [{"kind": "grant_item", "itemId": "missing_fixture_item"}]
		events[0] = event
		copy["events"] = events
	, "grant_item points to missing item")
	_expect_definition_error(definitions, "broken quest seed state ref", func(copy: Dictionary) -> void:
		var events: Array = copy.get("events", [])
		var event: Dictionary = events[0].duplicate(true)
		event["effects"] = [{"kind": "set_quest_seed_state", "questSeedId": "missing_fixture_seed"}]
		events[0] = event
		copy["events"] = events
	, "set_quest_seed_state points to missing quest seed")
	_expect_definition_error(definitions, "broken NPC handoff vendor", func(copy: Dictionary) -> void:
		var npcs: Array = copy.get("npcs", [])
		var npc_index := _first_npc_with_services(npcs)
		var npc: Dictionary = npcs[npc_index].duplicate(true)
		var services: Array = npc.get("services", []).duplicate(true)
		var service: Dictionary = services[0].duplicate(true)
		service["opensService"] = {"serviceId": "fixture_shop", "vendorId": "missing_fixture_vendor"}
		services[0] = service
		npc["services"] = services
		npcs[npc_index] = npc
		copy["npcs"] = npcs
	, "opensService points to missing vendor")
	_expect_definition_error(definitions, "broken vendor skill ref", func(copy: Dictionary) -> void:
		var vendors: Array = copy.get("vendors", [])
		var vendor: Dictionary = vendors[0].duplicate(true)
		vendor["skillIds"] = ["missing_fixture_skill"]
		vendors[0] = vendor
		copy["vendors"] = vendors
	, "skillIds points to missing skill")
	_expect_definition_error(definitions, "broken quest seed reward item", func(copy: Dictionary) -> void:
		var npcs: Array = copy.get("npcs", [])
		var npc_index := _first_npc_with_quest_seed(npcs)
		var npc: Dictionary = npcs[npc_index].duplicate(true)
		var seeds: Array = npc.get("questSeeds", []).duplicate(true)
		var seed: Dictionary = seeds[0].duplicate(true)
		seed["rewards"] = {"items": [{"itemId": "missing_fixture_item"}]}
		seeds[0] = seed
		npc["questSeeds"] = seeds
		npcs[npc_index] = npc
		copy["npcs"] = npcs
	, "quest seed")

func _probe_map_fixtures(maps: Dictionary) -> void:
	_expect_map_error(maps, "broken map material", func(copy: Dictionary) -> void:
		var map_data: Dictionary = copy.get("dungeon_floor_01", {}).duplicate(true)
		map_data["wallMaterialId"] = "missing_fixture_material"
		copy["dungeon_floor_01"] = map_data
	, "points to missing material")
	_expect_map_error(maps, "broken placement npc", func(copy: Dictionary) -> void:
		_mutate_first_placement(copy, "town_square", func(placement: Dictionary) -> void:
			placement["npcId"] = "missing_fixture_npc"
		)
	, "points to missing npc")
	_expect_map_error(maps, "broken placement event", func(copy: Dictionary) -> void:
		_mutate_first_placement(copy, "dungeon_floor_01", func(placement: Dictionary) -> void:
			placement["eventId"] = "missing_fixture_event"
		)
	, "points to missing event")
	_expect_map_error(maps, "broken placement target map", func(copy: Dictionary) -> void:
		_mutate_first_placement(copy, "dungeon_floor_01", func(placement: Dictionary) -> void:
			placement["targetMapId"] = "missing_fixture_map"
		)
	, "points to missing target map")
	_expect_map_error(maps, "invalid fieldAi behavior", func(copy: Dictionary) -> void:
		_mutate_first_placement(copy, "dungeon_floor_01", func(placement: Dictionary) -> void:
			placement["fieldAi"] = {
				"behavior": "teleport",
				"approachRange": 4,
				"chaseRange": 2,
				"leashRange": 5,
				"hearingRange": 1
			}
		)
	, "fieldAi behavior teleport is unsupported")
	_expect_map_error(maps, "invalid fieldAi patrol point", func(copy: Dictionary) -> void:
		_mutate_first_placement(copy, "dungeon_floor_01", func(placement: Dictionary) -> void:
			placement["fieldAi"] = {
				"behavior": "patrol",
				"approachRange": 4,
				"chaseRange": 2,
				"leashRange": 5,
				"hearingRange": 1,
				"patrolPoints": [[999, 999]]
			}
		)
	, "fieldAi patrol point 0 is out of bounds")

func _expect_definition_error(base_definitions: Dictionary, label: String, mutator: Callable, expected: String) -> void:
	var fixture := base_definitions.duplicate(true)
	mutator.call(fixture)
	var result := ContentTools.validate_definitions(fixture)
	_expect_expected_error(label, result, expected)

func _expect_map_error(base_maps: Dictionary, label: String, mutator: Callable, expected: String) -> void:
	var fixture := base_maps.duplicate(true)
	mutator.call(fixture)
	var result := ContentTools.validate_maps_dictionary_for_tests(fixture)
	_expect_expected_error(label, result, expected)

func _expect_expected_error(label: String, result: Dictionary, expected: String) -> void:
	var errors: Array = result.get("errors", [])
	var matched := false
	for error in errors:
		if String(error).contains(expected):
			matched = true
			break
	if bool(result.get("ok", true)) or not matched:
		failures.append("%s did not report expected error containing `%s`; errors=%s" % [label, expected, str(errors)])
	else:
		passed_cases += 1

func _load_manifest_maps() -> Dictionary:
	var maps: Dictionary = {}
	for entry in ContentTools.manifest().get("maps", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var map_id := String(entry.get("id", ""))
		var path := String(entry.get("path", ""))
		if map_id == "" or path == "":
			continue
		var parsed := _read_json_dict(path)
		if not parsed.is_empty():
			maps[map_id] = parsed
	return maps

func _read_json_dict(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _mutate_first_placement(maps: Dictionary, map_id: String, mutator: Callable) -> void:
	var map_data: Dictionary = maps.get(map_id, {}).duplicate(true)
	var placements: Array = map_data.get("placements", []).duplicate(true)
	if placements.is_empty():
		failures.append("fixture map %s has no placements to mutate" % map_id)
		return
	var placement: Dictionary = placements[0].duplicate(true)
	mutator.call(placement)
	placements[0] = placement
	map_data["placements"] = placements
	maps[map_id] = map_data

func _first_npc_with_quest_seed(npcs: Array) -> int:
	for index in range(npcs.size()):
		var npc: Dictionary = npcs[index]
		if not npc.get("questSeeds", []).is_empty():
			return index
	return 0

func _first_npc_with_services(npcs: Array) -> int:
	for index in range(npcs.size()):
		var npc: Dictionary = npcs[index]
		if not npc.get("services", []).is_empty():
			return index
	return 0

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

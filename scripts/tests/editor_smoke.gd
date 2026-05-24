extends SceneTree

const ContentTools = preload("res://scripts/editor/content_tools.gd")
const ContentEditorDockScript = preload("res://addons/connan_editor/docks/content_editor_dock.gd")
const EditorWorkspaceScript = preload("res://scripts/runtime/editor_workspace.gd")
const SKILLS_PATH := "res://data/source_json/skills.json"
const QUESTS_PATH := "res://data/source_json/quests.json"
const FLOOR01_PATH := "res://data/source_json/maps/dungeon_floor_01.json"
const ROUTE_PREVIEW_OUTPUT_PATH := "res://output/editor_route_preview_report.json"
const ROUTE_PREVIEW_IMPORTED_PATH := "res://data/imported/editor_route_preview_report.json"

func _initialize() -> void:
	var skills_backup := _read_text(SKILLS_PATH)
	var quests_backup := _read_text(QUESTS_PATH)
	var floor01_backup := _read_text(FLOOR01_PATH)
	var definitions := ContentTools.load_definitions()
	var validation := ContentTools.validate_definitions(definitions)
	var map_validation := ContentTools.validate_maps()
	var preview := ContentTools.export_compiled_map_preview("dungeon_floor_01")
	var invalid_edit_result := {}
	var valid_edit_result := {}
	var bundle := {}
	var report := {}
	var content_ok := false
	var compiled_map_has_preview := false
	var runtime_skill_power := -1
	var compiled_handoff_ok := false
	var authored_handoff_ok := false
	var invalid_edit_blocked := false
	var invalid_edit_unchanged := false
	var valid_edit_applied := false
	var editor_skill_power := -1
	var edited_skill_power := -1
	var invalid_map_edit_blocked := false
	var invalid_map_edit_unchanged := false
	var valid_map_edit_applied := false
	var runtime_field_ai_approach := -1
	var invalid_map_structure_blocked := false
	var invalid_map_structure_unchanged := false
	var valid_map_structure_applied := false
	var imported_start_x := -1
	var grid_editor_path_ok := false
	var placement_grid_editor_ok := false
	var imported_slime_y := -1
	var placement_create_ok := false
	var placement_delete_ok := false
	var placement_reference_picker_ok := false
	var runtime_rest_event_id := ""
	var runtime_deserter_npc_id := ""
	var placement_affordance_preview_ok := false
	var event_contract_apply_ok := false
	var npc_contract_apply_ok := false
	var imported_event_contract_ok := false
	var imported_npc_contract_ok := false
	var definition_authoring_ok := false
	var editor_dock_root_named_ok := false
	var route_preview_report: Dictionary = {}
	var fallback_workspace_summary_ok := false
	var fallback_workspace_detail_ok := false
	var imported_manifest_flow_ok := false

	var power_slash := _find_row(definitions.get("skills", []), "power_slash")
	if not power_slash.is_empty():
		editor_skill_power = int(power_slash.get("power", 0))
		var invalid_quest := _find_row(definitions.get("quests", []), "slime_cleanup")
		invalid_quest["targetMonsterId"] = "missing_monster"
		invalid_edit_result = ContentTools.save_definition_row("quests", "slime_cleanup", invalid_quest)
		invalid_edit_blocked = not bool(invalid_edit_result.get("ok", false))
		invalid_edit_unchanged = _read_text(QUESTS_PATH) == quests_backup

		var edited_skill := power_slash.duplicate(true)
		edited_skill["power"] = editor_skill_power + 1
		edited_skill["price"] = int(edited_skill.get("price", 0)) + 3
		edited_skill["name"] = "Power Slash+Smoke"
		valid_edit_result = ContentTools.save_definition_row("skills", "power_slash", edited_skill)
		edited_skill_power = int(edited_skill.get("power", 0))
		valid_edit_applied = bool(valid_edit_result.get("ok", false))

	var definition_dock: Control = ContentEditorDockScript.new()
	get_root().add_child(definition_dock)
	await process_frame
	editor_dock_root_named_ok = definition_dock.name == "Connan Content Editor"
	var event_authoring_ok := bool(definition_dock.call("smoke_select_kind", "events")) \
		and bool(definition_dock.call("smoke_select_definition", "event_blood_altar_unlock")) \
		and bool(definition_dock.call("smoke_definition_event_set_entry_step", "altar_end")) \
		and bool(definition_dock.call("smoke_definition_event_add_continue_choice", "altar_start", "Smoke Continue")) \
		and bool(definition_dock.call("smoke_definition_event_update_step_fields", "altar_start", "Smoke Altar", "Smoke row-level event text.")) \
		and bool(definition_dock.call("smoke_definition_event_update_choice_fields", "altar_start", 0, "Smoke Choice Label", "altar_end"))
	var event_authoring_row: Dictionary = definition_dock.call("smoke_collect_current_definition_row")
	var event_entry_ok := String(event_authoring_row.get("entryStepId", "")) == "altar_end"
	var event_choice_ok := false
	var event_step_field_ok := false
	for step in event_authoring_row.get("steps", []):
		if typeof(step) != TYPE_DICTIONARY:
			continue
		if String(step.get("id", "")) != "altar_start":
			continue
		event_step_field_ok = String(step.get("title", "")) == "Smoke Altar" \
			and String(step.get("text", "")) == "Smoke row-level event text."
		for choice in (step as Dictionary).get("choices", []):
			if typeof(choice) == TYPE_DICTIONARY and String((choice as Dictionary).get("label", "")) == "Smoke Continue":
				event_choice_ok = true
			if typeof(choice) == TYPE_DICTIONARY \
					and String((choice as Dictionary).get("label", "")) == "Smoke Choice Label" \
					and String((choice as Dictionary).get("nextStepId", "")) == "altar_end":
				event_choice_ok = true
	var npc_authoring_ok := bool(definition_dock.call("smoke_select_kind", "npcs")) \
		and bool(definition_dock.call("smoke_select_definition", "npc_gatekeeper")) \
		and bool(definition_dock.call("smoke_definition_npc_add_talk_service", "Smoke Gate Talk")) \
		and bool(definition_dock.call("smoke_definition_npc_update_service_fields", 0, "route_info", "Smoke Gate Route", "Smoke row-level NPC service note.", {
			"kind": "route_info",
			"serviceId": "smoke_gate_route",
			"title": "Smoke Route"
		}))
	var npc_authoring_row: Dictionary = definition_dock.call("smoke_collect_current_definition_row")
	var npc_service_ok := false
	var npc_service_field_ok := false
	for service in npc_authoring_row.get("services", []):
		if typeof(service) == TYPE_DICTIONARY \
				and String((service as Dictionary).get("type", "")) == "talk" \
				and String((service as Dictionary).get("label", "")) == "Smoke Gate Talk":
			npc_service_ok = true
		if typeof(service) == TYPE_DICTIONARY \
				and String((service as Dictionary).get("type", "")) == "route_info" \
				and String((service as Dictionary).get("label", "")) == "Smoke Gate Route" \
				and String((service as Dictionary).get("note", "")) == "Smoke row-level NPC service note.":
			var opens_service: Dictionary = (service as Dictionary).get("opensService", {})
			npc_service_field_ok = String(opens_service.get("serviceId", "")) == "smoke_gate_route"
	definition_authoring_ok = event_authoring_ok and event_entry_ok and event_choice_ok and event_step_field_ok and npc_authoring_ok and npc_service_ok and npc_service_field_ok
	if not definition_authoring_ok:
		print("EDITOR_SMOKE_DEFINITION_AUTHORING event_authoring=%s event_entry=%s event_choice=%s event_step_field=%s npc_authoring=%s npc_service=%s npc_service_field=%s event_row=%s npc_row=%s" % [
			event_authoring_ok,
			event_entry_ok,
			event_choice_ok,
			event_step_field_ok,
			npc_authoring_ok,
			npc_service_ok,
			npc_service_field_ok,
			event_authoring_row,
			npc_authoring_row
		])
	definition_dock.queue_free()
	await process_frame

	var map_data := ContentTools.load_map_data("dungeon_floor_01")
	if not map_data.is_empty():
		var invalid_map_data := map_data.duplicate(true)
		invalid_map_data["cells"] = [
			"########",
			"#.....#"
		]
		var invalid_map_save := ContentTools.save_map_data("dungeon_floor_01", invalid_map_data)
		invalid_map_structure_blocked = not bool(invalid_map_save.get("ok", false))
		invalid_map_structure_unchanged = _read_text(FLOOR01_PATH) == floor01_backup

		var dock: Control = ContentEditorDockScript.new()
		get_root().add_child(dock)
		await process_frame
		dock.call("smoke_select_map", "dungeon_floor_01")
		dock.call("smoke_set_grid_mode", "start")
		dock.call("smoke_apply_grid_edit", 3, 5)
		var valid_map_save: Dictionary = dock.call("smoke_commit_current_map")
		valid_map_structure_applied = bool(valid_map_save.get("ok", false))
		grid_editor_path_ok = valid_map_structure_applied
		dock.queue_free()
		await process_frame

	var floor01_after_structure_edit := _read_text(FLOOR01_PATH)
	var slime_alpha := _find_row(map_data.get("placements", []), "slime_alpha")
	if not slime_alpha.is_empty():
		var invalid_placement := slime_alpha.duplicate(true)
		invalid_placement["fieldAi"] = {
			"approachRange": -1,
			"chaseRange": 2,
			"leashRange": 5
		}
		var invalid_map_edit_result := ContentTools.save_map_placement("dungeon_floor_01", "slime_alpha", invalid_placement)
		invalid_map_edit_blocked = not bool(invalid_map_edit_result.get("ok", false))
		invalid_map_edit_unchanged = _read_text(FLOOR01_PATH) == floor01_after_structure_edit

		var placement_dock: Control = ContentEditorDockScript.new()
		get_root().add_child(placement_dock)
		await process_frame
		placement_dock.call("smoke_select_map", "dungeon_floor_01")
		placement_dock.call("smoke_select_placement", "slime_alpha")
		placement_dock.call("smoke_set_grid_mode", "placement")
		placement_dock.call("smoke_apply_grid_edit", 4, 4)
		placement_dock.call("smoke_set_current_placement_field", "fieldAi", {
			"approachRange": 6,
			"chaseRange": 3,
			"leashRange": 7
		})
		var placement_save_result: Dictionary = placement_dock.call("smoke_commit_current_placement")
		valid_map_edit_applied = bool(placement_save_result.get("ok", false))
		placement_grid_editor_ok = valid_map_edit_applied

		placement_dock.call("smoke_select_placement", "rest_altar")
		var rest_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
		var rest_event_ok := bool(placement_dock.call("smoke_set_current_placement_field", "eventId", "event_rest_guard_post"))
		var rest_event_save: Dictionary = placement_dock.call("smoke_commit_current_placement")
		placement_dock.call("smoke_select_placement", "deserter_captain")
		var deserter_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
		var npc_picker_ok := bool(placement_dock.call("smoke_set_current_placement_field", "npcId", "npc_wounded_mystic"))
		var npc_picker_save: Dictionary = placement_dock.call("smoke_commit_current_placement")
		placement_dock.call("smoke_select_placement", "deserter_captain")
		placement_dock.call("smoke_set_preview_npc_service_index", 0)
		npc_contract_apply_ok = bool(placement_dock.call("smoke_apply_selected_npc_service_contract"))
		var npc_contract_save: Dictionary = placement_dock.call("smoke_commit_current_placement")
		placement_reference_picker_ok = rest_event_ok \
			and npc_picker_ok \
			and bool(rest_event_save.get("ok", false)) \
			and bool(npc_picker_save.get("ok", false)) \
			and bool(npc_contract_save.get("ok", false)) \
			and "\"eventId\": \"event_rest_guard_post\"" in _read_text(FLOOR01_PATH) \
			and "\"npcId\": \"npc_wounded_mystic\"" in _read_text(FLOOR01_PATH)

		var create_result: Dictionary = placement_dock.call("smoke_create_placement", "stairs", 6, 1)
		placement_create_ok = bool(create_result.get("ok", false))
		if placement_create_ok:
			var temp_id := String(create_result.get("id", ""))
			var stairs_preview_before: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			var trainer_target_ok := bool(placement_dock.call("smoke_set_preview_route_target_placement", "town_trainer_tent"))
			var trainer_target_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			var gatekeeper_target_ok := bool(placement_dock.call("smoke_set_preview_route_target_placement", "town_gatekeeper"))
			var gatekeeper_service_ok := bool(placement_dock.call("smoke_set_route_target_npc_service_index", 1))
			var gatekeeper_target_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			var route_picker_ok := bool(placement_dock.call("smoke_set_current_placement_field", "targetRoute", "dungeon"))
			var stairs_preview_after: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			placement_dock.call("smoke_set_current_placement_field", "targetMapId", "dungeon_floor_02")
			var after_create_result: Dictionary = placement_dock.call("smoke_commit_current_map")
			placement_create_ok = bool(after_create_result.get("ok", false)) \
				and temp_id in _read_text(FLOOR01_PATH) \
				and "\"targetMapId\": \"dungeon_floor_02\"" in _read_text(FLOOR01_PATH)
			var preview_checks := {
				"rest_usage": String(rest_preview.get("eventPreview", "")).contains("usage="),
				"rest_steps": String(rest_preview.get("eventPreview", "")).contains("steps="),
				"rest_choices": String(rest_preview.get("eventChoices", "")).contains("Choices:"),
				"rest_effects": String(rest_preview.get("eventEffects", "")).contains("Effects:"),
				"rest_graph": String(rest_preview.get("eventGraph", "")).contains("Graph:"),
				"rest_selected_unavailable": String(rest_preview.get("selectedEventStep", "")).contains("unavailable"),
				"deserter_services": String(deserter_preview.get("npcPreview", "")).contains("services="),
				"deserter_fight": String(deserter_preview.get("npcPreview", "")).contains("fight:칼을 뽑는다"),
				"deserter_service_rows": String(deserter_preview.get("npcServices", "")).contains("fight:칼을 뽑는다"),
				"deserter_service_detail": String(deserter_preview.get("npcServiceDetails", "")).contains("fight:칼을 뽑는다"),
				"deserter_selected": String(deserter_preview.get("selectedNpcService", "")).contains("Selected service:"),
				"route_picker_ok": route_picker_ok,
				"stairs_before_requirements": String(stairs_preview_before.get("routeRequirements", "")).contains("Route requirements: none"),
				"stairs_before_target": String(stairs_preview_before.get("routeTargetPreview", "")).contains("Target map: town_square"),
				"stairs_before_grid": String(stairs_preview_before.get("routeTargetMiniGrid", "")).contains("Mini-grid:"),
				"stairs_before_overlay": String(stairs_preview_before.get("routeTargetMiniGrid", "")).contains("T"),
				"stairs_before_targets": "town_square" in stairs_preview_before.get("routeTargets", []),
				"stairs_before_downstream_ok": trainer_target_ok,
				"stairs_before_downstream_contract": String(trainer_target_preview.get("routeHighlightedPlacementDownstream", "")).contains("opens skill_shop/town_trainer_skill_shop"),
				"stairs_before_downstream_surface": String(trainer_target_preview.get("routeHighlightedPlacementDownstream", "")).contains("ui=Buy Skill, Refresh Stock"),
				"stairs_before_downstream_catalog": String(trainer_target_preview.get("routeHighlightedPlacementDownstream", "")).contains("Power Slash+Smoke"),
				"stairs_before_downstream_selected": String(trainer_target_preview.get("routeTargetSelectedNpcService", "")).contains("Selected service: talk:기술 상점을 연다"),
				"stairs_before_gatekeeper_ok": gatekeeper_target_ok and gatekeeper_service_ok,
				"stairs_before_gatekeeper_downstream": String(gatekeeper_target_preview.get("routeHighlightedPlacementDownstream", "")).contains("Selected service: talk:청동 문에 대해 묻는다"),
				"stairs_before_gatekeeper_selected": String(gatekeeper_target_preview.get("routeTargetSelectedNpcService", "")).contains("Selected service: talk:청동 문에 대해 묻는다"),
				"stairs_after_targets": "dungeon_floor_02" in stairs_preview_after.get("routeTargets", []),
				"stairs_after_target": String(stairs_preview_after.get("routeTargetPreview", "")).contains("Target map: dungeon_floor_01"),
				"stairs_after_kind": String(stairs_preview_after.get("routeTargetPreview", "")).contains("kind=dungeon"),
				"stairs_after_start": String(stairs_preview_after.get("routeTargetMiniGrid", "")).contains("S"),
				"stairs_after_overlay": String(stairs_preview_after.get("routeTargetMiniGrid", "")).contains("L")
			}
			placement_affordance_preview_ok = true
			for check_value in preview_checks.values():
				placement_affordance_preview_ok = placement_affordance_preview_ok and bool(check_value)

			placement_dock.call("smoke_select_map", "town_square")
			placement_dock.call("smoke_select_placement", "town_gate")
			var gate_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			placement_affordance_preview_ok = placement_affordance_preview_ok \
				and String(gate_preview.get("routeRequirements", "")).contains("questStatus in [accepted, complete_ready, claimed]") \
				and String(gate_preview.get("routeRequirements", "")).contains("blocked=\"게시판에서 원정 전표를 받아야 청동 문이 열린다.\"") \
				and String(gate_preview.get("routeTargetPreview", "")).contains("Target map: dungeon_floor_01") \
				and String(gate_preview.get("routeTargetPreview", "")).contains("kind=dungeon") \
				and String(gate_preview.get("routeTargetMiniGrid", "")).contains("S")
			placement_dock.call("smoke_select_map", "dungeon_floor_02")
			placement_dock.call("smoke_select_placement", "black_water_rite")
			var rite_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			placement_affordance_preview_ok = placement_affordance_preview_ok \
				and String(rite_preview.get("eventChoices", "")).contains("검은 물 제단") \
				and String(rite_preview.get("eventEffects", "")).contains("set_flag") \
				and String(rite_preview.get("eventGraph", "")).contains("rite_start -> rite_end")
			var rite_step_ok := bool(placement_dock.call("smoke_set_preview_event_step", "rite_end"))
			var rite_step_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			placement_dock.call("smoke_set_preview_event_step", "rite_start")
			var rite_choice_ok := bool(placement_dock.call("smoke_set_preview_event_choice_index", 0))
			var rite_choice_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			placement_affordance_preview_ok = placement_affordance_preview_ok \
				and rite_step_ok \
				and String(rite_step_preview.get("selectedEventStep", "")).contains("잠잠해진 수면")
			placement_dock.call("smoke_select_placement", "mystic_camp")
			var mystic_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			placement_affordance_preview_ok = placement_affordance_preview_ok \
				and String(mystic_preview.get("npcServices", "")).contains("trade:약재를 산다") \
				and String(mystic_preview.get("npcServices", "")).contains("identify:저주를 살핀다") \
				and String(mystic_preview.get("npcServiceDetails", "")).contains("trade:약재를 산다") \
				and String(mystic_preview.get("npcServiceDetails", "")).contains("identify:저주를 살핀다")
			placement_dock.call("smoke_select_map", "town_square")
			placement_dock.call("smoke_select_placement", "town_trainer_tent")
			var trainer_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			var trainer_service_ok := bool(placement_dock.call("smoke_set_preview_npc_service_index", 0))
			var trainer_service_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			placement_dock.call("smoke_select_placement", "town_gate")
			var gate_highlight_ok := bool(placement_dock.call("smoke_set_preview_route_target_placement", "slime_alpha"))
			var gate_highlight_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			var gate_event_highlight_ok := bool(placement_dock.call("smoke_set_preview_route_target_placement", "blood_altar"))
			var gate_event_highlight_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			var gate_stairs_highlight_ok := bool(placement_dock.call("smoke_set_preview_route_target_placement", "stairs_down_floor_02"))
			var gate_stairs_highlight_preview: Dictionary = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			placement_dock.call("smoke_select_map", "dungeon_floor_01")
			var branch_create_result: Dictionary = placement_dock.call("smoke_create_placement", "event", 7, 5)
			var branch_choice_ok := false
			var branch_choice_preview: Dictionary = {}
			if bool(branch_create_result.get("ok", false)):
				placement_dock.call("smoke_set_current_placement_field", "eventId", "event_scholar_cache_reward")
				var branch_save_result: Dictionary = placement_dock.call("smoke_commit_current_placement")
				if bool(branch_save_result.get("ok", false)):
					branch_choice_ok = bool(placement_dock.call("smoke_set_preview_event_choice_index", 0))
					event_contract_apply_ok = bool(placement_dock.call("smoke_apply_selected_event_contract"))
					placement_dock.call("smoke_commit_current_placement")
					branch_choice_preview = placement_dock.call("smoke_get_current_placement_affordance_snapshot")
			preview_checks["gate_requirements"] = String(gate_preview.get("routeRequirements", "")).contains("questStatus in [accepted, complete_ready, claimed]")
			preview_checks["gate_blocked"] = String(gate_preview.get("routeRequirements", "")).contains("blocked=\"게시판에서 원정 전표를 받아야 청동 문이 열린다.\"")
			preview_checks["gate_target"] = String(gate_preview.get("routeTargetPreview", "")).contains("Target map: dungeon_floor_01")
			preview_checks["gate_kind"] = String(gate_preview.get("routeTargetPreview", "")).contains("kind=dungeon")
			preview_checks["gate_grid_start"] = String(gate_preview.get("routeTargetMiniGrid", "")).contains("S")
			preview_checks["gate_highlight_ok"] = gate_highlight_ok
			preview_checks["gate_highlight_target"] = String(gate_highlight_preview.get("routeHighlightedPlacement", "")).contains("slime_alpha")
			preview_checks["gate_highlight_grid"] = String(gate_highlight_preview.get("routeTargetMiniGrid", "")).contains("@")
			preview_checks["gate_highlight_detail"] = String(gate_highlight_preview.get("routeHighlightedPlacementDetail", "")).contains("fieldAi=6/3/7")
			preview_checks["gate_highlight_contract"] = String(gate_highlight_preview.get("routeHighlightedPlacementContract", "")).contains("encounter blocker")
			preview_checks["gate_event_highlight_ok"] = gate_event_highlight_ok
			preview_checks["gate_event_highlight_detail"] = String(gate_event_highlight_preview.get("routeHighlightedPlacementDetail", "")).contains("event_blood_altar_unlock") and String(gate_event_highlight_preview.get("routeHighlightedPlacementDetail", "")).contains("interaction=interact")
			preview_checks["gate_event_highlight_contract"] = String(gate_event_highlight_preview.get("routeHighlightedPlacementContract", "")).contains("choices=") and String(gate_event_highlight_preview.get("routeHighlightedPlacementContract", "")).contains("Effects:")
			preview_checks["gate_event_highlight_selected_step"] = String(gate_event_highlight_preview.get("routeTargetSelectedEventStep", "")).contains("Selected step: 피의 제단")
			preview_checks["gate_event_highlight_selected_choice"] = String(gate_event_highlight_preview.get("routeTargetSelectedEventChoice", "")).contains("Selected choice:")
			preview_checks["gate_stairs_highlight_ok"] = gate_stairs_highlight_ok
			preview_checks["gate_stairs_highlight_contract"] = String(gate_stairs_highlight_preview.get("routeHighlightedPlacementContract", "")).contains("flag=altar_blood_paid") and String(gate_stairs_highlight_preview.get("routeHighlightedPlacementContract", "")).contains("The lower seal is still closed")
			preview_checks["rite_choices"] = String(rite_preview.get("eventChoices", "")).contains("검은 물 제단")
			preview_checks["rite_effects"] = String(rite_preview.get("eventEffects", "")).contains("set_flag")
			preview_checks["rite_graph"] = String(rite_preview.get("eventGraph", "")).contains("rite_start -> rite_end")
			preview_checks["rite_step_ok"] = rite_step_ok
			preview_checks["rite_selected_step"] = String(rite_step_preview.get("selectedEventStep", "")).contains("잠잠해진 수면")
			preview_checks["rite_choice_ok"] = rite_choice_ok
			preview_checks["rite_selected_choice"] = String(rite_choice_preview.get("selectedEventChoice", "")).contains("effects=set_flag, set_quest_seed_state, heal_party, mark_done, log")
			preview_checks["branch_choice_ok"] = branch_choice_ok
			preview_checks["branch_selected_choice"] = String(branch_choice_preview.get("selectedEventChoice", "")).contains("학자 의뢰 진행 중") \
				and String(branch_choice_preview.get("selectedEventChoice", "")).contains("next=opened_cache") \
				and String(branch_choice_preview.get("selectedEventChoice", "")).contains("seed=quest_seed_black_mural") \
				and String(branch_choice_preview.get("selectedEventChoice", "")).contains("seedStatus=active")
			preview_checks["mystic_rows"] = String(mystic_preview.get("npcServices", "")).contains("trade:약재를 산다")
			preview_checks["mystic_identify"] = String(mystic_preview.get("npcServices", "")).contains("identify:저주를 살핀다")
			preview_checks["mystic_detail_trade"] = String(mystic_preview.get("npcServiceDetails", "")).contains("trade:약재를 산다")
			preview_checks["mystic_detail_identify"] = String(mystic_preview.get("npcServiceDetails", "")).contains("identify:저주를 살핀다")
			preview_checks["trainer_detail"] = String(trainer_preview.get("npcServiceDetails", "")).contains("opens(skill_shop/town_trainer_skill_shop)")
			preview_checks["trainer_service_ok"] = trainer_service_ok
			preview_checks["trainer_selected"] = String(trainer_service_preview.get("selectedNpcService", "")).contains("opens skill_shop/town_trainer_skill_shop")
			preview_checks["trainer_open_preview"] = String(trainer_service_preview.get("opensServicePreview", "")).contains("catalogId=trainer_skill_rotation") and String(trainer_service_preview.get("opensServicePreview", "")).contains("currency=gold")
			preview_checks["trainer_open_surface"] = String(trainer_service_preview.get("opensServiceSurface", "")).contains("ui=Buy Skill, Refresh Stock") and String(trainer_service_preview.get("opensServiceSurface", "")).contains("catalog=trainer_skill_rotation")
			preview_checks["trainer_open_catalog"] = String(trainer_service_preview.get("opensServiceCatalog", "")).contains("count=5") \
				and String(trainer_service_preview.get("opensServiceCatalog", "")).contains("Power Slash+Smoke") \
				and String(trainer_service_preview.get("opensServiceCatalog", "")).contains("Guard Break")
			preview_checks["trainer_open_stock"] = String(trainer_service_preview.get("opensServiceStock", "")).contains("stockSize=3") \
				and String(trainer_service_preview.get("opensServiceStock", "")).contains("Power Slash+Smoke=42g") \
				and String(trainer_service_preview.get("opensServiceStock", "")).contains("Guard Break=24g")
			route_preview_report = {
				"tempTownRouteTrainer": trainer_target_preview,
				"tempTownRouteGatekeeper": gatekeeper_target_preview,
				"townGateToDungeonFieldMonster": gate_highlight_preview,
				"townGateToDungeonEvent": gate_event_highlight_preview,
				"townGateToDungeonStairs": gate_stairs_highlight_preview
			}
			placement_affordance_preview_ok = true
			for check_value in preview_checks.values():
				placement_affordance_preview_ok = placement_affordance_preview_ok and bool(check_value)
			if not placement_affordance_preview_ok:
				print("EDITOR_SMOKE_GATEKEEPER target=%s service=%s downstream=%s" % [gatekeeper_target_ok, gatekeeper_service_ok, gatekeeper_target_preview.get("routeHighlightedPlacementDownstream", "")])
				print("EDITOR_SMOKE_CHECKS %s" % preview_checks)
			placement_dock.call("smoke_select_map", "dungeon_floor_01")
			placement_dock.call("smoke_select_placement", temp_id)
			var delete_result: Dictionary = placement_dock.call("smoke_delete_selected_placement")
			if bool(delete_result.get("ok", false)):
				var after_delete_result: Dictionary = placement_dock.call("smoke_commit_current_map")
				placement_delete_ok = bool(after_delete_result.get("ok", false)) and temp_id not in _read_text(FLOOR01_PATH)
		placement_dock.queue_free()
		await process_frame

	if valid_edit_applied and valid_map_edit_applied and valid_map_structure_applied:
		bundle = ContentTools.export_build_bundle()
		report = ContentTools.export_manifest_report("res://output/editor_manifest_report.json")
		var content_registry: Node = get_root().get_node_or_null("ContentRegistry")
		var game_app: Node = get_root().get_node_or_null("GameApp")
		if content_registry != null:
			content_registry.call("load_all")
			var imported_manifest := _load_json_dict(ContentTools.IMPORTED_MANIFEST_PATH)
			var compiled_maps: Array = imported_manifest.get("compiledMaps", [])
			var map_source_hash_ok := false
			content_ok = not imported_manifest.is_empty() and compiled_maps.size() > 0
			for entry in compiled_maps:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				if String(entry.get("id", "")) != "dungeon_floor_01":
					continue
				map_source_hash_ok = String(entry.get("sourcePath", "")) == FLOOR01_PATH \
					and entry.has("sourceHash") \
					and int(entry.get("sourceHash", 0)) != 0
				var imported_map_data := _load_json_dict(String(entry.get("path", "")))
				compiled_map_has_preview = imported_map_data.has("compiledPreview")
				imported_start_x = int(imported_map_data.get("start", [-1, -1])[0])
				for placement in imported_map_data.get("placements", []):
					if typeof(placement) != TYPE_DICTIONARY:
						continue
					var placement_id := String(placement.get("id", ""))
					match placement_id:
						"slime_alpha":
							runtime_field_ai_approach = int(placement.get("fieldAi", {}).get("approachRange", -1))
							imported_slime_y = int(placement.get("position", [-1, -1])[1])
						"rest_altar":
							runtime_rest_event_id = String(placement.get("eventId", ""))
						"deserter_captain":
							runtime_deserter_npc_id = String(placement.get("npcId", ""))
							imported_npc_contract_ok = String(placement.get("authoringSelectedNpcServiceType", "")) != "" \
								and int(placement.get("authoringSelectedNpcServiceIndex", -1)) >= 0
					if String(placement.get("eventId", "")) == "event_scholar_cache_reward":
						imported_event_contract_ok = String(placement.get("authoringSelectedEventStepId", "")) != "" \
							and int(placement.get("authoringSelectedEventChoiceIndex", -1)) >= 0
				break
			imported_manifest_flow_ok = bool(bundle.get("ok", false)) \
				and String(bundle.get("manifestPath", "")) == ContentTools.IMPORTED_MANIFEST_PATH \
				and bool(report.get("validation", {}).get("ok", false)) \
				and bool(report.get("mapValidation", {}).get("ok", false)) \
				and imported_manifest.has("definitionHashes") \
				and map_source_hash_ok
			var runtime_skill: Dictionary = content_registry.call("get_definition", "skills", "power_slash")
			runtime_skill_power = int(runtime_skill.get("power", -1))
		if game_app != null:
			game_app.set("current_slot", 1)
			game_app.set("current_mode", "dungeon")
			game_app.set("dungeon_runtime_source", "compiled")
			game_app.call("set_editor_test_payload", {
				"route": "dungeon",
				"slot": 1,
				"map_id": "dungeon_floor_01",
				"dungeon_source": "compiled"
			})
			var dungeon_scene: Node = load("res://scenes/editor_tools/PlaytestDungeonScene.tscn").instantiate()
			get_root().call_deferred("add_child", dungeon_scene)
			await process_frame
			compiled_handoff_ok = String(dungeon_scene.get("dungeon_source_mode")) == "compiled" \
				and bool(dungeon_scene.get("compiled_runtime_active")) \
				and String(dungeon_scene.get("map_data").get("id", "")) == "dungeon_floor_01"
			dungeon_scene.queue_free()
			await process_frame

			game_app.set("current_mode", "dungeon")
			game_app.set("dungeon_runtime_source", "authored")
			game_app.call("set_editor_test_payload", {
				"route": "dungeon",
				"slot": 1,
				"map_id": "dungeon_floor_01",
				"dungeon_source": "authored"
			})
			var authored_scene: Node = load("res://scenes/editor_tools/PlaytestDungeonScene.tscn").instantiate()
			get_root().call_deferred("add_child", authored_scene)
			await process_frame
			authored_handoff_ok = String(authored_scene.get("dungeon_source_mode")) == "authored" \
				and not bool(authored_scene.get("compiled_runtime_active")) \
				and String(authored_scene.get("map_data").get("id", "")) == "dungeon_floor_01"
			authored_scene.queue_free()

	_restore_file(SKILLS_PATH, skills_backup)
	_restore_file(QUESTS_PATH, quests_backup)
	_restore_file(FLOOR01_PATH, floor01_backup)
	ContentTools.export_build_bundle()
	var content_registry_after_restore: Node = get_root().get_node_or_null("ContentRegistry")
	if content_registry_after_restore != null:
		content_registry_after_restore.call("load_all")
	var route_preview_file := FileAccess.open(ROUTE_PREVIEW_OUTPUT_PATH, FileAccess.WRITE)
	if route_preview_file != null:
		route_preview_file.store_string(JSON.stringify(route_preview_report, "\t"))
	route_preview_file = FileAccess.open(ROUTE_PREVIEW_IMPORTED_PATH, FileAccess.WRITE)
	if route_preview_file != null:
		route_preview_file.store_string(JSON.stringify(route_preview_report, "\t"))
	route_preview_file = null
	var fallback_workspace: Control = EditorWorkspaceScript.new()
	get_root().add_child(fallback_workspace)
	await process_frame
	var dungeon_summary := String(fallback_workspace.call("smoke_get_summary_text"))
	var dungeon_select_field := bool(fallback_workspace.call("smoke_set_route_preview_entry", "townGateToDungeonFieldMonster"))
	var dungeon_field_detail := String(fallback_workspace.call("smoke_get_route_preview_detail_text"))
	var dungeon_select_event := bool(fallback_workspace.call("smoke_set_route_preview_entry", "townGateToDungeonEvent"))
	var dungeon_event_detail := String(fallback_workspace.call("smoke_get_route_preview_detail_text"))
	var dungeon_event_choice_switched := bool(fallback_workspace.call("smoke_set_route_target_event_choice_index", 1))
	var dungeon_event_choice_detail := String(fallback_workspace.call("smoke_get_route_preview_detail_text"))
	var dungeon_event_step_switched := bool(fallback_workspace.call("smoke_set_route_target_event_step_id", "altar_end"))
	var dungeon_event_step_detail := String(fallback_workspace.call("smoke_get_route_preview_detail_text"))
	fallback_workspace.call("smoke_set_selected_map", "town_square")
	await process_frame
	var town_summary := String(fallback_workspace.call("smoke_get_summary_text"))
	var town_select_trainer := bool(fallback_workspace.call("smoke_set_route_preview_entry", "tempTownRouteTrainer"))
	var town_trainer_detail := String(fallback_workspace.call("smoke_get_route_preview_detail_text"))
	var town_select_gatekeeper := bool(fallback_workspace.call("smoke_set_route_preview_entry", "tempTownRouteGatekeeper"))
	var town_gatekeeper_detail := String(fallback_workspace.call("smoke_get_route_preview_detail_text"))
	var town_gatekeeper_talk_switched := bool(fallback_workspace.call("smoke_set_route_target_service_index", 1))
	var town_gatekeeper_talk_detail := String(fallback_workspace.call("smoke_get_route_preview_detail_text"))
	var town_gatekeeper_service_switched := bool(fallback_workspace.call("smoke_set_route_target_service_index", 0))
	var town_gatekeeper_service_detail := String(fallback_workspace.call("smoke_get_route_preview_detail_text"))
	fallback_workspace_summary_ok = dungeon_summary.contains("[b]Route Preview Report[/b]") \
		and dungeon_summary.contains("townGateToDungeonFieldMonster") \
		and dungeon_summary.contains("slime_alpha") \
		and dungeon_summary.contains("blood_altar") \
		and town_summary.contains("[b]Route Preview Report[/b]") \
		and town_summary.contains("tempTownRouteTrainer") \
		and town_summary.contains("town_gatekeeper") \
		and town_summary.contains("opens skill_shop/town_trainer_skill_shop")
	fallback_workspace_detail_ok = dungeon_select_field \
		and dungeon_field_detail.contains("[b]Route Preview Detail[/b] townGateToDungeonFieldMonster") \
		and dungeon_field_detail.contains("fieldAi=6/3/7") \
		and dungeon_select_event \
		and dungeon_event_detail.contains("[b]Route Preview Detail[/b] townGateToDungeonEvent") \
		and dungeon_event_detail.contains("Selected Target Step") \
		and dungeon_event_detail.contains("Selected step: altar_start") \
		and dungeon_event_detail.contains("학자의 기록대로 피를 바치고 문양을 완성한다") \
		and dungeon_event_choice_switched \
		and dungeon_event_choice_detail.contains("Selected choice: 피를 바친다") \
		and dungeon_event_choice_detail.contains("effects=set_flag, damage_front, mark_done, log") \
		and dungeon_event_step_switched \
		and dungeon_event_step_detail.contains("Selected step: altar_end") \
		and dungeon_event_step_detail.contains("제단은 다시 차갑게 식어 간다.") \
		and town_select_trainer \
		and town_trainer_detail.contains("[b]Route Preview Detail[/b] tempTownRouteTrainer") \
		and town_trainer_detail.contains("opens skill_shop/town_trainer_skill_shop") \
		and town_select_gatekeeper \
		and town_gatekeeper_detail.contains("[b]Route Preview Detail[/b] tempTownRouteGatekeeper") \
		and town_gatekeeper_detail.contains("Selected service: route_info:문 상태를 확인한다") \
		and town_gatekeeper_talk_switched \
		and town_gatekeeper_talk_detail.contains("Selected service: talk:청동 문에 대해 묻는다") \
		and town_gatekeeper_talk_detail.contains("Highlighted downstream: Selected service: talk:청동 문에 대해 묻는다") \
		and town_gatekeeper_service_switched \
		and town_gatekeeper_service_detail.contains("Selected service: route_info:문 상태를 확인한다") \
		and town_gatekeeper_service_detail.contains("Highlighted downstream: Selected service: route_info:문 상태를 확인한다")
	if not fallback_workspace_detail_ok:
		print("EDITOR_SMOKE_FALLBACK_EVENT_DETAIL %s" % dungeon_event_detail)
		print("EDITOR_SMOKE_FALLBACK_EVENT_CHOICE_DETAIL %s" % dungeon_event_choice_detail)
		print("EDITOR_SMOKE_FALLBACK_EVENT_STEP_DETAIL %s" % dungeon_event_step_detail)
		print("EDITOR_SMOKE_FALLBACK_TRAINER_DETAIL %s" % town_trainer_detail)
		print("EDITOR_SMOKE_FALLBACK_GATEKEEPER_DETAIL %s" % town_gatekeeper_detail)
		print("EDITOR_SMOKE_FALLBACK_GATEKEEPER_SWITCHED %s" % town_gatekeeper_service_detail)
	fallback_workspace.queue_free()
	await process_frame

	print("EDITOR_SMOKE validation_ok=%s map_ok=%s preview_ok=%s invalid_blocked=%s invalid_unchanged=%s map_invalid_blocked=%s map_invalid_unchanged=%s map_structure_invalid_blocked=%s map_structure_invalid_unchanged=%s edit_ok=%s definition_authoring_ok=%s dock_root_named=%s map_edit_ok=%s map_structure_ok=%s grid_editor_ok=%s placement_grid_ok=%s placement_reference_ok=%s placement_affordance_ok=%s placement_create_ok=%s placement_delete_ok=%s fallback_workspace_ok=%s fallback_workspace_detail_ok=%s bundle_ok=%s content_ok=%s imported_manifest_flow_ok=%s manifest=%s compiled_preview=%s runtime_power=%d field_ai=%d imported_start_x=%d imported_slime_y=%d rest_event=%s deserter_npc=%s compiled_handoff=%s authored_handoff=%s counts=%s" % [
		validation.get("ok", false),
		map_validation.get("ok", false),
		preview.get("ok", false),
		invalid_edit_blocked,
		invalid_edit_unchanged,
		invalid_map_edit_blocked,
		invalid_map_edit_unchanged,
		invalid_map_structure_blocked,
		invalid_map_structure_unchanged,
		valid_edit_applied,
		definition_authoring_ok,
		editor_dock_root_named_ok,
		valid_map_edit_applied,
		valid_map_structure_applied,
		grid_editor_path_ok,
		placement_grid_editor_ok,
		placement_reference_picker_ok,
		placement_affordance_preview_ok,
		placement_create_ok,
		placement_delete_ok,
		fallback_workspace_summary_ok,
		fallback_workspace_detail_ok,
		bundle.get("ok", false),
		content_ok,
		imported_manifest_flow_ok,
		ContentTools.IMPORTED_MANIFEST_PATH,
		compiled_map_has_preview,
		runtime_skill_power,
		runtime_field_ai_approach,
		imported_start_x,
		imported_slime_y,
		runtime_rest_event_id,
		runtime_deserter_npc_id,
		compiled_handoff_ok,
		authored_handoff_ok,
		report.get("counts", {})
	])
	var ok := bool(validation.get("ok", false)) \
		and bool(map_validation.get("ok", false)) \
		and bool(preview.get("ok", false)) \
		and invalid_edit_blocked \
		and invalid_edit_unchanged \
		and valid_edit_applied \
		and definition_authoring_ok \
		and editor_dock_root_named_ok \
		and invalid_map_edit_blocked \
		and invalid_map_edit_unchanged \
		and invalid_map_structure_blocked \
		and invalid_map_structure_unchanged \
		and valid_map_edit_applied \
		and valid_map_structure_applied \
		and grid_editor_path_ok \
		and placement_grid_editor_ok \
		and placement_reference_picker_ok \
		and placement_affordance_preview_ok \
		and event_contract_apply_ok \
		and npc_contract_apply_ok \
		and imported_event_contract_ok \
		and imported_npc_contract_ok \
		and placement_create_ok \
		and placement_delete_ok \
		and fallback_workspace_summary_ok \
		and fallback_workspace_detail_ok \
		and bool(bundle.get("ok", false)) \
		and content_ok \
		and imported_manifest_flow_ok \
		and compiled_map_has_preview \
		and runtime_skill_power == edited_skill_power \
		and runtime_field_ai_approach == 6 \
		and imported_start_x == 3 \
		and imported_slime_y == 4 \
		and runtime_rest_event_id == "event_rest_guard_post" \
		and runtime_deserter_npc_id == "npc_wounded_mystic" \
		and compiled_handoff_ok \
		and authored_handoff_ok
	quit(0 if ok else 1)

func _load_json_dict(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _read_text(path: String) -> String:
	if path == "" or not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

func _restore_file(path: String, text: String) -> void:
	if path == "":
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)

func _find_row(rows: Array, row_id: String) -> Dictionary:
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and String(row.get("id", "")) == row_id:
			return (row as Dictionary).duplicate(true)
	return {}

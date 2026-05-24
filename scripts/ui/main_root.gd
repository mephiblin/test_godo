extends Node

const EDITOR_WORKSPACE_SCENE := preload("res://scenes/editor_tools/EditorWorkspace.tscn")

@onready var scene_host: Node = $SceneHost
@onready var hud_layer: CanvasLayer = $HudLayer
@onready var modal_layer: CanvasLayer = $ModalLayer
@onready var transition_layer: CanvasLayer = $TransitionLayer

func _ready() -> void:
	SceneRouter.register_host(scene_host, hud_layer, modal_layer, transition_layer)
	SceneRouter.change_route(GameApp.current_mode, {})
	if OS.get_environment("CONAN_DOT_DOMAIN_SMOKE") == "1":
		call_deferred("_run_domain_smoke")
		return
	if OS.get_environment("CONAN_DOT_SAVE_MIGRATION_SMOKE") == "1":
		call_deferred("_run_save_migration_smoke")
		return
	if OS.get_environment("CONAN_DOT_CONTENT_IMPORT_SMOKE") == "1":
		call_deferred("_run_content_import_smoke")
		return
	if OS.get_environment("CONAN_DOT_BENCHMARK_SMOKE") == "1":
		call_deferred("_run_benchmark_smoke")
		return
	if GameApp.smoke_enabled:
		call_deferred("_run_smoke")

func _run_domain_smoke() -> void:
	var slot := 2
	var backup: Variant = _read_slot_text(slot)
	var aux_slot := 3
	var aux_backup: Variant = _read_slot_text(aux_slot)
	var probe_slot := 1
	var probe_backup: Variant = _read_slot_text(probe_slot)
	SaveService.delete_slot(slot)
	SaveService.delete_slot(aux_slot)
	SaveService.delete_slot(probe_slot)
	var profile: Dictionary = {
		"name": "Domain Conan",
		"classId": "wanderer",
		"backgroundId": "outcast",
		"startSupply": "camp_kit"
	}
	SaveService.create_default_session(slot, profile)
	SaveService.add_inventory_item(slot, "firebomb", 1)
	SaveService.add_inventory_item(slot, "antivenom", 1)
	SaveService.add_inventory_item(slot, "throwing_knife", 1)
	SaveService.update_front_state(slot, 20, 20, ["독"])
	var town_gate_before := await _debug_route_transition(slot, "town_square", "dungeon_floor_01", GameApp.DUNGEON_SOURCE_COMPILED)
	var gatekeeper_route_before := NpcService.inspect_route(slot, _find_service_by_type(NpcService.list_services("npc_gatekeeper"), "route_info"))
	var board_offers_before := QuestService.board_offers(slot)
	var board_offers_refresh := QuestService.refresh_board(slot)
	var accept_result: Dictionary = QuestService.accept_quest(slot, "slime_cleanup")
	var town_gate_after := await _debug_route_transition(slot, "town_square", "dungeon_floor_01", GameApp.DUNGEON_SOURCE_COMPILED)
	var gatekeeper_route_after := NpcService.inspect_route(slot, _find_service_by_type(NpcService.list_services("npc_gatekeeper"), "route_info"))
	var stock_before: Array[Dictionary] = ShopService.ensure_skill_shop_stock(slot, "town_scholar", ContentRegistry.get_definition("vendors", "town_scholar"))
	var stock_refresh: Array[Dictionary] = ShopService.reroll_skill_shop_stock(slot, "town_scholar", ContentRegistry.get_definition("vendors", "town_scholar"))
	var buy_result: Dictionary = {}
	if not stock_refresh.is_empty():
		buy_result = ShopService.buy_skill(slot, "town_scholar", String(stock_refresh[0].get("skillId", "")))
	var stock_after: Array[Dictionary] = ShopService.current_skill_shop_stock(slot, "town_scholar")
	var trade_result: Dictionary = ShopService.buy_vendor_item(slot, "vendor_apothecary", "bandage", 1)
	SaveService.add_inventory_item(slot, "black_dagger", 1)
	SaveService.add_inventory_item(slot, "priest_mask", 1)
	var scholar_services := NpcService.list_services("npc_scholar")
	var trainer_services_before := NpcService.describe_services_for_slot(slot, "npc_trainer")
	var scholar_talk_result := NpcService.start_dialogue(_find_service_by_type(scholar_services, "talk"))
	var scholar_choice_result := NpcService.choose_dialogue(_find_service_by_type(scholar_services, "talk"), "scholar_intro", 0)
	var identify_result := NpcService.identify_item(slot, "npc_scholar", _find_service_by_type(scholar_services, "identify"), "black_dagger")
	var equip_result := SaveService.equip_item(slot, "black_dagger")
	var identify_mask_result := NpcService.identify_item(slot, "npc_scholar", _find_service_by_type(scholar_services, "identify"), "priest_mask")
	var equip_mask_result := SaveService.equip_item(slot, "priest_mask")
	var quest_seed_accept := QuestService.accept_quest_seed(slot, "npc_scholar", "quest_seed_black_mural")
	var quest_seed_dungeon_snapshot_before: Dictionary = await _debug_route_snapshot(slot, "dungeon_floor_01", GameApp.MODE_DUNGEON, GameApp.DUNGEON_SOURCE_COMPILED)
	var field_ai_probe: Dictionary = {}
	var field_ambush_probe: Dictionary = {}
	var field_group_probe: Dictionary = {}
	var field_los_probe: Dictionary = {}
	var field_door_los_probe: Dictionary = {}
	var field_authored_group_probe: Dictionary = {}
	var secret_door_probe: Dictionary = {}
	var secret_door_patrol_probe: Dictionary = {}
	var ai_probe_scene: PackedScene = load("res://scenes/dungeon/DungeonScene.tscn")
	if ai_probe_scene != null:
		var ai_scene: Node = ai_probe_scene.instantiate()
		SceneRouter.scene_host.add_child(ai_scene)
		if ai_scene.has_method("setup"):
			ai_scene.call("setup", {
				"slot": slot,
				"map_id": "dungeon_floor_01",
				"dungeon_source": GameApp.DUNGEON_SOURCE_COMPILED
			})
		var grid_smoke := _grid_scene_smoke_driver()
		field_ai_probe = grid_smoke.field_monster_ai_probe(ai_scene, "slime_alpha")
		field_ambush_probe = grid_smoke.field_monster_ai_probe(ai_scene, "grave_robber")
		field_group_probe = grid_smoke.field_monster_group_alert_probe(ai_scene, "grave_robber")
		field_los_probe = grid_smoke.field_monster_los_probe(ai_scene, "slime_alpha")
		ai_scene.queue_free()
		await get_tree().process_frame
	if ai_probe_scene != null:
		var door_probe_scene: Node = ai_probe_scene.instantiate()
		SceneRouter.scene_host.add_child(door_probe_scene)
		if door_probe_scene.has_method("setup"):
			door_probe_scene.call("setup", {
				"slot": slot,
				"map_id": "dungeon_floor_01",
				"dungeon_source": GameApp.DUNGEON_SOURCE_AUTHORED
			})
		var grid_smoke := _grid_scene_smoke_driver()
		field_door_los_probe = grid_smoke.field_monster_door_los_probe(door_probe_scene, "slime_alpha", "sealed_gate")
		secret_door_probe = grid_smoke.secret_door_blocking_probe(door_probe_scene, "secret_cache")
		secret_door_patrol_probe = grid_smoke.secret_door_patrol_probe(door_probe_scene, "ruin_husk", "secret_cache")
		field_authored_group_probe = grid_smoke.field_monster_group_alert_probe(door_probe_scene, "grave_robber")
		door_probe_scene.queue_free()
		await get_tree().process_frame
	var second_seed_accept_before := QuestService.accept_quest_seed(slot, "npc_wounded_mystic", "quest_seed_black_water_vow")
	var scout_result := NpcService.recruit_companion(slot, "npc_exile_scout", _find_service_by_type(NpcService.list_services("npc_exile_scout"), "recruit"))
	var fight_context := NpcService.build_fight_context(slot, "npc_deserter_captain", _find_service_by_type(NpcService.list_services("npc_deserter_captain"), "fight"))
	var fight_victory := false
	var defeat_probe: Dictionary = {}
	var combat_skill_ids: Array = []
	var combat_roll_rows: Array = []
	var combat_item_results: Array = []
	var combat_state_after_items: Dictionary = {}
	var combat_state_before_target_confirm: Dictionary = {}
	var combat_state_after_target_confirm: Dictionary = {}
	var combat_selection_probe: Dictionary = {}
	var combat_item_command_probe: Dictionary = {}
	var combat_enemy_guard_probe: Dictionary = {}
	var combat_enemy_resist_probe: Dictionary = {}
	var combat_view_model_probe: Dictionary = {}
	var combat_victory_summary_probe: Dictionary = {}
	var combat_defeat_summary_probe: Dictionary = {}
	var ending_report_probe: Dictionary = {}
	var combat_runtime_script := preload("res://scripts/runtime/combat_runtime.gd")
	var probe_profile: Dictionary = {
		"name": "Probe Conan",
		"classId": "wanderer",
		"backgroundId": "outcast",
		"startSupply": "camp_kit"
	}
	SaveService.create_default_session(probe_slot, probe_profile)
	SaveService.add_inventory_item(probe_slot, "priest_mask", 1)
	NpcService.identify_item(probe_slot, "npc_scholar", _find_service_by_type(scholar_services, "identify"), "priest_mask")
	SaveService.equip_item(probe_slot, "priest_mask")
	SaveService.update_front_state(probe_slot, 20, 20, [])
	var guard_runtime = combat_runtime_script.new()
	guard_runtime.setup({
		"slot": probe_slot,
		"monster_id": "serpent_guard",
		"monster_name": "뱀 사원 경비병"
	})
	var combat_smoke := _combat_smoke_driver()
	combat_enemy_guard_probe = combat_smoke.runtime_enemy_turn_probe(guard_runtime)
	combat_view_model_probe = guard_runtime.build_view_model()
	var victory_runtime = combat_runtime_script.new()
	victory_runtime.setup({
		"slot": probe_slot,
		"monster_id": "slime_alpha",
		"monster_instance_id": "domain_slime_alpha",
		"return_map_id": "dungeon_floor_01"
	})
	combat_victory_summary_probe = combat_smoke.runtime_win(victory_runtime)
	var defeat_runtime = combat_runtime_script.new()
	defeat_runtime.setup({
		"slot": probe_slot,
		"monster_id": "serpent_guard",
		"monster_instance_id": "domain_serpent_guard",
		"return_map_id": "dungeon_floor_02"
	})
	combat_defeat_summary_probe = combat_smoke.runtime_lose(defeat_runtime)
	SaveService.update_front_state(probe_slot, 20, 20, [])
	var resist_runtime = combat_runtime_script.new()
	resist_runtime.setup({
		"slot": probe_slot,
		"monster_id": "poisoned_raider",
		"monster_name": "독에 미친 약탈자"
	})
	combat_enemy_resist_probe = combat_smoke.runtime_enemy_turn_probe(resist_runtime)
	var probe_data := SaveService.load_slot(probe_slot)
	probe_data["flags"]["blind_priest_cleared"] = true
	probe_data["questSeeds"]["quest_seed_black_mural"] = {"id": "quest_seed_black_mural", "status": "rewarded"}
	probe_data["questSeeds"]["quest_seed_black_water_vow"] = {"id": "quest_seed_black_water_vow", "status": "rewarded"}
	SaveService.save_slot(probe_slot, probe_data)
	SaveService.mark_campaign_clear(probe_slot, "Blind Priest Defeated", "dungeon_floor_03")
	ending_report_probe = NpcService.inspect_ending(probe_slot, _find_service_by_type(scholar_services, "ending_report"))
	if not fight_context.is_empty():
		GameApp.enter_combat(fight_context)
		await get_tree().process_frame
		var combat_scene := SceneRouter.current_scene
		combat_skill_ids = combat_smoke.skill_ids(combat_scene)
		combat_roll_rows = combat_smoke.roll_rows(combat_scene)
		combat_smoke.use_item(combat_scene, "firebomb")
		combat_item_results.append({"itemId": "firebomb"})
		combat_smoke.use_item(combat_scene, "antivenom")
		combat_item_results.append({"itemId": "antivenom"})
		combat_item_command_probe = combat_smoke.item_commands_probe(combat_scene, "throwing_knife")
		combat_state_after_items = combat_smoke.combat_state(combat_scene)
		combat_selection_probe = combat_smoke.selection_commands_probe(combat_scene)
		var probe: Dictionary = combat_smoke.target_and_cooldown_probe(combat_scene)
		combat_state_before_target_confirm = probe.get("before", {})
		combat_state_after_target_confirm = probe.get("after", {})
		combat_smoke.win(combat_scene)
		await get_tree().process_frame
		await get_tree().process_frame
		fight_victory = bool(SaveService.load_slot(slot).get("flags", {}).get(String(fight_context.get("victory_flag", "")), false))
	var defeat_profile: Dictionary = {
		"name": "Defeat Conan",
		"classId": "wanderer",
		"backgroundId": "outcast",
		"startSupply": "camp_kit"
	}
	SaveService.create_default_session(aux_slot, defeat_profile)
	GameApp.enter_combat({
		"slot": aux_slot,
		"monster_id": "slime_alpha",
		"monster_name": "Slime Alpha",
		"return_route": GameApp.MODE_DUNGEON,
		"return_map_id": "dungeon_floor_01"
	})
	await get_tree().process_frame
	var defeat_scene := SceneRouter.current_scene
	combat_smoke.lose(defeat_scene)
	await get_tree().process_frame
	combat_smoke.recover_in_town(defeat_scene)
	await get_tree().process_frame
	var defeat_data := SaveService.load_slot(aux_slot)
	defeat_probe = {
		"mode": GameApp.current_mode,
		"route": String(defeat_data.get("mode", "")),
		"meta": defeat_data.get("meta", {}).get("lastDefeat", {}),
		"defeatCount": int(defeat_data.get("meta", {}).get("defeatCount", 0)),
		"gold": int(defeat_data.get("resources", {}).get("gold", 0)),
		"mapId": String(defeat_data.get("runtime", {}).get("mapId", ""))
	}
	var avoid_profile: Dictionary = {
		"name": "Avoid Conan",
		"classId": "wanderer",
		"backgroundId": "outcast",
		"startSupply": "camp_kit"
	}
	SaveService.create_default_session(aux_slot, avoid_profile)
	var avoid_fight_result := NpcService.avoid_fight(aux_slot, "npc_deserter_captain", _find_service_by_type(NpcService.list_services("npc_deserter_captain"), "fight"))
	var trap_result: Dictionary = EventService.apply_event(slot, "event_trap_poison_dart")
	var rest_result: Dictionary = EventService.apply_event(slot, "event_rest_guard_post")
	var shrine_result: Dictionary = EventService.apply_event(slot, "event_shrine_healing_spring")
	var altar_result: Dictionary = EventService.apply_event(slot, "event_blood_altar_unlock")
	var cache_result: Dictionary = EventService.apply_event(slot, "event_scholar_cache_reward")
	var quest_seed_floor_02_snapshot_before: Dictionary = await _debug_route_snapshot(slot, "dungeon_floor_02", GameApp.MODE_DUNGEON, GameApp.DUNGEON_SOURCE_COMPILED)
	var floor3_gate_before: Dictionary = await _debug_route_transition(slot, "dungeon_floor_02", "dungeon_floor_03", GameApp.DUNGEON_SOURCE_COMPILED)
	var quest_seed_town_snapshot_ready: Dictionary = await _debug_route_snapshot(slot, "town_square", GameApp.MODE_TOWN, GameApp.DUNGEON_SOURCE_COMPILED)
	var quest_seed_claim := QuestService.claim_quest_seed_reward(slot, "npc_scholar", "quest_seed_black_mural")
	var second_seed_accept_after := QuestService.accept_quest_seed(slot, "npc_wounded_mystic", "quest_seed_black_water_vow")
	var quest_seed_floor_02_snapshot_active: Dictionary = await _debug_route_snapshot(slot, "dungeon_floor_02", GameApp.MODE_DUNGEON, GameApp.DUNGEON_SOURCE_COMPILED)
	var black_water_rite_result: Dictionary = EventService.apply_event(slot, "event_black_water_rite")
	var quest_seed_floor_02_snapshot_ready: Dictionary = await _debug_route_snapshot(slot, "dungeon_floor_02", GameApp.MODE_DUNGEON, GameApp.DUNGEON_SOURCE_COMPILED)
	var second_seed_claim := QuestService.claim_quest_seed_reward(slot, "npc_wounded_mystic", "quest_seed_black_water_vow")
	var quest_seed_floor_02_snapshot_after: Dictionary = await _debug_route_snapshot(slot, "dungeon_floor_02", GameApp.MODE_DUNGEON, GameApp.DUNGEON_SOURCE_COMPILED)
	var floor3_gate_after: Dictionary = await _debug_route_transition(slot, "dungeon_floor_02", "dungeon_floor_03", GameApp.DUNGEON_SOURCE_COMPILED)
	var floor3_snapshot_after_unlock: Dictionary = await _debug_route_snapshot(slot, "dungeon_floor_03", GameApp.MODE_DUNGEON, GameApp.DUNGEON_SOURCE_COMPILED)
	var trainer_services_after := NpcService.describe_services_for_slot(slot, "npc_trainer")
	QuestService.on_monster_defeated(slot, "slime_alpha")
	var reward_result: Dictionary = QuestService.claim_reward(slot)
	var final_data: Dictionary = SaveService.load_slot(slot)
	var report: Dictionary = {
		"slot": slot,
		"acceptQuest": accept_result,
		"shopStockBefore": stock_before,
		"shopStockRefresh": stock_refresh,
		"buySkill": buy_result,
		"tradeBuy": trade_result,
		"scholarTalk": scholar_talk_result,
		"trainerServicesBefore": trainer_services_before,
		"townGateBefore": town_gate_before,
		"townGateAfter": town_gate_after,
		"gatekeeperRouteBefore": gatekeeper_route_before,
		"gatekeeperRouteAfter": gatekeeper_route_after,
		"boardOffersBefore": board_offers_before,
		"boardOffersRefresh": board_offers_refresh,
		"scholarTalkChoice": scholar_choice_result,
		"identify": identify_result,
		"equip": equip_result,
		"identifyMask": identify_mask_result,
		"equipMask": equip_mask_result,
		"questSeedAccept": quest_seed_accept,
		"questSeedDungeonSnapshotBefore": quest_seed_dungeon_snapshot_before,
		"fieldMonsterAiProbe": field_ai_probe,
		"fieldMonsterAmbushProbe": field_ambush_probe,
		"fieldMonsterGroupProbe": field_group_probe,
		"fieldMonsterLosProbe": field_los_probe,
		"fieldMonsterDoorLosProbe": field_door_los_probe,
		"fieldMonsterAuthoredGroupProbe": field_authored_group_probe,
		"secretDoorProbe": secret_door_probe,
		"secretDoorPatrolProbe": secret_door_patrol_probe,
		"secondSeedAcceptBefore": second_seed_accept_before,
		"secondSeedFloor02SnapshotBefore": quest_seed_floor_02_snapshot_before,
		"floor3GateBefore": floor3_gate_before,
		"secondSeedAcceptAfter": second_seed_accept_after,
		"secondSeedFloor02SnapshotActive": quest_seed_floor_02_snapshot_active,
		"blackWaterRite": black_water_rite_result,
		"secondSeedFloor02SnapshotReady": quest_seed_floor_02_snapshot_ready,
		"secondSeedClaim": second_seed_claim,
		"secondSeedFloor02SnapshotAfter": quest_seed_floor_02_snapshot_after,
		"floor3GateAfter": floor3_gate_after,
		"floor3SnapshotAfterUnlock": floor3_snapshot_after_unlock,
		"trainerServicesAfter": trainer_services_after,
		"questSeedTownSnapshotReady": quest_seed_town_snapshot_ready,
		"questSeedClaim": quest_seed_claim,
		"recruit": scout_result,
		"fightContext": fight_context,
		"combatSkillIds": combat_skill_ids,
		"combatRollRows": combat_roll_rows,
		"combatItemResults": combat_item_results,
		"combatItemCommandProbe": combat_item_command_probe,
		"combatStateAfterItems": combat_state_after_items,
		"combatSelectionProbe": combat_selection_probe,
		"combatStateBeforeTargetConfirm": combat_state_before_target_confirm,
		"combatStateAfterTargetConfirm": combat_state_after_target_confirm,
		"combatEnemyGuardProbe": combat_enemy_guard_probe,
		"combatEnemyResistProbe": combat_enemy_resist_probe,
		"combatViewModelProbe": combat_view_model_probe,
		"combatVictorySummaryProbe": combat_victory_summary_probe,
		"combatDefeatSummaryProbe": combat_defeat_summary_probe,
		"endingReportProbe": ending_report_probe,
		"defeatProbe": defeat_probe,
		"fightVictory": fight_victory,
		"avoidFight": avoid_fight_result,
		"trapEvent": trap_result,
		"restEvent": rest_result,
		"shrineEvent": shrine_result,
		"altarEvent": altar_result,
		"cacheEvent": cache_result,
		"shopStockAfter": stock_after,
		"rewardClaim": reward_result,
		"knownSkills": final_data.get("knownSkills", []),
		"quest": final_data.get("quest", {}),
		"gold": int(final_data.get("resources", {}).get("gold", 0)),
		"saveVersion": int(final_data.get("saveVersion", 0)),
		"contentVersion": int(final_data.get("contentVersion", 0)),
		"shopState": final_data.get("shopState", {}),
		"companion": final_data.get("companion", {}),
		"npcState": final_data.get("npcState", {}),
		"questSeeds": final_data.get("questSeeds", {}),
		"partyXp": int(final_data.get("partyState", {}).get("partyXp", 0))
	}
	var out_dir: String = _output_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open("%s/domain_smoke_report.json" % out_dir, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	var ok: bool = bool(accept_result.get("ok", false)) \
		and not bool(town_gate_before.get("ok", false)) \
		and String(town_gate_before.get("blockedMessage", "")) == "게시판에서 원정 전표를 받아야 청동 문이 열린다." \
		and bool(town_gate_after.get("ok", false)) \
		and not bool(gatekeeper_route_before.get("open", true)) \
		and String(gatekeeper_route_before.get("blockedMessage", "")) == "게시판에서 원정 전표를 받아야 청동 문이 열린다." \
		and bool(gatekeeper_route_after.get("open", false)) \
		and board_offers_before.size() >= 3 \
		and board_offers_refresh.size() >= 3 \
		and JSON.stringify(board_offers_before) != JSON.stringify(board_offers_refresh) \
		and not stock_before.is_empty() \
		and not stock_refresh.is_empty() \
		and bool(buy_result.get("ok", false)) \
		and bool(trade_result.get("ok", false)) \
		and bool(scholar_talk_result.get("ok", false)) \
		and bool(scholar_choice_result.get("ok", false)) \
		and bool(identify_result.get("ok", false)) \
		and bool(equip_result.get("ok", false)) \
		and bool(identify_mask_result.get("ok", false)) \
		and bool(equip_mask_result.get("ok", false)) \
		and bool(quest_seed_accept.get("ok", false)) \
		and bool(field_ai_probe.get("ok", false)) \
		and String(field_ai_probe.get("before", {}).get("aiState", "")) in ["patrolling", "idle"] \
		and String(field_ai_probe.get("afterPatrol", {}).get("aiState", "")) in ["warning", "patrolling", "approaching"] \
		and String(field_ai_probe.get("afterApproach", {}).get("aiState", "")) in ["approaching", "chasing"] \
		and String(field_ai_probe.get("afterGiveUp", {}).get("aiState", "")) in ["giving_up", "returning"] \
		and String(field_ai_probe.get("afterReturn", {}).get("aiState", "")) in ["patrolling", "returning", "idle"] \
		and bool(field_ambush_probe.get("ok", false)) \
		and String(field_ambush_probe.get("fieldAi", {}).get("behavior", "")) == "ambush" \
		and String(field_ambush_probe.get("before", {}).get("aiState", "")) == "ambushing" \
		and not bool(field_ambush_probe.get("before", {}).get("revealed", true)) \
		and String(field_ambush_probe.get("afterPatrol", {}).get("aiState", "")) in ["ambushing", "warning", "approaching", "chasing", "giving_up"] \
		and String(field_ambush_probe.get("afterApproach", {}).get("aiState", "")) in ["warning", "approaching", "chasing", "giving_up"] \
		and bool(field_ambush_probe.get("afterApproach", {}).get("revealed", false)) \
		and String(field_ambush_probe.get("afterGiveUp", {}).get("aiState", "")) in ["giving_up", "returning"] \
		and String(field_ambush_probe.get("afterReturn", {}).get("aiState", "")) in ["ambushing", "returning", "idle"] \
		and not bool(field_ambush_probe.get("afterReturn", {}).get("revealed", true)) \
		and bool(field_group_probe.get("ok", false)) \
		and String(field_group_probe.get("sourceAlertGroup", "")) != "" \
		and String(field_group_probe.get("sourceAlertGroup", "")) == String(field_group_probe.get("allyAlertGroup", "")) \
		and String(field_group_probe.get("sourceEncounterId", "")) != String(field_group_probe.get("allyEncounterId", "")) \
		and String(field_group_probe.get("allyBefore", {}).get("aiState", "")) in ["idle", "patrolling", "ambushing", "returning"] \
		and String(field_group_probe.get("sourceAfter", {}).get("aiState", "")) in ["warning", "approaching", "chasing"] \
		and String(field_group_probe.get("allyAfter", {}).get("aiState", "")) in ["warning", "approaching", "chasing"] \
		and bool(field_los_probe.get("ok", false)) \
		and String(field_los_probe.get("blockedState", {}).get("aiState", "")) in ["patrolling", "idle"] \
		and String(field_los_probe.get("heardState", {}).get("aiState", "")) in ["warning", "approaching", "chasing"] \
		and String(field_los_probe.get("visibleState", {}).get("aiState", "")) in ["warning", "approaching", "chasing"] \
		and bool(field_door_los_probe.get("ok", false)) \
		and String(field_door_los_probe.get("lockedState", {}).get("aiState", "")) in ["patrolling", "idle"] \
		and String(field_door_los_probe.get("unlockedState", {}).get("aiState", "")) in ["warning", "approaching", "chasing"] \
		and bool(field_authored_group_probe.get("ok", false)) \
		and String(field_authored_group_probe.get("sourceAlertGroup", "")) == "altar_watch" \
		and String(field_authored_group_probe.get("sourceEncounterId", "")) == "encounter_grave_robber" \
		and String(field_authored_group_probe.get("allyEncounterId", "")) == "encounter_serpent_guard" \
		and String(field_authored_group_probe.get("allyAfter", {}).get("aiState", "")) in ["warning", "approaching", "chasing"] \
		and bool(secret_door_probe.get("ok", false)) \
		and bool(secret_door_probe.get("blockedBefore", false)) \
		and not bool(secret_door_probe.get("blockedAfter", true)) \
		and bool(secret_door_patrol_probe.get("ok", false)) \
		and secret_door_patrol_probe.get("blockedState", {}).get("currentCell", []) == [1.0, 5.0] \
		and secret_door_patrol_probe.get("discoveredState", {}).get("currentCell", []) == [1.0, 4.0] \
		and not bool(trainer_services_before[0].get("available", true)) \
		and quest_seed_dungeon_snapshot_before.get("minimap", {}).get("questSeedObjectiveKeys", []).has("1,2") \
		and not bool(second_seed_accept_before.get("ok", false)) \
		and String(second_seed_accept_before.get("message", "")).contains("Required flag") \
		and quest_seed_floor_02_snapshot_before.get("minimap", {}).get("questSeedObjectiveKeys", []).is_empty() \
		and not bool(floor3_gate_before.get("ok", false)) \
		and bool(second_seed_accept_after.get("ok", false)) \
		and quest_seed_floor_02_snapshot_active.get("minimap", {}).get("questSeedObjectiveKeys", []).has("5,2") \
		and bool(black_water_rite_result.get("ok", false)) \
		and quest_seed_floor_02_snapshot_ready.get("minimap", {}).get("questSeedObjectiveKeys", []).has("2,2") \
		and bool(second_seed_claim.get("ok", false)) \
		and quest_seed_floor_02_snapshot_after.get("minimap", {}).get("questSeedObjectiveKeys", []).is_empty() \
		and bool(floor3_gate_after.get("ok", false)) \
		and String(floor3_snapshot_after_unlock.get("minimap", {}).get("mapId", "")) == "dungeon_floor_03" \
		and bool(trainer_services_after[0].get("available", false)) \
		and quest_seed_town_snapshot_ready.get("minimap", {}).get("questSeedObjectiveKeys", []).has("3,4") \
		and bool(quest_seed_claim.get("ok", false)) \
		and bool(scout_result.get("ok", false)) \
		and not fight_context.is_empty() \
		and combat_skill_ids.has(String(buy_result.get("skillId", stock_refresh[0].get("skillId", "")))) \
		and combat_roll_rows.size() == 3 \
		and not combat_roll_rows[0].get("effectOps", []).is_empty() \
		and combat_item_results.size() == 2 \
		and bool(combat_item_command_probe.get("ok", false)) \
		and String(combat_item_command_probe.get("afterPick", {}).get("pendingItemState", {}).get("itemId", "")) == "throwing_knife" \
		and String(combat_item_command_probe.get("afterPick", {}).get("pendingTargetState", {}).get("mode", "")) == "single_enemy" \
		and String(combat_item_command_probe.get("afterPick", {}).get("pendingTargetState", {}).get("source", "")) == "item" \
		and combat_item_command_probe.get("afterUse", {}).get("pendingItemState", {}).is_empty() \
		and combat_state_after_items.get("enemyStatuses", []).has("burning") \
		and not combat_state_after_items.get("frontStatuses", []).has("독") \
		and bool(combat_selection_probe.get("ok", false)) \
		and combat_selection_probe.get("selectedBeforeClear", []).size() == 2 \
		and combat_selection_probe.get("selectedAfterClear", []).is_empty() \
		and JSON.stringify(combat_selection_probe.get("beforeSwap", [])) != JSON.stringify(combat_selection_probe.get("afterSwap", [])) \
		and String(combat_state_before_target_confirm.get("pendingTargetMode", "")) == "single_enemy" \
		and not combat_state_after_target_confirm.get("skillCooldowns", {}).is_empty() \
		and bool(combat_enemy_guard_probe.get("ok", false)) \
		and int(combat_enemy_guard_probe.get("after", {}).get("enemyGuardPoints", 0)) >= 2 \
		and bool(combat_enemy_resist_probe.get("ok", false)) \
		and not combat_enemy_resist_probe.get("after", {}).get("frontStatuses", []).has("독") \
		and String(combat_view_model_probe.get("activeHero", {}).get("name", "")) == "Probe Conan" \
		and int(combat_view_model_probe.get("selectLimit", 0)) == 2 \
		and not combat_view_model_probe.get("enemyCombatProfile", {}).get("turnOps", []).is_empty() \
		and combat_view_model_probe.has("selectedRollIds") \
		and combat_view_model_probe.has("pendingItemState") \
		and bool(combat_victory_summary_probe.get("victory", false)) \
		and String(combat_victory_summary_probe.get("summary", {}).get("monsterId", "")) == "slime_alpha" \
		and String(combat_victory_summary_probe.get("summary", {}).get("monsterInstanceId", "")) == "domain_slime_alpha" \
		and not combat_victory_summary_probe.get("summary", {}).get("rewards", []).is_empty() \
		and bool(combat_defeat_summary_probe.get("defeat", false)) \
		and String(combat_defeat_summary_probe.get("summary", {}).get("monsterId", "")) == "serpent_guard" \
		and int(combat_defeat_summary_probe.get("summary", {}).get("partyHp", 1)) == 0 \
		and bool(ending_report_probe.get("cleared", false)) \
		and String(ending_report_probe.get("message", "")).contains("Blind Priest Defeated") \
		and String(defeat_probe.get("route", "")) == "town" \
		and String(defeat_probe.get("mapId", "")) == "town_square" \
		and int(defeat_probe.get("defeatCount", 0)) >= 1 \
		and int(defeat_probe.get("meta", {}).get("goldPenalty", 0)) >= 0 \
		and fight_victory \
		and bool(avoid_fight_result.get("ok", false)) \
		and bool(trap_result.get("ok", false)) \
		and bool(rest_result.get("ok", false)) \
		and bool(shrine_result.get("ok", false)) \
		and bool(altar_result.get("ok", false)) \
		and bool(cache_result.get("ok", false)) \
		and bool(reward_result.get("ok", false)) \
		and JSON.stringify(stock_before) != JSON.stringify(stock_refresh) \
		and int(final_data.get("inventory", {}).get("bandage", 0)) >= 1 \
		and bool(final_data.get("flags", {}).get("altar_blood_paid", false)) \
		and bool(final_data.get("flags", {}).get("black_water_rite_cleansed", false)) \
		and bool(final_data.get("flags", {}).get("npc_fight_npc_deserter_captain_cleared", false)) \
		and bool(final_data.get("flags", {}).get("quest_seed_black_mural_rewarded", false)) \
		and bool(final_data.get("flags", {}).get("quest_seed_black_water_vow_rewarded", false)) \
		and int(final_data.get("resources", {}).get("torch", 0)) >= 5 \
		and int(final_data.get("partyState", {}).get("partyXp", 0)) >= 20 \
		and bool(final_data.get("npcState", {}).get("identifiedItems", {}).get("black_dagger", false)) \
		and bool(final_data.get("npcState", {}).get("identifiedItems", {}).get("priest_mask", false)) \
		and String(final_data.get("equipment", {}).get("weapon", "")) == "black_dagger" \
		and String(final_data.get("equipment", {}).get("trinket", "")) == "priest_mask" \
		and String(final_data.get("companion", {}).get("name", "")) == "마샤" \
		and String(final_data.get("questSeeds", {}).get("quest_seed_black_mural", {}).get("status", "")) == "rewarded" \
		and String(final_data.get("questSeeds", {}).get("quest_seed_black_water_vow", {}).get("status", "")) == "rewarded" \
		and final_data.get("partyState", {}).get("front", {}).get("statuses", []).has("저주") \
		and not final_data.get("partyState", {}).get("front", {}).get("statuses", []).has("독") \
		and String(final_data.get("quest", {}).get("status", "")) == "claimed"
	_restore_slot(slot, backup)
	_restore_slot(aux_slot, aux_backup)
	_restore_slot(probe_slot, probe_backup)
	print("DOMAIN_SMOKE ok=%s stock_before=%d stock_refresh=%d stock_after=%d" % [ok, stock_before.size(), stock_refresh.size(), stock_after.size()])
	get_tree().quit(0 if ok else 1)

func _run_save_migration_smoke() -> void:
	var test_slots := [2, 3]
	var backups: Dictionary = {}
	for slot in test_slots:
		backups[slot] = _read_slot_text(slot)
	var current_content_version := int(ContentRegistry.get_manifest().get("contentVersion", 0))
	var legacy_ok := _run_legacy_save_migration_check(current_content_version)
	var future_ok := _run_future_content_block_check(current_content_version)
	var editor_fallback_dungeon: Dictionary = await _capture_editor_fallback_snapshot("dungeon_floor_01", "townGateToDungeonEvent", "", {
		"eventChoiceIndices": [1],
		"eventStepIds": ["altar_end"]
	})
	var editor_fallback_town: Dictionary = await _capture_editor_fallback_snapshot("town_square", "tempTownRouteTrainer", "")
	var editor_fallback_town_gatekeeper: Dictionary = await _capture_editor_fallback_snapshot("town_square", "tempTownRouteGatekeeper", "", {
		"npcServiceIndices": [1, 0]
	})
	for slot in test_slots:
		_restore_slot(slot, backups.get(slot, null))
	var report := {
		"currentContentVersion": current_content_version,
		"legacyOk": legacy_ok,
		"futureOk": future_ok,
		"importedRoutePreviewExists": FileAccess.file_exists("res://data/imported/editor_route_preview_report.json"),
		"importedRoutePreviewPath": "res://data/imported/editor_route_preview_report.json",
		"editorFallbackDungeon": editor_fallback_dungeon,
		"editorFallbackTown": editor_fallback_town,
		"editorFallbackTownGatekeeper": editor_fallback_town_gatekeeper
	}
	var out_dir := _output_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open("%s/save_migration_report.json" % out_dir, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("SAVE_MIGRATION_SMOKE legacy_ok=%s future_ok=%s route_preview=%s current_content_version=%d" % [
		legacy_ok,
		future_ok,
		report["importedRoutePreviewExists"],
		current_content_version
	])
	get_tree().quit(0 if legacy_ok \
		and future_ok \
		and bool(report["importedRoutePreviewExists"]) \
		and bool(editor_fallback_dungeon.get("ok", false)) \
		and bool(editor_fallback_town.get("ok", false)) \
		and bool(editor_fallback_town_gatekeeper.get("ok", false)) \
		and _fallback_variant_contains(editor_fallback_dungeon, "eventChoice:1", "Selected choice: 피를 바친다") \
		and _fallback_variant_contains(editor_fallback_dungeon, "eventStep:altar_end", "Selected step: altar_end") \
		and _fallback_variant_contains(editor_fallback_town_gatekeeper, "npcService:1", "Selected service: talk:청동 문에 대해 묻는다") \
		and _fallback_variant_contains(editor_fallback_town_gatekeeper, "npcService:0", "Selected service: route_info:문 상태를 확인한다") else 1)

func _run_smoke() -> void:
	print("SMOKE: title")
	await _capture("01_title.png")
	var defeat_probe_slot := 2
	var defeat_backup: Variant = _read_slot_text(defeat_probe_slot)
	var defeat_probe_snapshot: Dictionary = {}
	SaveService.delete_slot(defeat_probe_slot)
	SaveService.create_default_session(defeat_probe_slot, {
		"name": "Defeat Conan",
		"classId": "wanderer",
		"backgroundId": "outcast",
		"startSupply": "camp_kit"
	})
	var defeat_packed: PackedScene = load("res://scenes/combat/CombatScene.tscn")
	if defeat_packed != null:
		var defeat_scene: Node = defeat_packed.instantiate()
		if defeat_scene.has_method("setup"):
			defeat_scene.call("setup", {
				"slot": defeat_probe_slot,
				"monster_id": "slime_alpha",
				"monster_name": "Slime Alpha",
				"return_route": GameApp.MODE_DUNGEON,
				"return_map_id": "dungeon_floor_01"
			})
		scene_host.add_child(defeat_scene)
		await get_tree().process_frame
		var combat_smoke := _combat_smoke_driver()
		combat_smoke.lose(defeat_scene)
		await get_tree().process_frame
		combat_smoke.recover_in_town(defeat_scene)
		await get_tree().process_frame
		defeat_probe_snapshot = SaveService.load_slot(defeat_probe_slot).get("meta", {}).get("lastDefeat", {})
		await _capture("05_defeat.png")
		defeat_scene.queue_free()
		await get_tree().process_frame
	_restore_slot(defeat_probe_slot, defeat_backup)
	GameApp.start_new_game(1)
	print("SMOKE: town route")
	await get_tree().process_frame
	var town_scene := SceneRouter.current_scene
	var town_snapshot_before: Dictionary = {}
	var dungeon_snapshot_before: Dictionary = {}
	var dungeon_snapshot_after_blood_altar: Dictionary = {}
	var floor_02_snapshot: Dictionary = {}
	var floor_03_snapshot: Dictionary = {}
	var floor_03_after_boss_snapshot: Dictionary = {}
	var town_snapshot_ready_for_seed_turnin: Dictionary = {}
	var town_snapshot_after: Dictionary = {}
	var town_snapshot_after_clear: Dictionary = {}
	var grid_smoke := _grid_scene_smoke_driver()
	var service_smoke := _service_overlay_smoke_driver()
	grid_smoke.accept_quest(town_scene)
	grid_smoke.accept_quest_seed(town_scene)
	grid_smoke.cycle_town_focus(town_scene, 1)
	if town_scene and town_scene.has_method("hud_snapshot"):
		town_snapshot_before = town_scene.call("hud_snapshot")
	grid_smoke.open_service_by_npc(town_scene, "npc_gatekeeper")
	await get_tree().process_frame
	if SceneRouter.modal_layer.get_child_count() > 0:
		var gate_overlay := SceneRouter.modal_layer.get_child(SceneRouter.modal_layer.get_child_count() - 1)
		service_smoke.select_service_type(gate_overlay, "route_info")
	await _capture("02_gatekeeper.png")
	if town_scene and town_scene.has_method("_close_service_overlay"):
		town_scene.call("_close_service_overlay")
	grid_smoke.open_service_by_type(town_scene, "quest_board")
	await get_tree().process_frame
	await _capture("02_quest_board.png")
	if town_scene and town_scene.has_method("_close_service_overlay"):
		town_scene.call("_close_service_overlay")
	grid_smoke.open_inventory(town_scene)
	await _capture("02_inventory.png")
	if town_scene and town_scene.has_method("_close_service_overlay"):
		town_scene.call("_close_service_overlay")
	grid_smoke.move_forward(town_scene)
	grid_smoke.cycle_town_focus(town_scene, 1)
	await _capture("03_town.png")
	grid_smoke.route_dungeon(town_scene)
	print("SMOKE: dungeon route")
	await _capture("04_dungeon.png")
	var dungeon_scene := SceneRouter.current_scene
	if dungeon_scene and dungeon_scene.has_method("hud_snapshot"):
		dungeon_snapshot_before = dungeon_scene.call("hud_snapshot")
	if dungeon_scene and dungeon_scene.has_method("_discover_secret"):
		for placement in dungeon_scene.map_data.get("placements", []):
			if String(placement.get("type", "")) == "secret_door":
				dungeon_scene.call("_discover_secret", placement)
				break
	grid_smoke.trigger_blood_altar(dungeon_scene)
	if dungeon_scene and dungeon_scene.has_method("hud_snapshot"):
		dungeon_snapshot_after_blood_altar = dungeon_scene.call("hud_snapshot")
	grid_smoke.route_to_map(dungeon_scene, "dungeon_floor_02")
	await get_tree().process_frame
	var floor_02_scene := SceneRouter.current_scene
	if floor_02_scene and floor_02_scene.has_method("hud_snapshot"):
		floor_02_snapshot = floor_02_scene.call("hud_snapshot")
	await _capture("04_floor2.png")
	grid_smoke.trigger_event(floor_02_scene, "event_black_water_rite")
	QuestService.claim_quest_seed_reward(1, "npc_wounded_mystic", "quest_seed_black_water_vow")
	grid_smoke.route_to_map(floor_02_scene, "dungeon_floor_03")
	await get_tree().process_frame
	var floor_03_scene := SceneRouter.current_scene
	if floor_03_scene and floor_03_scene.has_method("hud_snapshot"):
		floor_03_snapshot = floor_03_scene.call("hud_snapshot")
	await _capture("04_floor3.png")
	grid_smoke.route_to_map(floor_03_scene, "dungeon_floor_02")
	await get_tree().process_frame
	floor_02_scene = SceneRouter.current_scene
	grid_smoke.route_to_map(floor_02_scene, "dungeon_floor_01")
	await get_tree().process_frame
	dungeon_scene = SceneRouter.current_scene
	grid_smoke.enter_combat(dungeon_scene)
	print("SMOKE: combat route")
	await _capture("05_combat.png")
	var combat_scene := SceneRouter.current_scene
	var combat_smoke := _combat_smoke_driver()
	combat_smoke.win(combat_scene)
	await get_tree().process_frame
	dungeon_scene = SceneRouter.current_scene
	grid_smoke.return_town(dungeon_scene)
	await get_tree().process_frame
	town_scene = SceneRouter.current_scene
	if town_scene and town_scene.has_method("hud_snapshot"):
		town_snapshot_ready_for_seed_turnin = town_scene.call("hud_snapshot")
	grid_smoke.claim_quest_seed_reward(town_scene)
	grid_smoke.claim_reward(town_scene)
	if town_scene and town_scene.has_method("hud_snapshot"):
		town_snapshot_after = town_scene.call("hud_snapshot")
	QuestService.accept_quest_seed(1, "npc_wounded_mystic", "quest_seed_black_water_vow")
	grid_smoke.route_dungeon(town_scene)
	await get_tree().process_frame
	dungeon_scene = SceneRouter.current_scene
	grid_smoke.route_to_map(dungeon_scene, "dungeon_floor_02")
	await get_tree().process_frame
	var post_reward_floor_02_scene := SceneRouter.current_scene
	grid_smoke.trigger_event(post_reward_floor_02_scene, "event_black_water_rite")
	QuestService.claim_quest_seed_reward(1, "npc_wounded_mystic", "quest_seed_black_water_vow")
	grid_smoke.route_to_map(post_reward_floor_02_scene, "dungeon_floor_03")
	await get_tree().process_frame
	var post_reward_floor_03_scene := SceneRouter.current_scene
	if post_reward_floor_03_scene and post_reward_floor_03_scene.has_method("hud_snapshot"):
		floor_03_snapshot = post_reward_floor_03_scene.call("hud_snapshot")
	await _capture("04_floor3.png")
	grid_smoke.enter_combat_by_monster(post_reward_floor_03_scene, "blind_priest")
	await get_tree().process_frame
	var final_combat_scene := SceneRouter.current_scene
	combat_smoke.win(final_combat_scene)
	await get_tree().process_frame
	post_reward_floor_03_scene = SceneRouter.current_scene
	if post_reward_floor_03_scene and post_reward_floor_03_scene.has_method("hud_snapshot"):
		floor_03_after_boss_snapshot = post_reward_floor_03_scene.call("hud_snapshot")
	grid_smoke.return_town(post_reward_floor_03_scene)
	await get_tree().process_frame
	town_scene = SceneRouter.current_scene
	if town_scene and town_scene.has_method("hud_snapshot"):
		town_snapshot_after = town_scene.call("hud_snapshot")
	grid_smoke.open_service_by_npc(town_scene, "npc_scholar")
	await get_tree().process_frame
	if SceneRouter.modal_layer.get_child_count() > 0:
		var scholar_overlay := SceneRouter.modal_layer.get_child(SceneRouter.modal_layer.get_child_count() - 1)
		service_smoke.select_service_type(scholar_overlay, "ending_report")
	if town_scene and town_scene.has_method("hud_snapshot"):
		town_snapshot_after_clear = town_scene.call("hud_snapshot")
	await _capture("06_epilogue.png")
	if town_scene and town_scene.has_method("_close_service_overlay"):
		town_scene.call("_close_service_overlay")
	grid_smoke.open_inventory(town_scene)
	await _capture("06_inventory_rewards.png")
	if town_scene and town_scene.has_method("_close_service_overlay"):
		town_scene.call("_close_service_overlay")
	await _capture("06_reward.png")
	var editor_fallback_dungeon: Dictionary = await _capture_editor_fallback_snapshot("dungeon_floor_01", "townGateToDungeonEvent", "07_editor_fallback_dungeon.png", {
		"eventChoiceIndices": [1],
		"eventStepIds": ["altar_end"]
	})
	var editor_fallback_town: Dictionary = await _capture_editor_fallback_snapshot("town_square", "tempTownRouteTrainer", "07_editor_fallback_town.png")
	var editor_fallback_town_gatekeeper: Dictionary = await _capture_editor_fallback_snapshot("town_square", "tempTownRouteGatekeeper", "", {
		"npcServiceIndices": [1, 0]
	})
	var smoke_slot := SaveService.load_slot(1)
	var report := {
		"content": ContentRegistry.validate_content(),
		"slots": SaveService.list_slots(),
		"route": GameApp.current_mode,
		"dungeonSource": GameApp.dungeon_runtime_source,
		"quest": smoke_slot.get("quest", {}),
		"questSeeds": smoke_slot.get("questSeeds", {}),
		"runtime": smoke_slot.get("runtime", {}),
		"townSnapshotBeforeDungeon": town_snapshot_before,
		"dungeonSnapshotBeforeCombat": dungeon_snapshot_before,
		"dungeonSnapshotAfterBloodAltar": dungeon_snapshot_after_blood_altar,
		"floor02SnapshotAfterUnlock": floor_02_snapshot,
		"floor03SnapshotAfterUnlock": floor_03_snapshot,
		"floor03SnapshotAfterBoss": floor_03_after_boss_snapshot,
		"townSnapshotReadyForSeedTurnIn": town_snapshot_ready_for_seed_turnin,
		"townSnapshotAfterReward": town_snapshot_after,
		"townSnapshotAfterClear": town_snapshot_after_clear,
		"editorFallbackDungeon": editor_fallback_dungeon,
		"editorFallbackTown": editor_fallback_town,
		"editorFallbackTownGatekeeper": editor_fallback_town_gatekeeper,
		"meta": smoke_slot.get("meta", {}),
		"recentRewards": SaveService.recent_rewards(1),
		"defeatProbe": defeat_probe_snapshot
	}
	var out_dir := _output_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open("%s/smoke_report.json" % out_dir, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("SMOKE: done")
	get_tree().quit()

func _run_benchmark_smoke() -> void:
	var slot := 1
	var backup: Variant = _read_slot_text(slot)
	SaveService.delete_slot(slot)
	var benchmark_report := {
		"dungeonBuildMs": -1.0,
		"movementMs": -1.0,
		"combatLoopMs": -1.0,
		"dungeonSnapshotBeforeMove": {},
		"dungeonSnapshotAfterMove": {},
		"combatSnapshot": {},
		"editorFallbackDungeon": {},
		"editorFallbackTown": {},
		"routeAfterCombat": "",
		"ok": false
	}
	GameApp.start_new_game(slot)
	await _await_frames(2)
	var town_scene := SceneRouter.current_scene
	QuestService.accept_quest(slot, "slime_cleanup")
	var grid_smoke := _grid_scene_smoke_driver()
	var dungeon_start := Time.get_ticks_usec()
	grid_smoke.route_dungeon(town_scene)
	await _await_frames(3)
	var dungeon_scene := SceneRouter.current_scene
	benchmark_report["dungeonBuildMs"] = _elapsed_ms(dungeon_start)
	benchmark_report["dungeonSnapshotBeforeMove"] = grid_smoke.benchmark_snapshot(dungeon_scene)
	var movement_start := Time.get_ticks_usec()
	grid_smoke.move_forward(dungeon_scene)
	await _await_frames(1)
	benchmark_report["movementMs"] = _elapsed_ms(movement_start)
	benchmark_report["dungeonSnapshotAfterMove"] = grid_smoke.benchmark_snapshot(dungeon_scene)
	var combat_start := Time.get_ticks_usec()
	grid_smoke.enter_combat(dungeon_scene)
	await _await_frames(1)
	var combat_scene := SceneRouter.current_scene
	var combat_smoke := _combat_smoke_driver()
	benchmark_report["combatSnapshot"] = combat_smoke.combat_state(combat_scene)
	combat_smoke.win(combat_scene)
	await _await_frames(2)
	benchmark_report["combatLoopMs"] = _elapsed_ms(combat_start)
	benchmark_report["routeAfterCombat"] = GameApp.current_mode
	benchmark_report["editorFallbackDungeon"] = await _capture_editor_fallback_snapshot("dungeon_floor_01", "townGateToDungeonEvent", "", {
		"eventChoiceIndices": [1],
		"eventStepIds": ["altar_end"]
	})
	benchmark_report["editorFallbackTown"] = await _capture_editor_fallback_snapshot("town_square", "tempTownRouteTrainer", "")
	benchmark_report["editorFallbackTownGatekeeper"] = await _capture_editor_fallback_snapshot("town_square", "tempTownRouteGatekeeper", "", {
		"npcServiceIndices": [1, 0]
	})
	var before_move: Dictionary = benchmark_report.get("dungeonSnapshotBeforeMove", {})
	var after_move: Dictionary = benchmark_report.get("dungeonSnapshotAfterMove", {})
	benchmark_report["ok"] = float(benchmark_report.get("dungeonBuildMs", -1.0)) >= 0.0 \
		and float(benchmark_report.get("movementMs", -1.0)) >= 0.0 \
		and float(benchmark_report.get("combatLoopMs", -1.0)) >= 0.0 \
		and before_move.get("playerCell", []) != after_move.get("playerCell", []) \
		and bool((benchmark_report.get("editorFallbackDungeon", {}) as Dictionary).get("ok", false)) \
		and bool((benchmark_report.get("editorFallbackTown", {}) as Dictionary).get("ok", false)) \
		and bool((benchmark_report.get("editorFallbackTownGatekeeper", {}) as Dictionary).get("ok", false)) \
		and _fallback_variant_contains(benchmark_report.get("editorFallbackDungeon", {}) as Dictionary, "eventChoice:1", "Selected choice: 피를 바친다") \
		and _fallback_variant_contains(benchmark_report.get("editorFallbackDungeon", {}) as Dictionary, "eventStep:altar_end", "Selected step: altar_end") \
		and _fallback_variant_contains(benchmark_report.get("editorFallbackTownGatekeeper", {}) as Dictionary, "npcService:1", "Selected service: talk:청동 문에 대해 묻는다") \
		and _fallback_variant_contains(benchmark_report.get("editorFallbackTownGatekeeper", {}) as Dictionary, "npcService:0", "Selected service: route_info:문 상태를 확인한다") \
		and String(benchmark_report.get("routeAfterCombat", "")) == GameApp.MODE_DUNGEON
	var out_dir := _output_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open("%s/benchmark_report.json" % out_dir, FileAccess.WRITE)
	file.store_string(JSON.stringify(benchmark_report, "\t"))
	_restore_slot(slot, backup)
	print("BENCHMARK_SMOKE ok=%s dungeon_ms=%.3f move_ms=%.3f combat_ms=%.3f" % [
		benchmark_report["ok"],
		benchmark_report["dungeonBuildMs"],
		benchmark_report["movementMs"],
		benchmark_report["combatLoopMs"]
	])
	get_tree().quit(0 if bool(benchmark_report["ok"]) else 1)

func _run_content_import_smoke() -> void:
	ContentRegistry.load_all()
	var validation := ContentRegistry.validate_content()
	var imported_manifest := ContentRegistry._load_json(ContentRegistry.IMPORTED_MANIFEST_PATH)
	var map_ids := ["town_square", "dungeon_floor_01", "dungeon_floor_02", "dungeon_floor_03"]
	var compiled_maps: Array[Dictionary] = []
	for map_id in map_ids:
		compiled_maps.append(ContentRegistry.get_map(map_id))
	var required_definition_kinds := [
		"monsters",
		"skills",
		"items",
		"quests",
		"events",
		"npcs",
		"vendors",
		"map_profiles",
		"materials"
	]
	var required_ok := true
	var definition_counts := {}
	for kind in required_definition_kinds:
		var rows: Array[Dictionary] = ContentRegistry.list_definitions(kind)
		definition_counts[kind] = rows.size()
		if rows.is_empty():
			required_ok = false
	var report := {
		"validation": validation,
		"importedManifestExists": FileAccess.file_exists(ContentRegistry.IMPORTED_MANIFEST_PATH),
		"importedManifestPath": ContentRegistry.IMPORTED_MANIFEST_PATH,
		"sourceManifestPath": ContentRegistry.SOURCE_MANIFEST_PATH,
		"importedRoutePreviewExists": FileAccess.file_exists("res://data/imported/editor_route_preview_report.json"),
		"importedRoutePreviewPath": "res://data/imported/editor_route_preview_report.json",
		"activeManifestPath": String(validation.get("manifestPath", "")),
		"importedManifestContentVersion": int(imported_manifest.get("contentVersion", 0)),
		"compiledMapIds": compiled_maps.map(func(row: Dictionary) -> String: return String(row.get("id", ""))),
		"compiledMapPreviewCounts": compiled_maps.map(func(row: Dictionary) -> int: return row.get("compiledPreview", {}).get("generatedCells", []).size()),
		"definitionCounts": definition_counts
	}
	report["editorFallbackDungeon"] = await _capture_editor_fallback_snapshot("dungeon_floor_01", "townGateToDungeonEvent", "", {
		"eventChoiceIndices": [1],
		"eventStepIds": ["altar_end"]
	})
	report["editorFallbackTown"] = await _capture_editor_fallback_snapshot("town_square", "tempTownRouteTrainer", "")
	report["editorFallbackTownGatekeeper"] = await _capture_editor_fallback_snapshot("town_square", "tempTownRouteGatekeeper", "", {
		"npcServiceIndices": [1, 0]
	})
	report["ok"] = bool(validation.get("ok", false)) \
		and bool(report["importedManifestExists"]) \
		and bool(report["importedRoutePreviewExists"]) \
		and String(report["activeManifestPath"]) == ContentRegistry.IMPORTED_MANIFEST_PATH \
		and int(report["importedManifestContentVersion"]) > 0 \
		and report["compiledMapIds"] == map_ids \
		and int(report["compiledMapPreviewCounts"][1]) > 0 \
		and int(report["compiledMapPreviewCounts"][2]) > 0 \
		and int(report["compiledMapPreviewCounts"][3]) > 0 \
		and bool((report.get("editorFallbackDungeon", {}) as Dictionary).get("ok", false)) \
		and bool((report.get("editorFallbackTown", {}) as Dictionary).get("ok", false)) \
		and bool((report.get("editorFallbackTownGatekeeper", {}) as Dictionary).get("ok", false)) \
		and _fallback_variant_contains(report.get("editorFallbackDungeon", {}) as Dictionary, "eventChoice:1", "Selected choice: 피를 바친다") \
		and _fallback_variant_contains(report.get("editorFallbackDungeon", {}) as Dictionary, "eventStep:altar_end", "Selected step: altar_end") \
		and _fallback_variant_contains(report.get("editorFallbackTownGatekeeper", {}) as Dictionary, "npcService:1", "Selected service: talk:청동 문에 대해 묻는다") \
		and _fallback_variant_contains(report.get("editorFallbackTownGatekeeper", {}) as Dictionary, "npcService:0", "Selected service: route_info:문 상태를 확인한다") \
		and required_ok
	var out_dir := _output_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open("%s/content_import_report.json" % out_dir, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CONTENT_IMPORT_SMOKE ok=%s manifest=%s generated_cells=%d route_preview=%s" % [
		report["ok"],
		report["activeManifestPath"],
		int(report["compiledMapPreviewCounts"][1]),
		report["importedRoutePreviewExists"]
	])
	get_tree().quit(0 if bool(report["ok"]) else 1)

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("SMOKE: capture skipped for %s on headless display" % file_name)
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		print("SMOKE: capture skipped for %s because viewport texture is null" % file_name)
		return
	var image := texture.get_image()
	if image == null:
		print("SMOKE: capture skipped for %s because viewport image is null" % file_name)
		return
	var path := "%s/%s" % [_output_dir(), file_name]
	var error := image.save_png(path)
	print("SMOKE: capture %s error=%s size=%s" % [path, error, image.get_size()])

func _output_dir() -> String:
	if GameApp.smoke_output_dir != "":
		return GameApp.smoke_output_dir
	return ProjectSettings.globalize_path("res://output")

func _await_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0

func _grid_scene_smoke_driver() -> RefCounted:
	var script: Script = load("res://scripts/tests/grid_scene_smoke_driver.gd")
	return script.new()

func _combat_smoke_driver() -> RefCounted:
	var script: Script = load("res://scripts/tests/combat_smoke_driver.gd")
	return script.new()

func _service_overlay_smoke_driver() -> RefCounted:
	var script: Script = load("res://scripts/tests/service_overlay_smoke_driver.gd")
	return script.new()

func _debug_route_snapshot(slot: int, map_id: String, route: String, dungeon_source: String) -> Dictionary:
	var scene_path := "res://scenes/town/TownScene.tscn"
	if route == GameApp.MODE_DUNGEON:
		scene_path = "res://scenes/dungeon/DungeonScene.tscn"
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return {}
	var scene: Node = packed.instantiate()
	SceneRouter.scene_host.add_child(scene)
	if scene.has_method("setup"):
		scene.call("setup", {
			"slot": slot,
			"map_id": map_id,
			"dungeon_source": dungeon_source
		})
	var snapshot: Dictionary = {}
	if scene.has_method("hud_snapshot"):
		snapshot = scene.call("hud_snapshot")
	scene.queue_free()
	await get_tree().process_frame
	return snapshot

func _debug_route_transition(slot: int, start_map_id: String, target_map_id: String, dungeon_source: String) -> Dictionary:
	var packed: PackedScene = load("res://scenes/dungeon/DungeonScene.tscn")
	if packed == null:
		return {}
	var scene: Node = packed.instantiate()
	SceneRouter.scene_host.add_child(scene)
	if scene.has_method("setup"):
		scene.call("setup", {
			"slot": slot,
			"map_id": start_map_id,
			"dungeon_source": dungeon_source
		})
	var grid_smoke := _grid_scene_smoke_driver()
	var result: Dictionary = grid_smoke.route_probe(scene, target_map_id)
	if SceneRouter.current_scene != null and SceneRouter.current_scene != scene and SceneRouter.current_scene.has_method("hud_snapshot"):
		result["snapshot"] = SceneRouter.current_scene.call("hud_snapshot")
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame
	return result

func _capture_editor_fallback_snapshot(map_id: String, route_entry: String, file_name: String, options: Dictionary = {}) -> Dictionary:
	var packed: PackedScene = EDITOR_WORKSPACE_SCENE
	if packed == null:
		return {"ok": false, "message": "Missing EditorWorkspace scene."}
	var workspace: Control = packed.instantiate()
	SceneRouter.scene_host.add_child(workspace)
	await get_tree().process_frame
	if workspace.has_method("smoke_set_selected_map"):
		workspace.call("smoke_set_selected_map", map_id)
	await get_tree().process_frame
	var selected_ok := false
	if workspace.has_method("smoke_set_route_preview_entry"):
		selected_ok = bool(workspace.call("smoke_set_route_preview_entry", route_entry))
	await get_tree().process_frame
	if file_name != "":
		await _capture(file_name)
	var result := {
		"ok": selected_ok,
		"mapId": map_id,
		"routeEntry": route_entry,
		"summary": "",
		"detail": "",
		"variants": {}
	}
	if workspace.has_method("smoke_get_summary_text"):
		result["summary"] = String(workspace.call("smoke_get_summary_text"))
	if workspace.has_method("smoke_get_route_preview_detail_text"):
		result["detail"] = String(workspace.call("smoke_get_route_preview_detail_text"))
	var variants: Dictionary = {}
	var event_choice_indices: Array = options.get("eventChoiceIndices", [])
	for index_variant in event_choice_indices:
		var index := int(index_variant)
		var variant_key := "eventChoice:%d" % index
		var switch_ok := false
		if workspace.has_method("smoke_set_route_target_event_choice_index"):
			switch_ok = bool(workspace.call("smoke_set_route_target_event_choice_index", index))
		await get_tree().process_frame
		variants[variant_key] = {
			"ok": switch_ok,
			"detail": String(workspace.call("smoke_get_route_preview_detail_text")) if workspace.has_method("smoke_get_route_preview_detail_text") else ""
		}
	var event_step_ids: Array = options.get("eventStepIds", [])
	for step_variant in event_step_ids:
		var step_id := String(step_variant)
		var variant_key := "eventStep:%s" % step_id
		var switch_ok := false
		if workspace.has_method("smoke_set_route_target_event_step_id"):
			switch_ok = bool(workspace.call("smoke_set_route_target_event_step_id", step_id))
		await get_tree().process_frame
		variants[variant_key] = {
			"ok": switch_ok,
			"detail": String(workspace.call("smoke_get_route_preview_detail_text")) if workspace.has_method("smoke_get_route_preview_detail_text") else ""
		}
	var npc_service_indices: Array = options.get("npcServiceIndices", [])
	for index_variant in npc_service_indices:
		var index := int(index_variant)
		var variant_key := "npcService:%d" % index
		var switch_ok := false
		if workspace.has_method("smoke_set_route_target_service_index"):
			switch_ok = bool(workspace.call("smoke_set_route_target_service_index", index))
		await get_tree().process_frame
		variants[variant_key] = {
			"ok": switch_ok,
			"detail": String(workspace.call("smoke_get_route_preview_detail_text")) if workspace.has_method("smoke_get_route_preview_detail_text") else ""
		}
	if not variants.is_empty():
		result["variants"] = variants
		for variant in variants.values():
			if typeof(variant) == TYPE_DICTIONARY:
				result["ok"] = bool(result["ok"]) and bool((variant as Dictionary).get("ok", false))
	workspace.queue_free()
	await get_tree().process_frame
	return result

func _fallback_variant_contains(snapshot: Dictionary, variant_key: String, expected_text: String) -> bool:
	var variants: Dictionary = snapshot.get("variants", {})
	if expected_text == "":
		return bool((variants.get(variant_key, {}) as Dictionary).get("ok", false))
	var variant: Dictionary = variants.get(variant_key, {})
	return bool(variant.get("ok", false)) and String(variant.get("detail", "")).contains(expected_text)

func _find_service_by_type(services: Array[Dictionary], service_type: String) -> Dictionary:
	for service in services:
		if String(service.get("type", "")) == service_type:
			return service
	return {}

func _run_legacy_save_migration_check(current_content_version: int) -> bool:
	var legacy_slot := 2
	var legacy_data := {
		"slot": legacy_slot,
		"slotName": "Legacy Conan",
		"saveVersion": 0,
		"contentVersion": 0,
		"player": {
			"name": "Legacy Conan"
		},
		"resources": {
			"gold": 12
		},
		"mode": "dungeon",
		"runtime": {
			"mapId": "dungeon_floor_01",
			"fieldMonsters": {
				"legacy_guard": {
					"defeated": false
				}
			}
		}
	}
	_write_json(SaveService.slot_path(legacy_slot), legacy_data)
	var inspection := SaveService.inspect_slot(legacy_slot)
	var migrated: Dictionary = inspection.get("data", {})
	var summary := SaveService.slot_summary(legacy_slot)
	var messages: Array = inspection.get("messages", [])
	var first_message := String(messages[0]) if not messages.is_empty() else ""
	return (
		not migrated.is_empty()
		and int(migrated.get("saveVersion", 0)) == SaveService.SAVE_SCHEMA_VERSION
		and int(migrated.get("contentVersion", 0)) == current_content_version
		and typeof(migrated.get("flags", null)) == TYPE_DICTIONARY
		and typeof(migrated.get("npcState", null)) == TYPE_DICTIONARY
		and typeof(migrated.get("floorState", null)) == TYPE_DICTIONARY
		and typeof(migrated.get("runtimeMaps", null)) == TYPE_DICTIONARY
		and typeof(migrated.get("visitedMapIds", null)) == TYPE_ARRAY
		and String(migrated.get("runtime", {}).get("dungeonSource", "")) == GameApp.DUNGEON_SOURCE_COMPILED
		and typeof(migrated.get("runtime", {}).get("visitedCells", null)) == TYPE_DICTIONARY
		and bool(inspection.get("migrated", false))
		and not bool(summary.get("blocked", false))
		and first_message.contains("Migrated save schema")
	)

func _run_future_content_block_check(current_content_version: int) -> bool:
	var future_slot := 3
	var future_data := SaveService.build_default_session(future_slot, {
		"name": "Future Conan",
		"classId": "wanderer",
		"backgroundId": "outcast",
		"startSupply": "camp_kit"
	})
	future_data["contentVersion"] = current_content_version + 10
	_write_json(SaveService.slot_path(future_slot), future_data)
	var inspection := SaveService.inspect_slot(future_slot)
	var messages: Array = inspection.get("messages", [])
	return (
		bool(inspection.get("exists", false))
		and bool(inspection.get("blocked", false))
		and not messages.is_empty()
		and SaveService.load_slot(future_slot).is_empty()
	)

func _read_slot_text(slot: int) -> Variant:
	var path := SaveService.slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return file.get_as_text()

func _restore_slot(slot: int, text: Variant) -> void:
	var path := SaveService.slot_path(slot)
	if text == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(String(text))

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))

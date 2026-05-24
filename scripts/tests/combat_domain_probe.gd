extends SceneTree

const CombatRuntime = preload("res://scripts/runtime/combat_runtime.gd")
const CombatSmokeDriver = preload("res://scripts/tests/combat_smoke_driver.gd")
const PROBE_SLOT := 3

var failures: Array[String] = []
var slot_backups: Dictionary = {}
var combat_smoke := CombatSmokeDriver.new()

func _initialize() -> void:
	_content_registry().call("load_all")
	_backup_slot(PROBE_SLOT)
	_prepare_probe_slot()
	_probe_skill_effect_ops()
	_probe_item_combat_use()
	_probe_enemy_profiles()
	_restore_slot(PROBE_SLOT)
	for failure in failures:
		print("COMBAT_DOMAIN_PROBE_FAIL %s" % failure)
	var ok := failures.is_empty()
	print("COMBAT_DOMAIN_PROBE ok=%s failures=%d" % [str(ok), failures.size()])
	quit(0 if ok else 1)

func _prepare_probe_slot() -> void:
	_save_service().call("create_default_session", PROBE_SLOT, {
		"name": "Combat Probe",
		"classId": "wanderer",
		"backgroundId": "outcast",
		"startSupply": "camp_kit"
	})
	var data: Dictionary = _save_service().call("load_slot", PROBE_SLOT)
	data["knownSkills"] = [
		"basic_strike",
		"guard_break",
		"mending_chant",
		"skill_vital_stab",
		"skill_bastion_vow"
	]
	data["inventory"] = {
		"firebomb": 2,
		"antivenom": 2,
		"healing_tonic": 1,
		"priest_mask": 1
	}
	data["npcState"] = {
		"identifiedItems": {
			"priest_mask": true
		}
	}
	_save_service().call("save_slot", PROBE_SLOT, data)
	_save_service().call("equip_item", PROBE_SLOT, "priest_mask")
	_save_service().call("update_front_state", PROBE_SLOT, 14, 20, ["독"])

func _probe_skill_effect_ops() -> void:
	var guard_break: Dictionary = combat_smoke.runtime_skill_effect_probe(_runtime("serpent_guard"), "guard_break", 6, {
		"enemyHp": 28,
		"enemyGuardPoints": 0,
		"weaponBonus": 0
	})
	_expect(bool(guard_break.get("ok", false)), "guard_break probe should run")
	_expect(int(guard_break.get("damage", 0)) >= 5, "guard_break should deal armor-adjusted damage")
	_expect(int(guard_break.get("after", {}).get("enemyArmorBreak", 0)) >= 2, "guard_break should increase enemy armor break")
	_expect(guard_break.get("after", {}).get("enemyStatuses", []).has("weakened"), "guard_break should apply weakened")

	var lifesteal: Dictionary = combat_smoke.runtime_skill_effect_probe(_runtime("serpent_guard"), "skill_vital_stab", 6, {
		"partyHp": 10,
		"enemyHp": 28,
		"enemyGuardPoints": 0,
		"weaponBonus": 0
	})
	_expect(bool(lifesteal.get("ok", false)), "vital stab probe should run")
	_expect(int(lifesteal.get("after", {}).get("partyHp", 0)) > int(lifesteal.get("before", {}).get("partyHp", 0)), "lifesteal should restore party HP")
	_expect(int(lifesteal.get("after", {}).get("enemyHp", 99)) < int(lifesteal.get("before", {}).get("enemyHp", 0)), "lifesteal should damage enemy")

	var heal: Dictionary = combat_smoke.runtime_skill_effect_probe(_runtime("serpent_guard"), "mending_chant", 4, {
		"partyHp": 8,
		"enemyHp": 28,
		"enemyGuardPoints": 0
	})
	_expect(bool(heal.get("ok", false)), "mending chant probe should run")
	_expect(int(heal.get("after", {}).get("partyHp", 0)) > int(heal.get("before", {}).get("partyHp", 0)), "heal skill should restore party HP")
	_expect(int(heal.get("after", {}).get("enemyHp", 0)) == int(heal.get("before", {}).get("enemyHp", -1)), "heal skill should not damage enemy")

	var guard: Dictionary = combat_smoke.runtime_skill_effect_probe(_runtime("serpent_guard"), "skill_bastion_vow", 5, {
		"partyHp": 14,
		"enemyHp": 28,
		"guardPoints": 0
	})
	_expect(bool(guard.get("ok", false)), "bastion vow probe should run")
	_expect(int(guard.get("after", {}).get("guardPoints", 0)) > int(guard.get("before", {}).get("guardPoints", 0)), "guard skill should add party guard")

func _probe_item_combat_use() -> void:
	var fire_runtime := _runtime("serpent_guard")
	var firebomb: Dictionary = combat_smoke.runtime_use_item(fire_runtime, "firebomb")
	var fire_state: Dictionary = combat_smoke.runtime_combat_state(fire_runtime)
	_expect(bool(firebomb.get("refresh", false)), "firebomb should resolve without ending combat")
	_expect(fire_state.get("enemyStatuses", []).has("burning"), "firebomb should apply burning")
	_expect(int(fire_state.get("enemyHp", 99)) < 28, "firebomb should damage enemy")
	_expect(int((_save_service().call("inventory", PROBE_SLOT) as Dictionary).get("firebomb", 0)) == 1, "firebomb should consume one item")

	_save_service().call("update_front_state", PROBE_SLOT, 14, 20, ["독"])
	var antivenom_runtime := _runtime("poisoned_raider")
	var antivenom: Dictionary = combat_smoke.runtime_use_item(antivenom_runtime, "antivenom")
	var antivenom_state: Dictionary = combat_smoke.runtime_combat_state(antivenom_runtime)
	_expect(bool(antivenom.get("refresh", false)), "antivenom should resolve without ending combat")
	_expect(not antivenom_state.get("frontStatuses", []).has("독"), "antivenom should cure poison")
	_expect(int((_save_service().call("inventory", PROBE_SLOT) as Dictionary).get("antivenom", 0)) == 1, "antivenom should consume one item")

func _probe_enemy_profiles() -> void:
	_set_front_state(20, 20, [])
	var guard_runtime := _runtime("serpent_guard")
	var guard_probe: Dictionary = combat_smoke.runtime_enemy_turn_probe(guard_runtime)
	_expect(bool(guard_probe.get("ok", false)), "guardian profile probe should run")
	_expect(int(guard_probe.get("after", {}).get("enemyGuardPoints", 0)) >= 2, "guardian profile should add or preserve enemy guard")

	_set_front_state(20, 20, [])
	var resist_runtime := _runtime("poisoned_raider")
	var resist_probe: Dictionary = combat_smoke.runtime_enemy_turn_probe(resist_runtime)
	_expect(bool(resist_probe.get("ok", false)), "ambusher profile probe should run")
	_expect(not resist_probe.get("after", {}).get("frontStatuses", []).has("독"), "priest mask should resist ambusher poison")

	var coward_runtime := _runtime("grave_robber")
	var coward_probe: Dictionary = combat_smoke.runtime_skill_effect_probe(coward_runtime, "basic_strike", 1, {
		"enemyHp": 7,
		"enemyMaxHp": 22,
		"enemyGuardPoints": 0
	})
	coward_runtime.stop_dice()
	var coward_before: Dictionary = combat_smoke.runtime_combat_state(coward_runtime)
	coward_runtime.call("_run_enemy_turn")
	var coward_after: Dictionary = combat_smoke.runtime_combat_state(coward_runtime)
	_expect(bool(coward_probe.get("ok", false)), "coward setup probe should run")
	_expect(int(coward_after.get("enemyHp", 0)) > int(coward_before.get("enemyHp", 0)), "coward profile should heal when low")
	_expect(int(coward_after.get("enemyGuardPoints", 0)) > int(coward_before.get("enemyGuardPoints", 0)), "coward profile should hide behind guard")

func _runtime(monster_id: String) -> RefCounted:
	var runtime := CombatRuntime.new()
	runtime.setup({
		"slot": PROBE_SLOT,
		"monster_id": monster_id,
		"monster_instance_id": "probe_%s" % monster_id,
		"return_map_id": "dungeon_floor_01"
	})
	return runtime

func _backup_slot(slot: int) -> void:
	slot_backups.clear()
	for path in [
		String(_save_service().call("slot_path", slot)),
		String(_save_service().call("slot_temp_path", slot)),
		String(_save_service().call("slot_backup_path", slot))
	]:
		slot_backups[path] = _read_text(path)

func _restore_slot(_slot: int) -> void:
	for path in slot_backups.keys():
		var text := String(slot_backups[path])
		if text == "":
			var absolute := ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(absolute)
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(text)

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

func _set_front_state(hp: int, max_hp: int, statuses: Array) -> void:
	var data: Dictionary = _save_service().call("load_slot", PROBE_SLOT)
	var party_state: Dictionary = data.get("partyState", {})
	var front: Dictionary = party_state.get("front", {})
	front["hp"] = hp
	front["maxHp"] = max_hp
	front["statuses"] = statuses.duplicate()
	party_state["front"] = front
	data["partyState"] = party_state
	_save_service().call("save_slot", PROBE_SLOT, data)

func _save_service() -> Node:
	return root.get_node("SaveService")

func _content_registry() -> Node:
	return root.get_node("ContentRegistry")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

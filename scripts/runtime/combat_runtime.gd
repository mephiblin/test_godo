extends RefCounted

const CombatViewModelBuilder = preload("res://scripts/runtime/combat_view_model_builder.gd")

var enemy_name := "Slime Alpha"
var enemy_ai := "aggressive"
var enemy_combat_profile: Dictionary = {}
var return_route := GameApp.MODE_DUNGEON
var return_map_id := "dungeon_floor_01"
var monster_id := ""
var monster_instance_id := ""
var spinning := true
var selected_roll_ids: Array[int] = []
var rolls: Array[Dictionary] = []
var party_hp := 20
var enemy_hp := 18
var enemy_max_hp := 18
var slot := 1
var weapon_bonus := 0
var curse_penalty := 0
var enemy_attack_min := 1
var enemy_attack_max := 4
var enemy_armor := 0
var party_max_hp := 20
var front_statuses: Array[String] = []
var known_skill_ids: Array[String] = []
var combat_log: Array[String] = []
var guard_points := 0
var enemy_guard_points := 0
var enemy_armor_break := 0
var enemy_statuses: Array[String] = []
var pending_item_id := ""
var pending_target_mode := ""
var pending_skill_target_mode := ""
var pending_target_id := ""
var pending_skill_roll_ids: Array[int] = []
var skill_cooldowns: Dictionary = {}
var enemy_turn_index := 0

const SELECT_LIMIT := 2

func setup(payload: Dictionary) -> void:
	front_statuses.clear()
	known_skill_ids.clear()
	combat_log.clear()
	guard_points = 0
	enemy_guard_points = 0
	enemy_armor_break = 0
	enemy_statuses.clear()
	pending_item_id = ""
	pending_target_mode = ""
	pending_skill_target_mode = ""
	pending_target_id = ""
	pending_skill_roll_ids.clear()
	skill_cooldowns.clear()
	enemy_turn_index = 0
	weapon_bonus = 0
	curse_penalty = 0
	enemy_attack_min = 1
	enemy_attack_max = 4
	enemy_armor = 0
	enemy_ai = "aggressive"
	enemy_combat_profile = {}
	enemy_name = String(payload.get("monster_name", enemy_name))
	return_route = String(payload.get("return_route", return_route))
	return_map_id = String(payload.get("return_map_id", return_map_id))
	monster_id = String(payload.get("monster_id", ""))
	monster_instance_id = String(payload.get("monster_instance_id", monster_id))
	slot = int(payload.get("slot", GameApp.current_slot))
	var monster_def := ContentRegistry.get_definition("monsters", monster_id)
	if not monster_def.is_empty():
		enemy_name = String(monster_def.get("name", enemy_name))
		enemy_hp = maxi(int(monster_def.get("maxHp", monster_def.get("hp", enemy_hp))), 1)
		enemy_max_hp = enemy_hp
		enemy_attack_min = maxi(int(monster_def.get("attackMin", monster_def.get("atkMin", enemy_attack_min))), 0)
		enemy_attack_max = maxi(int(monster_def.get("attackMax", monster_def.get("atkMax", monster_def.get("atk", enemy_attack_max)))), enemy_attack_min)
		enemy_armor = maxi(int(monster_def.get("def", 0)), 0)
		enemy_ai = String(monster_def.get("ai", enemy_ai))
		enemy_combat_profile = _combat_profile_for_monster(monster_def)
		enemy_guard_points = maxi(int(enemy_combat_profile.get("startingGuard", _default_enemy_guard(enemy_ai))), 0)
	else:
		enemy_max_hp = enemy_hp
	var front_state := SaveService.front_state(slot)
	party_max_hp = maxi(int(front_state.get("maxHp", 20)), 1)
	party_hp = clampi(int(front_state.get("hp", party_max_hp)), 1, party_max_hp)
	for status_variant in front_state.get("statuses", []):
		var status := String(status_variant)
		if status != "":
			front_statuses.append(status)
	known_skill_ids = SaveService.known_skills(slot)
	var equipment_data: Dictionary = SaveService.equipment(slot)
	var weapon_id := String(equipment_data.get("weapon", ""))
	var weapon_def := ContentRegistry.get_definition("items", weapon_id)
	weapon_bonus = int(weapon_def.get("powerBonus", 0))
	curse_penalty = 1 if String(weapon_def.get("curseStatus", "")) != "" else 0
	combat_log = ["Encountered %s." % enemy_name]
	if enemy_guard_points > 0:
		combat_log.append("%s started with %d guard." % [enemy_name, enemy_guard_points])
	_reset_rolls()

func tick_spinning() -> void:
	if not spinning:
		return
	for roll in rolls:
		roll["value"] = randi_range(1, 6)

func build_view_model() -> Dictionary:
	return CombatViewModelBuilder.build(self)

func toggle_roll(index: int) -> void:
	if spinning:
		return
	var roll: Dictionary = rolls[index]
	if int(roll.get("cooldownRemaining", 0)) > 0:
		combat_log.append("%s is on cooldown." % String(roll.get("skillName", "Skill")))
		return
	if selected_roll_ids.has(index):
		selected_roll_ids.erase(index)
	else:
		if selected_roll_ids.size() >= SELECT_LIMIT:
			return
		selected_roll_ids.append(index)
	_refresh_selected_orders()

func stop_dice() -> void:
	spinning = false
	_tick_skill_cooldowns()
	for roll in rolls:
		var cooldown_key := String(roll.get("cooldownKey", ""))
		roll["cooldownRemaining"] = int(skill_cooldowns.get(cooldown_key, 0))
		roll["spinState"] = "stopped"

func confirm_selection() -> Dictionary:
	if pending_item_id != "":
		return use_item()
	if pending_skill_target_mode != "":
		return select_target("enemy_0")
	if spinning or selected_roll_ids.is_empty():
		return {}
	var target_required := false
	for selected_id in selected_roll_ids:
		var selected_roll: Dictionary = rolls[selected_id]
		if String(selected_roll.get("targetMode", "single_enemy")) == "single_enemy":
			target_required = true
			break
	if target_required:
		pending_skill_target_mode = "single_enemy"
		pending_target_id = ""
		pending_skill_roll_ids = selected_roll_ids.duplicate()
		combat_log.append("Target ready for %s. Use SelectTarget to resolve." % enemy_name)
		return {"refresh": true}
	return _resolve_selected_rolls(selected_roll_ids.duplicate())

func clear_selection() -> void:
	selected_roll_ids.clear()
	pending_skill_roll_ids.clear()
	pending_skill_target_mode = ""
	pending_target_id = ""
	_clear_pending_item()
	_refresh_selected_orders()
	combat_log.append("Selection cleared.")

func swap_selected_rolls() -> void:
	if spinning:
		return
	if selected_roll_ids.size() != 2:
		combat_log.append("Swap requires exactly two selected rolls.")
		return
	var first_index := int(selected_roll_ids[0])
	var second_index := int(selected_roll_ids[1])
	var swap_keys := [
		"faceIndex", "skillId", "skillName", "kind", "effectKind", "power",
		"guardBonus", "healBonus", "armorBreak", "lifestealRatio", "targetMode",
		"cooldownKey", "cooldownTurns", "cooldownRemaining", "value"
	]
	var first_roll: Dictionary = rolls[first_index]
	var second_roll: Dictionary = rolls[second_index]
	for key in swap_keys:
		var temp: Variant = first_roll.get(key)
		first_roll[key] = second_roll.get(key)
		second_roll[key] = temp
	rolls[first_index] = first_roll
	rolls[second_index] = second_roll
	combat_log.append("Swapped selected rolls.")

func flee() -> Dictionary:
	combat_log.append("Retreated from combat.")
	_persist_party_state()
	return {"exit": true, "victory": false}

func build_defeat_summary() -> Dictionary:
	return {
		"enemyName": enemy_name,
		"monsterId": monster_id,
		"mapId": return_map_id,
		"partyHp": party_hp,
		"partyMaxHp": party_max_hp,
		"gold": int(SaveService.load_slot(slot).get("resources", {}).get("gold", 0)),
		"statuses": front_statuses.duplicate(),
		"logTail": combat_log.slice(maxi(combat_log.size() - 4, 0), combat_log.size())
	}

func pick_item(item_id: String) -> Dictionary:
	var item_def := ContentRegistry.get_definition("items", item_id)
	if item_def.is_empty():
		return {}
	var combat_use: Dictionary = item_def.get("combatUse", {})
	if combat_use.is_empty():
		return {}
	if not SaveService.has_inventory_item(slot, item_id, 1):
		combat_log.append("Missing %s." % String(item_def.get("name", item_id)))
		return {}
	pending_item_id = item_id
	pending_target_mode = String(combat_use.get("targetMode", "self"))
	pending_target_id = ""
	combat_log.append("Prepared %s." % String(item_def.get("name", item_id)))
	if pending_target_mode == "self":
		combat_log.append("Use UseItem to consume it.")
	else:
		combat_log.append("Use SelectTarget to resolve it.")
	return {"refresh": true}

func queue_item(item_id: String) -> Dictionary:
	return pick_item(item_id)

func use_item() -> Dictionary:
	if pending_item_id == "":
		return {}
	if pending_target_mode == "single_enemy" and pending_target_id == "":
		combat_log.append("Select a target first.")
		return {"refresh": true}
	return _use_pending_item()

func select_target(target_id: String) -> Dictionary:
	if pending_item_id != "":
		if pending_target_mode != "single_enemy":
			return use_item()
		if target_id == "":
			combat_log.append("Missing target.")
			return {"refresh": true}
		pending_target_id = target_id
		return _use_pending_item()
	if pending_skill_target_mode == "":
		return {}
	if target_id == "":
		combat_log.append("Missing target.")
		return {"refresh": true}
	pending_target_id = target_id
	return _resolve_selected_rolls(pending_skill_roll_ids.duplicate())

func smoke_win() -> Dictionary:
	spinning = false
	selected_roll_ids.clear()
	selected_roll_ids.append(0)
	selected_roll_ids.append(1)
	enemy_hp = 1
	var outcome := confirm_selection()
	if pending_skill_target_mode != "":
		outcome = confirm_selection()
	return outcome

func smoke_use_item(item_id: String) -> Dictionary:
	var outcome := pick_item(item_id)
	if pending_item_id != "":
		if pending_target_mode == "single_enemy":
			outcome = select_target("enemy_0")
		else:
			outcome = use_item()
	return outcome

func smoke_lose() -> Dictionary:
	party_hp = 0
	combat_log.append("The front line collapsed.")
	return {"exit": true, "victory": false, "defeat": true, "summary": build_defeat_summary()}

func smoke_probe_target_and_cooldown() -> Dictionary:
	spinning = false
	selected_roll_ids.clear()
	for index in range(rolls.size()):
		var cooldown_roll: Dictionary = rolls[index]
		if String(cooldown_roll.get("targetMode", "")) == "single_enemy" and int(cooldown_roll.get("cooldownTurns", 0)) > 0 and int(cooldown_roll.get("cooldownRemaining", 0)) <= 0:
			selected_roll_ids.append(index)
			break
	for index in range(rolls.size()):
		if not selected_roll_ids.is_empty():
			break
		var roll: Dictionary = rolls[index]
		if String(roll.get("targetMode", "")) == "single_enemy" and int(roll.get("cooldownRemaining", 0)) <= 0:
			selected_roll_ids.append(index)
			break
	if selected_roll_ids.is_empty():
		return {"ok": false}
	confirm_selection()
	var before := debug_combat_state()
	select_target("enemy_0")
	var after := debug_combat_state()
	return {"ok": true, "before": before, "after": after}

func smoke_probe_item_commands(item_id: String) -> Dictionary:
	var before := build_view_model()
	var pick_outcome := pick_item(item_id)
	var after_pick := build_view_model()
	var resolve_outcome := {}
	if pending_item_id != "":
		if pending_target_mode == "single_enemy":
			resolve_outcome = select_target("enemy_0")
		else:
			resolve_outcome = use_item()
	var after_use := build_view_model()
	return {
		"ok": true,
		"before": before,
		"pickOutcome": pick_outcome,
		"afterPick": after_pick,
		"resolveOutcome": resolve_outcome,
		"afterUse": after_use
	}

func smoke_probe_selection_commands() -> Dictionary:
	spinning = false
	selected_roll_ids.clear()
	_refresh_selected_orders()
	if rolls.size() < 2:
		return {"ok": false}
	toggle_roll(0)
	toggle_roll(1)
	var before_swap := debug_roll_rows()
	swap_selected_rolls()
	var after_swap := debug_roll_rows()
	var selected_before_clear := selected_roll_ids.duplicate()
	clear_selection()
	return {
		"ok": true,
		"beforeSwap": before_swap,
		"afterSwap": after_swap,
		"selectedBeforeClear": selected_before_clear,
		"selectedAfterClear": selected_roll_ids.duplicate()
	}

func smoke_probe_enemy_turn() -> Dictionary:
	stop_dice()
	selected_roll_ids.clear()
	_refresh_selected_orders()
	if rolls.is_empty():
		return {"ok": false}
	toggle_roll(0)
	var before := debug_combat_state()
	var outcome := confirm_selection()
	if pending_skill_target_mode != "":
		outcome = confirm_selection()
	var after := debug_combat_state()
	return {
		"ok": true,
		"before": before,
		"after": after,
		"outcome": outcome,
		"log": combat_log.slice(maxi(combat_log.size() - 6, 0), combat_log.size())
	}

func debug_combat_state() -> Dictionary:
	return {
		"frontStatuses": front_statuses.duplicate(),
		"enemyStatuses": enemy_statuses.duplicate(),
		"enemyGuardPoints": enemy_guard_points,
		"selectedRollIds": selected_roll_ids.duplicate(),
		"pendingTargetMode": pending_skill_target_mode,
		"pendingTargetId": pending_target_id,
		"pendingItemId": pending_item_id,
		"enemyHp": enemy_hp,
		"partyHp": party_hp,
		"skillCooldowns": skill_cooldowns.duplicate()
	}

func debug_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for roll in rolls:
		result.append(String(roll.get("skillId", "")))
	return result

func debug_roll_rows() -> Array[Dictionary]:
	return CombatViewModelBuilder.build_roll_rows(rolls)

func _reset_rolls() -> void:
	rolls.clear()
	selected_roll_ids.clear()
	for index in range(3):
		var skill_id := known_skill_ids[index % known_skill_ids.size()]
		var skill_def := ContentRegistry.get_definition("skills", skill_id)
		rolls.append({
			"id": index,
			"dieId": index,
			"faceIndex": index,
			"value": randi_range(1, 6),
			"skillId": skill_id,
			"skillName": String(skill_def.get("name", skill_id)),
			"kind": String(skill_def.get("kind", "attack")),
			"effectKind": String(skill_def.get("effectKind", skill_def.get("kind", "attack"))),
			"power": int(skill_def.get("power", 1)),
			"guardBonus": int(skill_def.get("guardBonus", 0)),
			"healBonus": int(skill_def.get("healBonus", 0)),
			"armorBreak": int(skill_def.get("armorBreak", 0)),
			"lifestealRatio": float(skill_def.get("lifestealRatio", 0.0)),
			"targetMode": String(skill_def.get("targetMode", "single_enemy")),
			"cooldownKey": String(skill_def.get("cooldownKey", skill_id)),
			"cooldownTurns": int(skill_def.get("cooldownTurns", 0)),
			"cooldownRemaining": int(skill_cooldowns.get(String(skill_def.get("cooldownKey", skill_id)), 0)),
			"effectOps": _effect_ops_for_skill(skill_def),
			"spinState": "spinning",
			"selectedOrder": -1
		})

func _resolve_selected_rolls(resolved_roll_ids: Array[int]) -> Dictionary:
	if resolved_roll_ids.is_empty():
		return {}
	var damage := 0
	resolved_roll_ids.sort()
	var used_cooldown_keys: Array[String] = []
	var resolution_context := {
		"weaponBonusAvailable": weapon_bonus
	}
	for selected_id in resolved_roll_ids:
		var roll: Dictionary = rolls[selected_id]
		var skill_name := String(roll.get("skillName", "Skill"))
		var cooldown_key := String(roll.get("cooldownKey", ""))
		var cooldown_turns := int(roll.get("cooldownTurns", 0))
		if cooldown_key != "" and cooldown_turns > 0:
			used_cooldown_keys.append("%s:%d" % [cooldown_key, cooldown_turns])
		damage += _resolve_roll_effect_ops(roll, resolution_context)
	selected_roll_ids.clear()
	pending_skill_roll_ids.clear()
	pending_skill_target_mode = ""
	pending_target_id = ""
	_refresh_selected_orders()
	for cooldown_row in used_cooldown_keys:
		var parts := cooldown_row.split(":")
		if parts.size() == 2:
			skill_cooldowns[parts[0]] = int(parts[1])
	_apply_damage_to_enemy(damage)
	if enemy_hp <= 0:
		_persist_party_state()
		return {"exit": true, "victory": true}
	_apply_enemy_status_tick()
	if enemy_hp <= 0:
		_persist_party_state()
		return {"exit": true, "victory": true}
	_run_enemy_turn()
	if party_hp <= 0:
		combat_log.append("The front line was defeated.")
		return {"exit": true, "victory": false, "defeat": true, "summary": build_defeat_summary()}
	_persist_party_state()
	spinning = true
	_reset_rolls()
	return {"refresh": true}

func _use_pending_item() -> Dictionary:
	if pending_item_id == "":
		return {}
	var item_id := pending_item_id
	var item_def := ContentRegistry.get_definition("items", item_id)
	var combat_use: Dictionary = item_def.get("combatUse", {})
	if combat_use.is_empty():
		_clear_pending_item()
		return {}
	if not SaveService.consume_inventory_item(slot, item_id, 1):
		combat_log.append("Failed to use %s." % String(item_def.get("name", item_id)))
		_clear_pending_item()
		return {}
	var item_context := {
		"weaponBonusAvailable": 0,
		"itemName": String(item_def.get("name", item_id)),
		"sourceKind": "item"
	}
	var item_damage := _resolve_effect_ops(_effect_ops_for_item_use(combat_use), {
		"skillName": String(item_def.get("name", item_id)),
		"power": 0,
		"value": 0
	}, item_context)
	_apply_damage_to_enemy(item_damage)
	_clear_pending_item()
	if enemy_hp <= 0:
		_persist_party_state()
		return {"exit": true, "victory": true}
	_persist_party_state()
	return {"refresh": true}

func _clear_pending_item() -> void:
	pending_item_id = ""
	pending_target_mode = ""
	pending_target_id = ""

func _apply_enemy_status_tick() -> void:
	if enemy_statuses.has("burning"):
		enemy_hp -= 2
		combat_log.append("%s suffered 2 burning damage." % enemy_name)

func _apply_front_status_tick() -> void:
	if front_statuses.has("독"):
		party_hp = maxi(party_hp - 2, 0)
		combat_log.append("Poison dealt 2 damage to the front line.")

func _apply_damage_to_enemy(total_damage: int) -> void:
	if total_damage <= 0:
		return
	var resolved_damage := total_damage
	if enemy_guard_points > 0:
		var absorbed := mini(enemy_guard_points, resolved_damage)
		resolved_damage -= absorbed
		enemy_guard_points -= absorbed
		combat_log.append("%s guard absorbed %d." % [enemy_name, absorbed])
	enemy_hp -= resolved_damage

func _run_enemy_turn() -> void:
	enemy_turn_index += 1
	_apply_front_status_tick()
	if party_hp <= 0:
		return
	var retaliation := randi_range(enemy_attack_min, enemy_attack_max) + curse_penalty
	var inflict_status := ""
	var turn_result := _resolve_enemy_turn_ops(retaliation)
	retaliation = int(turn_result.get("retaliation", retaliation))
	inflict_status = String(turn_result.get("inflictStatus", ""))
	if bool(turn_result.get("endTurn", false)):
		return
	if enemy_statuses.has("weakened"):
		retaliation = maxi(retaliation - 1, 0)
		combat_log.append("%s was weakened and hit softer." % enemy_name)
	if guard_points > 0:
		var absorbed := mini(guard_points, retaliation)
		retaliation -= absorbed
		guard_points -= absorbed
		combat_log.append("Guard absorbed %d." % absorbed)
	party_hp = maxi(party_hp - retaliation, 0)
	combat_log.append("%s struck back for %d." % [enemy_name, retaliation])
	if inflict_status != "":
		_apply_front_status(inflict_status)

func _apply_front_status(status: String) -> void:
	if status == "":
		return
	var resisted := false
	for resist_status in _front_resist_statuses():
		if resist_status == status:
			resisted = true
			break
	if resisted:
		combat_log.append("The front line resisted %s." % status)
		return
	if front_statuses.has(status):
		return
	front_statuses.append(status)
	combat_log.append("%s afflicted the front line with %s." % [enemy_name, status])

func _tick_skill_cooldowns() -> void:
	for key in skill_cooldowns.keys():
		var remaining := maxi(int(skill_cooldowns.get(key, 0)) - 1, 0)
		if remaining <= 0:
			skill_cooldowns.erase(key)
		else:
			skill_cooldowns[key] = remaining

func _refresh_selected_orders() -> void:
	for roll in rolls:
		roll["selectedOrder"] = -1
	for index in range(selected_roll_ids.size()):
		var roll_id := int(selected_roll_ids[index])
		if roll_id >= 0 and roll_id < rolls.size():
			rolls[roll_id]["selectedOrder"] = index

func _persist_party_state() -> void:
	SaveService.update_front_state(slot, maxi(party_hp, 1), party_max_hp, front_statuses)

func _front_resist_statuses() -> Array[String]:
	var result: Array[String] = []
	var equipment_data: Dictionary = SaveService.equipment(slot)
	for equip_slot in equipment_data.keys():
		var item_id := String(equipment_data.get(equip_slot, ""))
		if item_id == "":
			continue
		var item_def := ContentRegistry.get_definition("items", item_id)
		var resist_bonus := String(item_def.get("resistBonus", ""))
		if resist_bonus != "" and not result.has(resist_bonus):
			result.append(resist_bonus)
	return result

func _effect_ops_for_skill(skill_def: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for op_variant in skill_def.get("effectOps", []):
		if typeof(op_variant) == TYPE_DICTIONARY:
			result.append((op_variant as Dictionary).duplicate(true))
	if not result.is_empty():
		return result
	var effect_kind := String(skill_def.get("effectKind", skill_def.get("kind", "attack")))
	match effect_kind:
		"guard":
			result.append({"op": "gain_guard", "bonus": int(skill_def.get("guardBonus", 0))})
		"heal":
			result.append({"op": "heal_self", "bonus": int(skill_def.get("healBonus", int(skill_def.get("power", 1))))})
		"break_attack":
			result.append({"op": "damage_enemy", "allowWeaponBonus": true, "bonus": 0, "armorBreakOffset": int(skill_def.get("armorBreak", 0))})
			result.append({"op": "break_enemy_armor", "value": int(skill_def.get("armorBreak", 0))})
			result.append({"op": "apply_enemy_status", "status": "weakened"})
		"lifesteal":
			result.append({"op": "damage_enemy", "allowWeaponBonus": true, "bonus": 0})
			result.append({"op": "lifesteal_last_damage", "ratio": float(skill_def.get("lifestealRatio", 0.5))})
		_:
			result.append({"op": "damage_enemy", "allowWeaponBonus": true, "bonus": 0})
	return result

func _effect_ops_for_item_use(combat_use: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for op_variant in combat_use.get("effectOps", []):
		if typeof(op_variant) == TYPE_DICTIONARY:
			result.append((op_variant as Dictionary).duplicate(true))
	if not result.is_empty():
		return result
	var effect_kind := String(combat_use.get("effectKind", ""))
	match effect_kind:
		"heal_self":
			result.append({"op": "heal_self_flat", "value": int(combat_use.get("heal", 0))})
		"cure_status_self":
			result.append({"op": "cure_front_status", "status": String(combat_use.get("status", ""))})
		"damage_enemy":
			result.append({"op": "damage_enemy_flat", "value": int(combat_use.get("damage", 0))})
		"burn_enemy":
			result.append({"op": "damage_enemy_flat", "value": int(combat_use.get("damage", 0))})
			result.append({"op": "apply_enemy_status", "status": String(combat_use.get("status", "burning"))})
	return result

func _resolve_roll_effect_ops(roll: Dictionary, resolution_context: Dictionary) -> int:
	return _resolve_effect_ops(roll.get("effectOps", []), roll, resolution_context)

func _resolve_effect_ops(effect_ops: Array, source_row: Dictionary, resolution_context: Dictionary) -> int:
	var total_damage := 0
	var skill_name := String(source_row.get("skillName", "Skill"))
	var power := maxi(int(source_row.get("power", 1)), 0)
	var roll_value := int(source_row.get("value", 0))
	var last_damage := 0
	for op_variant in effect_ops:
		if typeof(op_variant) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = op_variant
		match String(op.get("op", "")):
			"damage_enemy":
				var strike_bonus := 0
				if bool(op.get("allowWeaponBonus", false)):
					strike_bonus = int(resolution_context.get("weaponBonusAvailable", 0))
					resolution_context["weaponBonusAvailable"] = 0
				var armor_break_offset := maxi(int(op.get("armorBreakOffset", 0)), 0)
				var defense := maxi(enemy_armor - enemy_armor_break - armor_break_offset, 0)
				var strike_damage := maxi(1, roll_value + power + int(op.get("bonus", 0)) + strike_bonus - defense)
				total_damage += strike_damage
				last_damage = strike_damage
				combat_log.append("%s hit for %d." % [skill_name, strike_damage])
			"damage_enemy_flat":
				var flat_damage := maxi(int(op.get("value", 0)), 1)
				total_damage += flat_damage
				last_damage = flat_damage
				combat_log.append("Used %s for %d damage." % [skill_name, flat_damage])
			"gain_guard":
				var guard_gain := roll_value + power + int(op.get("bonus", 0))
				guard_points += guard_gain
				combat_log.append("%s granted %d guard." % [skill_name, guard_gain])
			"heal_self":
				var heal_amount := roll_value + int(op.get("bonus", power))
				party_hp = mini(party_hp + heal_amount, party_max_hp)
				combat_log.append("%s healed %d HP." % [skill_name, heal_amount])
			"heal_self_flat":
				var flat_heal := maxi(int(op.get("value", 0)), 1)
				party_hp = mini(party_hp + flat_heal, party_max_hp)
				combat_log.append("Used %s and healed %d HP." % [skill_name, flat_heal])
			"break_enemy_armor":
				var armor_break := maxi(int(op.get("value", 0)), 1)
				enemy_armor_break += armor_break
				combat_log.append("%s broke %d armor." % [skill_name, armor_break])
			"apply_enemy_status":
				var status := String(op.get("status", ""))
				if status != "" and not enemy_statuses.has(status):
					enemy_statuses.append(status)
					if String(resolution_context.get("sourceKind", "skill")) == "item":
						combat_log.append("Used %s and applied %s." % [skill_name, status])
					else:
						combat_log.append("%s applied %s." % [skill_name, status])
			"cure_front_status":
				var cured_status := String(op.get("status", ""))
				if cured_status != "" and front_statuses.has(cured_status):
					front_statuses.erase(cured_status)
					combat_log.append("Used %s and cured %s." % [skill_name, cured_status])
				else:
					combat_log.append("Used %s, but there was no %s to cure." % [skill_name, cured_status])
			"lifesteal_last_damage":
				var heal_back := maxi(int(ceil(float(last_damage) * float(op.get("ratio", 0.5)))), 1)
				party_hp = mini(party_hp + heal_back, party_max_hp)
				combat_log.append("%s restored %d HP." % [skill_name, heal_back])
	return total_damage

func _pending_item_view_model() -> Dictionary:
	if pending_item_id == "":
		return {}
	var item_def := ContentRegistry.get_definition("items", pending_item_id)
	return {
		"itemId": pending_item_id,
		"targetMode": pending_target_mode,
		"name": String(item_def.get("name", pending_item_id))
	}

func _pending_target_view_model() -> Dictionary:
	var mode := pending_skill_target_mode
	var source := "skill"
	if pending_item_id != "":
		mode = pending_target_mode
		source = "item"
	if mode == "":
		return {}
	return {
		"mode": mode,
		"targetId": pending_target_id,
		"source": source,
		"targetOptions": [
			{
				"id": "enemy_0",
				"label": enemy_name
			}
		]
	}

func _active_hero_view() -> Dictionary:
	var slot_data := SaveService.load_slot(slot)
	var player_name := String(slot_data.get("player", {}).get("name", "Conan"))
	return {
		"name": player_name,
		"slot": "front",
		"weaponBonus": weapon_bonus,
		"resistStatuses": _front_resist_statuses()
	}

func _default_enemy_guard(ai: String) -> int:
	match ai:
		"guardian":
			return 2
		"defensive":
			return 1
		_:
			return 0

func _combat_profile_for_monster(monster_def: Dictionary) -> Dictionary:
	var profile: Dictionary = monster_def.get("combatProfile", {})
	if not profile.is_empty():
		return profile.duplicate(true)
	return _default_combat_profile(String(monster_def.get("ai", enemy_ai)))

func _default_combat_profile(ai: String) -> Dictionary:
	match ai:
		"aggressive":
			return {
				"startingGuard": 0,
				"turnOps": [
					{"op": "retaliation_bonus", "value": 1}
				]
			}
		"guardian":
			return {
				"startingGuard": 2,
				"turnOps": [
					{"op": "add_guard", "value": 2, "log": "%s braced and gained 2 guard."},
					{"op": "retaliation_penalty", "value": 1}
				]
			}
		"defensive":
			return {
				"startingGuard": 1,
				"turnOps": [
					{"op": "conditional_guard", "enemyHpBelowRatio": 0.5, "guard": 3, "retaliationPenalty": 1, "log": "%s fortified and gained 3 guard."}
				]
			}
		"ambusher":
			return {
				"startingGuard": 0,
				"turnOps": [
					{"op": "if_party_guard_empty", "retaliationBonus": 2, "status": "독", "log": "%s struck from the blind side."}
				]
			}
		"caster":
			return {
				"startingGuard": 0,
				"turnOps": [
					{"op": "cycle", "steps": [
						{"status": "독", "retaliationPenalty": 1, "log": "%s cast a venom hex."},
						{"status": "저주", "retaliationBonus": 1, "log": "%s cast a curse."}
					]}
				]
			}
		"coward":
			return {
				"startingGuard": 0,
				"turnOps": [
					{"op": "heal_and_hide_if_enemy_hp_below_ratio", "ratio": 0.34, "heal": 4, "guard": 1, "log": "%s recovered %d HP and hid behind guard."}
				]
			}
		_:
			return {
				"startingGuard": 0,
				"turnOps": []
			}

func _resolve_enemy_turn_ops(base_retaliation: int) -> Dictionary:
	var retaliation := base_retaliation
	var inflict_status := ""
	var end_turn := false
	for op_variant in enemy_combat_profile.get("turnOps", []):
		if typeof(op_variant) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = op_variant
		match String(op.get("op", "")):
			"retaliation_bonus":
				retaliation += int(op.get("value", 0))
			"retaliation_penalty":
				retaliation = maxi(retaliation - int(op.get("value", 0)), 0)
			"add_guard":
				var guard_gain := maxi(int(op.get("value", 0)), 0)
				enemy_guard_points += guard_gain
				var log_template := String(op.get("log", ""))
				if log_template != "":
					combat_log.append(log_template % enemy_name)
			"conditional_guard":
				var ratio := float(op.get("enemyHpBelowRatio", 1.0))
				if float(enemy_hp) <= float(enemy_max_hp) * ratio:
					var guard_gain_cond := maxi(int(op.get("guard", 0)), 0)
					enemy_guard_points += guard_gain_cond
					retaliation = maxi(retaliation - int(op.get("retaliationPenalty", 0)), 0)
					var cond_log := String(op.get("log", ""))
					if cond_log != "":
						combat_log.append(cond_log % enemy_name)
			"if_party_guard_empty":
				if guard_points <= 0:
					retaliation += int(op.get("retaliationBonus", 0))
					inflict_status = String(op.get("status", inflict_status))
					var ambush_log := String(op.get("log", ""))
					if ambush_log != "":
						combat_log.append(ambush_log % enemy_name)
			"cycle":
				var steps: Array = op.get("steps", [])
				if typeof(steps) == TYPE_ARRAY and not steps.is_empty():
					var step: Dictionary = steps[(enemy_turn_index - 1) % steps.size()]
					retaliation += int(step.get("retaliationBonus", 0))
					retaliation = maxi(retaliation - int(step.get("retaliationPenalty", 0)), 0)
					inflict_status = String(step.get("status", inflict_status))
					var cycle_log := String(step.get("log", ""))
					if cycle_log != "":
						combat_log.append(cycle_log % enemy_name)
			"heal_and_hide_if_enemy_hp_below_ratio":
				var heal_ratio := float(op.get("ratio", 0.34))
				if float(enemy_hp) <= float(enemy_max_hp) * heal_ratio:
					var heal_amount := maxi(int(op.get("heal", 0)), 0)
					enemy_hp = mini(enemy_hp + heal_amount, enemy_max_hp)
					enemy_guard_points += maxi(int(op.get("guard", 0)), 0)
					var heal_log := String(op.get("log", ""))
					if heal_log != "":
						combat_log.append(heal_log % [enemy_name, heal_amount])
					end_turn = true
	return {
		"retaliation": retaliation,
		"inflictStatus": inflict_status,
		"endTurn": end_turn
	}

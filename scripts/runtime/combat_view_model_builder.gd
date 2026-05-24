extends RefCounted

static func build(runtime: RefCounted) -> Dictionary:
	return {
		"activeHero": runtime._active_hero_view(),
		"partyHp": runtime.party_hp,
		"partyMaxHp": runtime.party_max_hp,
		"enemyHp": runtime.enemy_hp,
		"enemyMaxHp": runtime.enemy_max_hp,
		"enemyName": runtime.enemy_name,
		"enemyAi": runtime.enemy_ai,
		"enemyCombatProfile": runtime.enemy_combat_profile.duplicate(true),
		"enemyArmor": runtime.enemy_armor,
		"enemyGuardPoints": runtime.enemy_guard_points,
		"enemyArmorBreak": runtime.enemy_armor_break,
		"guardPoints": runtime.guard_points,
		"dicePhase": "spinning" if runtime.spinning else "select",
		"knownSkills": runtime.known_skill_ids.duplicate(),
		"frontStatuses": runtime.front_statuses.duplicate(),
		"enemyStatuses": runtime.enemy_statuses.duplicate(),
		"selectedRollIds": runtime.selected_roll_ids.duplicate(),
		"selectLimit": runtime.SELECT_LIMIT,
		"pendingTargetMode": runtime.pending_skill_target_mode,
		"pendingTargetState": runtime._pending_target_view_model(),
		"pendingItemId": runtime.pending_item_id,
		"pendingItemState": runtime._pending_item_view_model(),
		"inventory": {
			"healing_tonic": int(SaveService.inventory(runtime.slot).get("healing_tonic", 0)),
			"bandage": int(SaveService.inventory(runtime.slot).get("bandage", 0)),
			"antivenom": int(SaveService.inventory(runtime.slot).get("antivenom", 0)),
			"throwing_knife": int(SaveService.inventory(runtime.slot).get("throwing_knife", 0)),
			"firebomb": int(SaveService.inventory(runtime.slot).get("firebomb", 0))
		},
		"weaponBonus": runtime.weapon_bonus,
		"cursePenalty": runtime.curse_penalty,
		"log": runtime.combat_log.slice(maxi(runtime.combat_log.size() - 4, 0), runtime.combat_log.size()),
		"rolls": build_roll_rows(runtime.rolls)
	}

static func build_roll_rows(rolls: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for roll in rolls:
		result.append({
			"id": int(roll.get("id", 0)),
			"dieId": int(roll.get("dieId", 0)),
			"faceIndex": int(roll.get("faceIndex", 0)),
			"skillId": String(roll.get("skillId", "")),
			"skillName": String(roll.get("skillName", "")),
			"kind": String(roll.get("kind", "")),
			"effectKind": String(roll.get("effectKind", "")),
			"targetMode": String(roll.get("targetMode", "")),
			"cooldownKey": String(roll.get("cooldownKey", "")),
			"cooldownRemaining": int(roll.get("cooldownRemaining", 0)),
			"effectOps": roll.get("effectOps", []),
			"spinState": String(roll.get("spinState", "")),
			"selectedOrder": int(roll.get("selectedOrder", -1)),
			"value": int(roll.get("value", 0))
		})
	return result

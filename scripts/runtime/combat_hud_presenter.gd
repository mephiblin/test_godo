extends RefCounted

static func build_roll_button_text(row: Dictionary, selected: bool) -> String:
	var selected_order := int(row.get("selectedOrder", -1))
	var cooldown_remaining := int(row.get("cooldownRemaining", 0))
	var suffix := " *" if selected else ""
	if selected_order >= 0:
		suffix += " #%d" % (selected_order + 1)
	if cooldown_remaining > 0:
		suffix += " CD%d" % cooldown_remaining
	return "Roll %d\n%s\n%d%s" % [
		int(row.get("id", 0)) + 1,
		String(row.get("skillName", "")),
		int(row.get("value", 0)),
		suffix
	]

static func build_info_text(vm: Dictionary) -> String:
	var active_hero: Dictionary = vm.get("activeHero", {})
	var pending_item_state: Dictionary = vm.get("pendingItemState", {})
	var pending_target_state: Dictionary = vm.get("pendingTargetState", {})
	var pending_target_label := "-"
	if not pending_target_state.is_empty():
		pending_target_label = "%s:%s" % [
			String(pending_target_state.get("source", "")),
			String(pending_target_state.get("mode", ""))
		]
	var text := "[b]Active Hero[/b] %s  [b]Resist[/b] %s\n[b]Party HP[/b] %d/%d   [b]%s HP[/b] %d/%d\n[b]Enemy Armor[/b] %d (-%d break)   [b]Party Guard[/b] %d   [b]Enemy Guard[/b] %d\n[b]Dice Phase[/b] %s   [b]Selected[/b] %s / %d\n[b]Known Skills[/b] %s\n[b]Front Statuses[/b] %s\n[b]Enemy Statuses[/b] %s\n[b]Pending Target[/b] %s\n[b]Pending Item[/b] %s\n[b]Inventory[/b] tonic %d / bandage %d / antivenom %d / knife %d / firebomb %d\n[b]Commands[/b] 1-3 select, Space stop, Enter confirm" % [
		String(active_hero.get("name", "Front")),
		", ".join(active_hero.get("resistStatuses", [])) if not active_hero.get("resistStatuses", []).is_empty() else "-",
		int(vm.get("partyHp", 0)),
		int(vm.get("partyMaxHp", 0)),
		String(vm.get("enemyName", "")),
		int(vm.get("enemyHp", 0)),
		int(vm.get("enemyMaxHp", 0)),
		int(vm.get("enemyArmor", 0)),
		int(vm.get("enemyArmorBreak", 0)),
		int(vm.get("guardPoints", 0)),
		int(vm.get("enemyGuardPoints", 0)),
		String(vm.get("dicePhase", "select")),
		str(vm.get("selectedRollIds", [])),
		int(vm.get("selectLimit", 2)),
		", ".join(vm.get("knownSkills", [])),
		", ".join(vm.get("frontStatuses", [])) if not vm.get("frontStatuses", []).is_empty() else "-",
		", ".join(vm.get("enemyStatuses", [])) if not vm.get("enemyStatuses", []).is_empty() else "-",
		pending_target_label,
		String(pending_item_state.get("name", vm.get("pendingItemId", ""))) if not pending_item_state.is_empty() else "-",
		int(vm.get("inventory", {}).get("healing_tonic", 0)),
		int(vm.get("inventory", {}).get("bandage", 0)),
		int(vm.get("inventory", {}).get("antivenom", 0)),
		int(vm.get("inventory", {}).get("throwing_knife", 0)),
		int(vm.get("inventory", {}).get("firebomb", 0))
	]
	if int(vm.get("weaponBonus", 0)) != 0 or int(vm.get("cursePenalty", 0)) != 0:
		text += "\n[b]Weapon Bonus[/b] +%d  [b]Curse Penalty[/b] +%d enemy damage" % [
			int(vm.get("weaponBonus", 0)),
			int(vm.get("cursePenalty", 0))
		]
	if not vm.get("log", []).is_empty():
		text += "\n[b]Log[/b]\n%s" % "\n".join(vm.get("log", []))
	return text

static func build_intent_text(vm: Dictionary) -> String:
	var pending_item_state: Dictionary = vm.get("pendingItemState", {})
	var pending_target_state: Dictionary = vm.get("pendingTargetState", {})
	if not pending_item_state.is_empty():
		return "[color=#f3e7b3]Item ready[/color] %s\nTarget or Use Item to resolve." % String(pending_item_state.get("name", vm.get("pendingItemId", "")))
	if not pending_target_state.is_empty():
		return "[color=#f3e7b3]Target required[/color] %s\nPress Target Enemy to commit the selected command." % String(pending_target_state.get("mode", "enemy"))
	var selected: Array = vm.get("selectedRollIds", [])
	if not selected.is_empty():
		return "[color=#9fd6a5]Selection ready[/color] %s / %d\nEnter confirms, C clears, Swap reorders two dice." % [
			str(selected),
			int(vm.get("selectLimit", 2))
		]
	if String(vm.get("dicePhase", "")) == "spinning":
		return "[color=#8fb7d8]Dice spinning[/color]\nSpace stops the reel; choose up to %d dice." % int(vm.get("selectLimit", 2))
	return "[color=#9aa7b8]Choose action[/color]\nSelect dice, use an item, or flee."

static func build_victory_text(summary: Dictionary) -> String:
	var reward_lines: Array[String] = []
	for reward in summary.get("rewards", []):
		if typeof(reward) != TYPE_DICTIONARY:
			continue
		var row := String(reward.get("label", "enemy defeated"))
		if bool(reward.get("boss", false)):
			row += " / boss flag %s" % String(reward.get("flag", ""))
		reward_lines.append(row)
	if reward_lines.is_empty():
		reward_lines.append("Field monster state will be marked defeated.")
	return "[b]Enemy[/b] %s\n[b]Return Map[/b] %s\n[b]Party HP[/b] %d/%d\n[b]Front Status[/b] %s\n[b]Outcome[/b]\n%s\n[b]Log[/b]\n%s" % [
		String(summary.get("enemyName", "Enemy")),
		String(summary.get("mapId", "")),
		int(summary.get("partyHp", 0)),
		int(summary.get("partyMaxHp", 0)),
		", ".join(summary.get("frontStatuses", [])) if not summary.get("frontStatuses", []).is_empty() else "-",
		"\n".join(reward_lines),
		"\n".join(summary.get("logTail", []))
	]

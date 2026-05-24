extends RefCounted

const CombatViewModelBuilder = preload("res://scripts/runtime/combat_view_model_builder.gd")

func win(scene: Node) -> void:
	var runtime := _runtime(scene)
	if runtime == null:
		return
	var outcome := runtime_win(runtime)
	if bool(outcome.get("exit", false)) and bool(outcome.get("victory", false)):
		_game_app().call("exit_combat", true)
		return
	_handle_outcome(scene, outcome)

func lose(scene: Node) -> void:
	var runtime := _runtime(scene)
	if runtime != null:
		_handle_outcome(scene, runtime_lose(runtime))

func use_item(scene: Node, item_id: String) -> void:
	var runtime := _runtime(scene)
	if runtime != null:
		_handle_outcome(scene, runtime_use_item(runtime, item_id))

func target_and_cooldown_probe(scene: Node) -> Dictionary:
	var runtime := _runtime(scene)
	if runtime == null:
		return {}
	return runtime_target_and_cooldown_probe(runtime)

func item_commands_probe(scene: Node, item_id: String) -> Dictionary:
	var runtime := _runtime(scene)
	if runtime == null:
		return {}
	return runtime_item_commands_probe(runtime, item_id)

func selection_commands_probe(scene: Node) -> Dictionary:
	var runtime := _runtime(scene)
	if runtime == null:
		return {}
	return runtime_selection_commands_probe(runtime)

func combat_state(scene: Node) -> Dictionary:
	var runtime := _runtime(scene)
	if runtime == null:
		return {}
	return runtime_combat_state(runtime)

func skill_ids(scene: Node) -> Array[String]:
	var runtime := _runtime(scene)
	if runtime == null:
		return []
	return runtime_skill_ids(runtime)

func roll_rows(scene: Node) -> Array[Dictionary]:
	var runtime := _runtime(scene)
	if runtime == null:
		return []
	return runtime_roll_rows(runtime)

func recover_in_town(scene: Node) -> void:
	var runtime := _runtime(scene)
	if runtime == null:
		return
	var game_app := _game_app()
	_save_service().call("record_defeat", runtime.slot, runtime.call("build_defeat_summary"), false)
	_scene_router().call("change_route", game_app.get("MODE_TOWN"), {
		"slot": runtime.slot,
		"map_id": "town_square",
		"dungeon_source": game_app.get("dungeon_runtime_source")
	})

func return_title_after_defeat(scene: Node) -> void:
	var runtime := _runtime(scene)
	if runtime == null:
		return
	_save_service().call("record_defeat", runtime.slot, runtime.call("build_defeat_summary"), true)
	_scene_router().call("change_route", _game_app().get("MODE_TITLE"), {})

func runtime_win(runtime: Object) -> Dictionary:
	runtime.set("spinning", false)
	var selected_roll_ids: Array = runtime.get("selected_roll_ids")
	selected_roll_ids.clear()
	selected_roll_ids.append(0)
	selected_roll_ids.append(1)
	runtime.set("enemy_hp", 1)
	var outcome: Dictionary = runtime.call("confirm_selection")
	if String(runtime.get("pending_skill_target_mode")) != "":
		outcome = runtime.call("confirm_selection")
	return outcome

func runtime_use_item(runtime: Object, item_id: String) -> Dictionary:
	var outcome: Dictionary = runtime.call("pick_item", item_id)
	if String(runtime.get("pending_item_id")) != "":
		if String(runtime.get("pending_target_mode")) == "single_enemy":
			outcome = runtime.call("select_target", "enemy_0")
		else:
			outcome = runtime.call("use_item")
	return outcome

func runtime_lose(runtime: Object) -> Dictionary:
	runtime.set("party_hp", 0)
	var combat_log: Array = runtime.get("combat_log")
	combat_log.append("The front line collapsed.")
	return {"exit": true, "victory": false, "defeat": true, "summary": runtime.call("build_defeat_summary")}

func runtime_target_and_cooldown_probe(runtime: Object) -> Dictionary:
	runtime.set("spinning", false)
	var selected_roll_ids: Array = runtime.get("selected_roll_ids")
	selected_roll_ids.clear()
	for index in range((runtime.get("rolls") as Array).size()):
		var cooldown_roll: Dictionary = (runtime.get("rolls") as Array)[index]
		if String(cooldown_roll.get("targetMode", "")) == "single_enemy" and int(cooldown_roll.get("cooldownTurns", 0)) > 0 and int(cooldown_roll.get("cooldownRemaining", 0)) <= 0:
			selected_roll_ids.append(index)
			break
	for index in range((runtime.get("rolls") as Array).size()):
		if not selected_roll_ids.is_empty():
			break
		var roll: Dictionary = (runtime.get("rolls") as Array)[index]
		if String(roll.get("targetMode", "")) == "single_enemy" and int(roll.get("cooldownRemaining", 0)) <= 0:
			selected_roll_ids.append(index)
			break
	if selected_roll_ids.is_empty():
		return {"ok": false}
	runtime.call("confirm_selection")
	var before := runtime_combat_state(runtime)
	runtime.call("select_target", "enemy_0")
	var after := runtime_combat_state(runtime)
	return {"ok": true, "before": before, "after": after}

func runtime_item_commands_probe(runtime: Object, item_id: String) -> Dictionary:
	var before: Dictionary = runtime.call("build_view_model")
	var pick_outcome: Dictionary = runtime.call("pick_item", item_id)
	var after_pick: Dictionary = runtime.call("build_view_model")
	var resolve_outcome := {}
	if String(runtime.get("pending_item_id")) != "":
		if String(runtime.get("pending_target_mode")) == "single_enemy":
			resolve_outcome = runtime.call("select_target", "enemy_0")
		else:
			resolve_outcome = runtime.call("use_item")
	var after_use: Dictionary = runtime.call("build_view_model")
	return {
		"ok": true,
		"before": before,
		"pickOutcome": pick_outcome,
		"afterPick": after_pick,
		"resolveOutcome": resolve_outcome,
		"afterUse": after_use
	}

func runtime_selection_commands_probe(runtime: Object) -> Dictionary:
	runtime.set("spinning", false)
	var selected_roll_ids: Array = runtime.get("selected_roll_ids")
	selected_roll_ids.clear()
	runtime.call("_refresh_selected_orders")
	if (runtime.get("rolls") as Array).size() < 2:
		return {"ok": false}
	runtime.call("toggle_roll", 0)
	runtime.call("toggle_roll", 1)
	var before_swap := runtime_roll_rows(runtime)
	runtime.call("swap_selected_rolls")
	var after_swap := runtime_roll_rows(runtime)
	var selected_before_clear := selected_roll_ids.duplicate()
	runtime.call("clear_selection")
	return {
		"ok": true,
		"beforeSwap": before_swap,
		"afterSwap": after_swap,
		"selectedBeforeClear": selected_before_clear,
		"selectedAfterClear": selected_roll_ids.duplicate()
	}

func runtime_enemy_turn_probe(runtime: Object) -> Dictionary:
	runtime.call("stop_dice")
	var selected_roll_ids: Array = runtime.get("selected_roll_ids")
	selected_roll_ids.clear()
	runtime.call("_refresh_selected_orders")
	if (runtime.get("rolls") as Array).is_empty():
		return {"ok": false}
	runtime.call("toggle_roll", 0)
	var before := runtime_combat_state(runtime)
	var outcome: Dictionary = runtime.call("confirm_selection")
	if String(runtime.get("pending_skill_target_mode")) != "":
		outcome = runtime.call("confirm_selection")
	var after := runtime_combat_state(runtime)
	var combat_log: Array = runtime.get("combat_log")
	return {
		"ok": true,
		"before": before,
		"after": after,
		"outcome": outcome,
		"log": combat_log.slice(maxi(combat_log.size() - 6, 0), combat_log.size())
	}

func runtime_skill_effect_probe(runtime: Object, skill_id: String, roll_value: int = 6, options: Dictionary = {}) -> Dictionary:
	var skill_def: Dictionary = _content_registry().call("get_definition", "skills", skill_id)
	if skill_def.is_empty():
		return {"ok": false, "error": "missing skill"}
	runtime.set("party_hp", clampi(int(options.get("partyHp", runtime.get("party_hp"))), 0, int(runtime.get("party_max_hp"))))
	runtime.set("enemy_hp", maxi(int(options.get("enemyHp", runtime.get("enemy_hp"))), 1))
	runtime.set("enemy_max_hp", maxi(int(options.get("enemyMaxHp", runtime.get("enemy_max_hp"))), int(runtime.get("enemy_hp"))))
	runtime.set("enemy_guard_points", maxi(int(options.get("enemyGuardPoints", runtime.get("enemy_guard_points"))), 0))
	runtime.set("enemy_armor_break", maxi(int(options.get("enemyArmorBreak", runtime.get("enemy_armor_break"))), 0))
	runtime.set("guard_points", maxi(int(options.get("guardPoints", runtime.get("guard_points"))), 0))
	var enemy_statuses: Array = runtime.get("enemy_statuses")
	enemy_statuses.clear()
	for status_variant in options.get("enemyStatuses", []):
		var enemy_status := String(status_variant)
		if enemy_status != "":
			enemy_statuses.append(enemy_status)
	var front_statuses: Array = runtime.get("front_statuses")
	front_statuses.clear()
	for front_status_variant in options.get("frontStatuses", []):
		var front_status := String(front_status_variant)
		if front_status != "":
			front_statuses.append(front_status)
	var before := runtime_combat_state(runtime)
	var roll := {
		"id": 0,
		"dieId": 0,
		"faceIndex": 0,
		"value": roll_value,
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
		"cooldownRemaining": 0,
		"effectOps": runtime.call("_effect_ops_for_skill", skill_def),
		"spinState": "stopped",
		"selectedOrder": 0
	}
	var context := {"weaponBonusAvailable": int(options.get("weaponBonus", runtime.get("weapon_bonus")))}
	var damage := int(runtime.call("_resolve_roll_effect_ops", roll, context))
	runtime.call("_apply_damage_to_enemy", damage)
	var after := runtime_combat_state(runtime)
	var combat_log: Array = runtime.get("combat_log")
	return {
		"ok": true,
		"skillId": skill_id,
		"effectOps": roll.get("effectOps", []),
		"damage": damage,
		"before": before,
		"after": after,
		"log": combat_log.slice(maxi(combat_log.size() - 8, 0), combat_log.size())
	}

func runtime_combat_state(runtime: Object) -> Dictionary:
	return {
		"frontStatuses": (runtime.get("front_statuses") as Array).duplicate(),
		"enemyStatuses": (runtime.get("enemy_statuses") as Array).duplicate(),
		"enemyGuardPoints": runtime.get("enemy_guard_points"),
		"enemyArmorBreak": runtime.get("enemy_armor_break"),
		"guardPoints": runtime.get("guard_points"),
		"selectedRollIds": (runtime.get("selected_roll_ids") as Array).duplicate(),
		"pendingTargetMode": runtime.get("pending_skill_target_mode"),
		"pendingTargetId": runtime.get("pending_target_id"),
		"pendingItemId": runtime.get("pending_item_id"),
		"enemyHp": runtime.get("enemy_hp"),
		"partyHp": runtime.get("party_hp"),
		"skillCooldowns": (runtime.get("skill_cooldowns") as Dictionary).duplicate()
	}

func runtime_skill_ids(runtime: Object) -> Array[String]:
	var result: Array[String] = []
	for roll in (runtime.get("rolls") as Array):
		result.append(String((roll as Dictionary).get("skillId", "")))
	return result

func runtime_roll_rows(runtime: Object) -> Array[Dictionary]:
	return CombatViewModelBuilder.build_roll_rows(runtime.get("rolls"))

func _runtime(scene: Node) -> Object:
	if scene == null:
		return null
	return scene.get("runtime")

func _handle_outcome(scene: Node, outcome: Dictionary) -> void:
	if scene != null:
		scene.call("_handle_outcome", outcome)

func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(name)

func _game_app() -> Node:
	return _autoload("GameApp")

func _save_service() -> Node:
	return _autoload("SaveService")

func _scene_router() -> Node:
	return _autoload("SceneRouter")

func _content_registry() -> Node:
	return _autoload("ContentRegistry")

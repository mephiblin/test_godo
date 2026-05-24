extends RefCounted

func win(scene: Node) -> void:
	var runtime := _runtime(scene)
	if runtime == null:
		return
	var outcome: Dictionary = runtime.call("smoke_win")
	if bool(outcome.get("exit", false)) and bool(outcome.get("victory", false)):
		GameApp.exit_combat(true)
		return
	_handle_outcome(scene, outcome)

func lose(scene: Node) -> void:
	var runtime := _runtime(scene)
	if runtime != null:
		_handle_outcome(scene, runtime.call("smoke_lose"))

func use_item(scene: Node, item_id: String) -> void:
	var runtime := _runtime(scene)
	if runtime != null:
		_handle_outcome(scene, runtime.call("smoke_use_item", item_id))

func target_and_cooldown_probe(scene: Node) -> Dictionary:
	var runtime := _runtime(scene)
	if runtime == null:
		return {}
	return runtime.call("smoke_probe_target_and_cooldown")

func item_commands_probe(scene: Node, item_id: String) -> Dictionary:
	var runtime := _runtime(scene)
	if runtime == null:
		return {}
	return runtime.call("smoke_probe_item_commands", item_id)

func selection_commands_probe(scene: Node) -> Dictionary:
	var runtime := _runtime(scene)
	if runtime == null:
		return {}
	return runtime.call("smoke_probe_selection_commands")

func combat_state(scene: Node) -> Dictionary:
	var runtime := _runtime(scene)
	if runtime == null:
		return {}
	return runtime.call("debug_combat_state")

func skill_ids(scene: Node) -> Array[String]:
	var runtime := _runtime(scene)
	if runtime == null:
		return []
	return runtime.call("debug_skill_ids")

func roll_rows(scene: Node) -> Array[Dictionary]:
	var runtime := _runtime(scene)
	if runtime == null:
		return []
	return runtime.call("debug_roll_rows")

func recover_in_town(scene: Node) -> void:
	var runtime := _runtime(scene)
	if runtime == null:
		return
	SaveService.record_defeat(runtime.slot, runtime.call("build_defeat_summary"), false)
	SceneRouter.change_route(GameApp.MODE_TOWN, {
		"slot": runtime.slot,
		"map_id": "town_square",
		"dungeon_source": GameApp.dungeon_runtime_source
	})

func return_title_after_defeat(scene: Node) -> void:
	var runtime := _runtime(scene)
	if runtime == null:
		return
	SaveService.record_defeat(runtime.slot, runtime.call("build_defeat_summary"), true)
	SceneRouter.change_route(GameApp.MODE_TITLE, {})

func _runtime(scene: Node) -> Object:
	if scene == null:
		return null
	return scene.get("runtime")

func _handle_outcome(scene: Node, outcome: Dictionary) -> void:
	if scene != null:
		scene.call("_handle_outcome", outcome)

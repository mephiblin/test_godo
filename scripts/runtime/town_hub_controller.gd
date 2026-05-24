extends RefCounted

var scene_ref: Node

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func handle_key(keycode: Key) -> bool:
	if scene_ref == null or not is_instance_valid(scene_ref):
		return false
	match keycode:
		KEY_W:
			if bool(scene_ref.call("_try_advance_town_focus_path")):
				return true
			scene_ref.call("_try_forward_move")
			return true
		KEY_S:
			scene_ref.call("_try_backward_move")
			return true
		KEY_A, KEY_Q:
			scene_ref.call("_cycle_town_focus", -1)
			return true
		KEY_D, KEY_E:
			scene_ref.call("_cycle_town_focus", 1)
			return true
		KEY_LEFT:
			scene_ref.call("_turn_player", -1)
			return true
		KEY_RIGHT:
			scene_ref.call("_turn_player", 1)
			return true
		KEY_SPACE, KEY_ENTER:
			interact()
			return true
	return false

func interact() -> void:
	if scene_ref == null or not is_instance_valid(scene_ref):
		return
	var front_placement: Dictionary = scene_ref.call("_front_interaction_placement")
	if not front_placement.is_empty():
		scene_ref.call("_trigger_interaction_placement", front_placement)
		return
	var selected: Dictionary = scene_ref.call("_selected_town_focus_placement", 2)
	if not selected.is_empty():
		if bool(scene_ref.call("_try_approach_town_focus", selected)):
			return
		scene_ref.call("_log", "%s 쪽으로 손을 뻗었다." % String(selected.get("label", selected.get("id", "거점"))))
		scene_ref.call("_trigger_interaction_placement", selected)
		return
	var nearby: Dictionary = scene_ref.call("_town_nearby_interaction_placement", 1)
	if not nearby.is_empty():
		scene_ref.call("_log", "%s 쪽으로 손을 뻗었다." % String(nearby.get("label", nearby.get("id", "거점"))))
		scene_ref.call("_trigger_interaction_placement", nearby)
		return
	scene_ref.call("_log", "Nothing to interact with.")

func controls_summary() -> String:
	return "W path advance, A/D or Q/E hub focus, Left/Right turn, Space interact, I inventory, R rest, T title"

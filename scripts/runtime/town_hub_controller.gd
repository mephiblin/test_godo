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
			scene_ref.call("_interact_forward")
			return true
	return false

func controls_summary() -> String:
	return "W path advance, A/D or Q/E hub focus, Left/Right turn, Space interact, I inventory, R rest, T title"

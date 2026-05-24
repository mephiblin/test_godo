extends "res://scripts/runtime/grid_scene.gd"

const TOWN_HUB_CONTROLLER_SCRIPT := preload("res://scripts/runtime/town_hub_controller.gd")

var town_hub_controller: RefCounted

func setup(payload: Dictionary) -> void:
	super.setup(payload)
	town_hub_controller = TOWN_HUB_CONTROLLER_SCRIPT.new().configure(self)

func build_hud() -> Control:
	return preload("res://scripts/ui/town_hud.gd").new().configure(self)

func _process(delta: float) -> void:
	if town_world_presenter != null:
		town_world_presenter.call("animate_ambient")
		town_world_presenter.call("animate_focus_anchor")

func hud_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.hud_snapshot()
	snapshot["hudMode"] = "town"
	snapshot["townFocus"] = _town_focus_snapshot()
	return snapshot

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if town_hub_controller != null and bool(town_hub_controller.call("handle_key", event.keycode)):
			return
		match event.keycode:
			KEY_I:
				_toggle_inventory_overlay()
			KEY_R:
				_try_rest()
			KEY_T:
				GameApp.return_to_title()

func _controls_summary() -> String:
	if town_hub_controller != null:
		return String(town_hub_controller.call("controls_summary"))
	return "W path advance, A/D or Q/E hub focus, Left/Right turn, Space interact, I inventory, R rest, T title"

extends Node

signal route_changed(route: String)

const ROUTE_SCENES := {
	"title": "res://scenes/shell/TitleMenu.tscn",
	"town": "res://scenes/town/TownScene.tscn",
	"dungeon": "res://scenes/dungeon/DungeonScene.tscn",
	"combat": "res://scenes/combat/CombatScene.tscn",
	"editor": "res://scenes/editor_tools/EditorWorkspace.tscn"
}

var scene_host: Node
var hud_layer: CanvasLayer
var modal_layer: CanvasLayer
var transition_layer: CanvasLayer
var current_scene: Node
var current_hud: Control

func register_host(host_scene_host: Node, host_hud_layer: CanvasLayer, host_modal_layer: CanvasLayer, host_transition_layer: CanvasLayer) -> void:
	scene_host = host_scene_host
	hud_layer = host_hud_layer
	modal_layer = host_modal_layer
	transition_layer = host_transition_layer

func change_route(route: String, payload: Dictionary = {}) -> void:
	if scene_host == null:
		return
	_clear_current()
	var scene_path := String(ROUTE_SCENES.get(route, ROUTE_SCENES["title"]))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Missing scene for route: %s" % route)
		return
	current_scene = packed.instantiate()
	scene_host.add_child(current_scene)
	if current_scene.has_method("setup"):
		current_scene.call("setup", payload)
	if current_scene.has_method("build_hud"):
		current_hud = current_scene.call("build_hud")
		if current_hud != null:
			hud_layer.add_child(current_hud)
	emit_signal("route_changed", route)

func _clear_current() -> void:
	if current_hud != null:
		current_hud.queue_free()
		current_hud = null
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null

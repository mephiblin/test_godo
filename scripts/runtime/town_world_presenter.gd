extends RefCounted

var scene_ref: Node
var ambient_nodes: Array[Dictionary] = []

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func clear() -> void:
	ambient_nodes.clear()

func build_world() -> void:
	if scene_ref == null:
		return
	scene_ref.call("_build_town_world_content")

func register_ambient_node(node: Node3D, kind: String, data: Dictionary = {}) -> void:
	if node == null:
		return
	ambient_nodes.append({
		"node": node,
		"kind": kind,
		"basePosition": node.position,
		"baseRotation": node.rotation_degrees,
		"baseScale": node.scale,
		"data": data
	})

func animate_ambient() -> void:
	var time := float(Time.get_ticks_msec()) / 1000.0
	for entry in ambient_nodes:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var node: Node3D = entry.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var kind := String(entry.get("kind", ""))
		var base_position: Vector3 = entry.get("basePosition", node.position)
		var base_rotation: Vector3 = entry.get("baseRotation", node.rotation_degrees)
		var base_scale: Vector3 = entry.get("baseScale", node.scale)
		var data: Dictionary = entry.get("data", {})
		var speed := float(data.get("speed", 1.0))
		match kind:
			"actor_body":
				var bob := float(data.get("bob", 0.03))
				node.position = base_position + Vector3(0, sin(time * speed) * bob, 0)
				node.rotation_degrees = base_rotation + Vector3(0, sin(time * speed * 0.5) * 3.0, 0)
			"actor_head":
				var bob_head := float(data.get("bob", 0.02))
				node.position = base_position + Vector3(0, sin(time * speed + 0.4) * bob_head, 0)
				node.rotation_degrees = base_rotation + Vector3(0, sin(time * speed * 0.7) * 4.0, 0)
			"sway":
				var yaw_amplitude := float(data.get("yawAmplitude", 2.0))
				var roll_amplitude := float(data.get("rollAmplitude", 1.5))
				node.rotation_degrees = base_rotation + Vector3(0, sin(time * speed) * yaw_amplitude, sin(time * speed * 1.1) * roll_amplitude)
			"banner":
				var roll := float(data.get("rollAmplitude", 4.0))
				var yaw := float(data.get("yawAmplitude", 2.0))
				node.rotation_degrees = base_rotation + Vector3(0, sin(time * speed * 0.9) * yaw, sin(time * speed) * roll)
			"flame":
				var flicker := float(data.get("flicker", 0.16))
				node.scale = base_scale * (1.0 + sin(time * speed * 1.4) * flicker)
				node.position = base_position + Vector3(0, abs(sin(time * speed * 1.8)) * 0.04, 0)
			"light":
				if node is OmniLight3D:
					var light: OmniLight3D = node
					var energy := float(data.get("energy", 0.8))
					var flicker_scale := float(data.get("flicker", 0.16))
					light.light_energy = energy + sin(time * speed * 1.7) * flicker_scale
			"ember":
				var rise := float(data.get("rise", 0.28))
				var drift := float(data.get("drift", 0.08))
				var cycle := fposmod(time * speed, 1.0)
				node.position = base_position + Vector3(sin(cycle * TAU) * drift, cycle * rise, cos(cycle * TAU * 0.7) * drift * 0.45)
				node.scale = base_scale * (1.0 - cycle * 0.45)
			"mote":
				var bob_mote := float(data.get("bob", 0.07))
				var drift_mote := float(data.get("drift", 0.08))
				node.position = base_position + Vector3(
					sin(time * speed) * drift_mote,
					sin(time * speed * 1.4) * bob_mote,
					cos(time * speed * 0.9) * drift_mote * 0.5
				)

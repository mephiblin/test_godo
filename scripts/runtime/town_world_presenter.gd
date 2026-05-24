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
	_configure_lighting()
	var map_data: Dictionary = scene_ref.get("map_data")
	var cells: Array = map_data.get("cells", [])
	for y in range(cells.size()):
		var row := String(cells[y])
		for x in range(row.length()):
			var cell := Vector2i(x, y)
			if row[x] == "#":
				_spawn_boundary(cell)
			else:
				_spawn_ground(cell)
	for placement in map_data.get("placements", []):
		scene_ref.call("_spawn_town_placement", placement)
	scene_ref.call("_spawn_town_ambient_dressing")

func _configure_lighting() -> void:
	var sun: DirectionalLight3D = scene_ref.get("sun")
	if sun == null:
		return
	sun.light_color = Color("fff1d5")
	sun.light_energy = 1.55

func _spawn_ground(cell: Vector2i) -> void:
	var world_root: Node3D = scene_ref.get("world_root")
	if world_root == null:
		return
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.0, 0.08, 1.0)
	base.mesh = base_mesh
	base.material_override = _ground_material(cell)
	base.position = Vector3(cell.x, -0.04, cell.y)
	world_root.add_child(base)
	if _path_cells().has(_cell_key(cell)):
		var path := MeshInstance3D.new()
		var path_mesh := BoxMesh.new()
		path_mesh.size = Vector3(0.76, 0.03, 0.76)
		path.mesh = path_mesh
		path.material_override = _flat_color_material(Color("9f8964"))
		path.position = Vector3(cell.x, 0.005, cell.y)
		world_root.add_child(path)

func _spawn_boundary(cell: Vector2i) -> void:
	var world_root: Node3D = scene_ref.get("world_root")
	if world_root == null:
		return
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1.0, 1.0, 1.0)
	wall.mesh = wall_mesh
	wall.material_override = _flat_color_material(Color("6d5842"))
	wall.position = Vector3(cell.x, 0.48, cell.y)
	world_root.add_child(wall)
	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(1.04, 0.12, 1.04)
	cap.mesh = cap_mesh
	cap.material_override = _flat_color_material(Color("9f835f"))
	cap.position = Vector3(cell.x, 1.02, cell.y)
	world_root.add_child(cap)

func _ground_material(cell: Vector2i) -> StandardMaterial3D:
	var color := Color("5e6e53")
	if cell == Vector2i(2, 5):
		color = Color("708262")
	elif cell.y <= 3:
		color = Color("667758")
	elif cell.x >= 5:
		color = Color("5b694f")
	return _flat_color_material(color)

func _path_cells() -> Dictionary:
	var keys := {}
	for cell in [
		Vector2i(2, 5), Vector2i(2, 4), Vector2i(2, 3), Vector2i(2, 2),
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(5, 2),
		Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4),
		Vector2i(3, 2), Vector2i(4, 2), Vector2i(6, 2)
	]:
		keys[_cell_key(cell)] = true
	return keys

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _flat_color_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

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

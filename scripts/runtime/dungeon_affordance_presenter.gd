extends RefCounted

var scene_ref: Node

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func spawn_placement(placement: Dictionary) -> void:
	var placement_id := String(placement.get("id", ""))
	if placement_id == "":
		return
	var kind := String(placement.get("type", ""))
	var pos: Array = placement.get("position", [0, 0])
	var color: Color = scene_ref.call("_placement_runtime_color", placement)
	var world_root: Node3D = scene_ref.get("world_root")

	var marker := MeshInstance3D.new()
	marker.mesh = marker_mesh(kind)
	marker.position = Vector3(float(pos[0]), marker_height(kind), float(pos[1]))
	marker.scale = marker_scale(kind)
	marker.material_override = scene_ref.call("_marker_material", color)
	world_root.add_child(marker)
	var placement_nodes: Dictionary = scene_ref.get("placement_nodes")
	placement_nodes[placement_id] = marker

	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = ring_radius(kind)
	ring_mesh.bottom_radius = ring_radius(kind) + 0.08
	ring_mesh.height = 0.035
	ring.mesh = ring_mesh
	ring.position = Vector3(float(pos[0]), 0.035, float(pos[1]))
	ring.material_override = scene_ref.call("_flat_color_material", color.darkened(0.22))
	world_root.add_child(ring)
	var placement_rings: Dictionary = scene_ref.get("placement_rings")
	placement_rings[placement_id] = ring

	var intent := MeshInstance3D.new()
	intent.mesh = intent_mesh(kind)
	intent.position = Vector3(float(pos[0]), intent_height(kind), float(pos[1]))
	intent.scale = intent_scale(kind)
	intent.material_override = scene_ref.call("_marker_material", color.lightened(0.18))
	world_root.add_child(intent)
	var placement_intent_nodes: Dictionary = scene_ref.get("placement_intent_nodes")
	placement_intent_nodes[placement_id] = intent

func spawn_focus_marker() -> void:
	var world_root: Node3D = scene_ref.get("world_root")
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.34
	mesh.height = 0.12
	marker.mesh = mesh
	marker.visible = false
	marker.material_override = scene_ref.call("_flat_color_material", Color("f3e7b3"))
	world_root.add_child(marker)
	scene_ref.set("dungeon_focus_node", marker)

func animate_affordances() -> void:
	var time := float(Time.get_ticks_msec()) / 1000.0
	var map_data: Dictionary = scene_ref.get("map_data")
	var placement_intent_nodes: Dictionary = scene_ref.get("placement_intent_nodes")
	for placement in map_data.get("placements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var placement_id := String(placement.get("id", ""))
		var intent_node: MeshInstance3D = placement_intent_nodes.get(placement_id)
		if intent_node and is_instance_valid(intent_node) and intent_node.visible:
			var base_y := intent_height(String(placement.get("type", "")))
			intent_node.position.y = base_y + sin(time * 3.0 + float(abs(hash(placement_id)) % 7)) * 0.08
			intent_node.rotation_degrees.y = fposmod(time * 70.0, 360.0)
	var dungeon_focus_node: MeshInstance3D = scene_ref.get("dungeon_focus_node")
	if dungeon_focus_node and is_instance_valid(dungeon_focus_node) and dungeon_focus_node.visible:
		dungeon_focus_node.rotation_degrees.y = fposmod(time * 90.0, 360.0)
	var dungeon_focus_path_nodes: Array = scene_ref.get("dungeon_focus_path_nodes")
	for index in range(dungeon_focus_path_nodes.size()):
		var path_node: MeshInstance3D = dungeon_focus_path_nodes[index]
		if not path_node or not is_instance_valid(path_node):
			continue
		var base_y := float(path_node.get_meta("base_y", path_node.position.y))
		var pulse := float(path_node.get_meta("pulse", 0.025))
		var offset := float(path_node.get_meta("offset", index)) * 0.45
		path_node.position.y = base_y + sin(time * 4.2 + offset) * pulse
		if bool(path_node.get_meta("rotate", false)):
			path_node.rotation_degrees.y = fposmod(time * 110.0 + offset * 20.0, 360.0)

func clear_focus_path() -> void:
	var dungeon_focus_path_nodes: Array = scene_ref.get("dungeon_focus_path_nodes")
	for node in dungeon_focus_path_nodes:
		if node and is_instance_valid(node):
			node.queue_free()
	dungeon_focus_path_nodes.clear()

func spawn_focus_path(path: Array[Vector2i], placement: Dictionary, interaction: Dictionary) -> void:
	clear_focus_path()
	if path.size() <= 1:
		return
	var marker_indices := focus_path_marker_indices(path.size())
	if marker_indices.is_empty():
		return
	var color := focus_path_color(placement, interaction)
	var world_root: Node3D = scene_ref.get("world_root")
	var dungeon_focus_path_nodes: Array = scene_ref.get("dungeon_focus_path_nodes")
	for marker_number in range(marker_indices.size()):
		var idx := int(marker_indices[marker_number])
		var cell: Vector2i = path[idx]
		var is_next := idx == 1
		var is_final := idx == path.size() - 1
		var node := MeshInstance3D.new()
		node.mesh = focus_path_mesh(is_next, is_final, bool(interaction.get("blocked", false)))
		node.material_override = scene_ref.call("_flat_color_material", color.lightened(0.18 if is_next or is_final else 0.0))
		var base_y := focus_path_height(is_next, is_final, marker_number)
		node.position = Vector3(cell.x, base_y, cell.y)
		node.scale = focus_path_scale(is_next, is_final)
		node.set_meta("base_y", base_y)
		node.set_meta("pulse", 0.035 if is_next or is_final else 0.018)
		node.set_meta("offset", marker_number)
		node.set_meta("rotate", is_next or is_final)
		world_root.add_child(node)
		dungeon_focus_path_nodes.append(node)

func focus_path_marker_indices(path_size: int) -> Array[int]:
	var indices: Array[int] = []
	if path_size <= 1:
		return indices
	var last_index := path_size - 1
	indices.append(1)
	var stride := 1
	if path_size > 10:
		stride = 3
	elif path_size > 6:
		stride = 2
	for idx in range(2, last_index):
		if idx % stride == 0:
			indices.append(idx)
	if not indices.has(last_index):
		indices.append(last_index)
	if indices.size() > 8:
		var reduced: Array[int] = [indices[0]]
		var middle_stride := ceili(float(indices.size() - 2) / 6.0)
		for idx in range(1, indices.size() - 1):
			if idx % middle_stride == 0:
				reduced.append(indices[idx])
		reduced.append(indices[indices.size() - 1])
		return reduced
	return indices

func focus_path_color(placement: Dictionary, interaction: Dictionary) -> Color:
	if bool(interaction.get("blocked", false)):
		return Color("d8895f")
	match String(interaction.get("intent", "")):
		"combat", "event", "door":
			return Color("d96d5f")
		"reward":
			return Color("e2c861")
		"rest", "service":
			return Color("76c4a0")
		"route":
			return Color("88addd")
		_:
			var color: Color = scene_ref.call("_placement_runtime_color", placement)
			return color.lightened(0.18)

func focus_path_mesh(is_next: bool, is_final: bool, blocked: bool) -> Mesh:
	if is_final:
		if blocked:
			var blocked_mesh := BoxMesh.new()
			blocked_mesh.size = Vector3(0.36, 0.1, 0.36)
			return blocked_mesh
		var final_mesh := PrismMesh.new()
		final_mesh.size = Vector3(0.34, 0.22, 0.34)
		return final_mesh
	if is_next:
		var next_mesh := CylinderMesh.new()
		next_mesh.top_radius = 0.08
		next_mesh.bottom_radius = 0.18
		next_mesh.height = 0.12
		return next_mesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.055
	mesh.bottom_radius = 0.1
	mesh.height = 0.07
	return mesh

func focus_path_height(is_next: bool, is_final: bool, marker_number: int) -> float:
	if is_final:
		return 0.18
	if is_next:
		return 0.16
	return 0.12 + float(marker_number % 3) * 0.012

func focus_path_scale(is_next: bool, is_final: bool) -> Vector3:
	if is_final:
		return Vector3.ONE * 1.2
	if is_next:
		return Vector3.ONE * 1.12
	return Vector3.ONE

func marker_mesh(kind: String) -> Mesh:
	match kind:
		"gate", "stairs":
			var mesh := PrismMesh.new()
			mesh.size = Vector3(0.58, 0.72, 0.58)
			return mesh
		"locked_door", "secret_door":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.16, 0.78, 0.64)
			return mesh
		"field_monster":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.2
			mesh.bottom_radius = 0.26
			mesh.height = 0.86
			return mesh
		"event", "trap":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.28
			mesh.bottom_radius = 0.28
			mesh.height = 0.18
			return mesh
		"loot":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.46, 0.32, 0.34)
			return mesh
		"rest":
			var mesh := SphereMesh.new()
			mesh.radius = 0.24
			mesh.height = 0.36
			return mesh
		"npc_service":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.16
			mesh.bottom_radius = 0.2
			mesh.height = 0.72
			return mesh
		_:
			var mesh := SphereMesh.new()
			mesh.radius = 0.24
			mesh.height = 0.42
			return mesh

func intent_mesh(kind: String) -> Mesh:
	match kind:
		"gate", "stairs", "locked_door", "secret_door":
			var mesh := PrismMesh.new()
			mesh.size = Vector3(0.34, 0.34, 0.34)
			return mesh
		"trap":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.38, 0.08, 0.38)
			return mesh
		_:
			var mesh := SphereMesh.new()
			mesh.radius = 0.12
			mesh.height = 0.22
			return mesh

func marker_height(kind: String) -> float:
	match kind:
		"locked_door", "secret_door", "field_monster", "npc_service":
			return 0.42
		"gate", "stairs":
			return 0.46
		"event", "trap", "loot", "rest":
			return 0.18
		_:
			return 0.3

func intent_height(kind: String) -> float:
	match kind:
		"field_monster", "npc_service", "gate", "stairs":
			return 1.02
		"locked_door", "secret_door":
			return 0.92
		_:
			return 0.58

func marker_scale(kind: String) -> Vector3:
	match kind:
		"trap":
			return Vector3(1.0, 0.7, 1.0)
		"loot":
			return Vector3.ONE
		_:
			return Vector3.ONE

func intent_scale(kind: String) -> Vector3:
	if kind == "trap":
		return Vector3(1.0, 1.0, 1.0)
	return Vector3.ONE

func ring_radius(kind: String) -> float:
	match kind:
		"gate", "stairs", "field_monster":
			return 0.52
		"trap", "event":
			return 0.44
		_:
			return 0.38

extends RefCounted

var scene_ref: Node
var ambient_nodes: Array[Dictionary] = []
var focus_anchor_node: MeshInstance3D
var focus_path_nodes: Array[MeshInstance3D] = []

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func clear() -> void:
	ambient_nodes.clear()
	focus_anchor_node = null
	focus_path_nodes.clear()

func _world_root() -> Node3D:
	return scene_ref.get("world_root")

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
		spawn_placement(placement)
		scene_ref.call("_spawn_town_placement_beacon", placement)
	spawn_ambient_dressing()

func spawn_placement(placement: Dictionary) -> void:
	var kind := String(placement.get("type", ""))
	var pos: Array = placement.get("position", [0, 0])
	var cell := Vector2i(int(pos[0]), int(pos[1]))
	match kind:
		"quest_board":
			_spawn_board(cell, Color("7b5a35"), Color("d4c0a1"))
			_spawn_actor(cell + Vector2i(0, 1), "scribe")
		"healer":
			_spawn_tent(cell, Color("7fbfa2"), Color("d9e5d2"))
			_spawn_table(cell + Vector2i(0, 1), Color("c7b18a"))
			_spawn_actor(cell + Vector2i(0, 1), "healer")
		"skill_shop":
			_spawn_tent(cell, Color("7ca7d8"), Color("d9e5f4"))
			_spawn_weapon_rack(cell + Vector2i(0, 1))
			_spawn_actor(cell + Vector2i(0, 1), "merchant")
		"trade":
			_spawn_stall(cell, Color("c88c55"), Color("ead0ad"))
			_spawn_crates(cell + Vector2i(0, 1))
			_spawn_actor(cell + Vector2i(0, 1), "apothecary")
		"npc_service":
			_spawn_npc_landmark(placement, cell)
		"gate":
			_spawn_gate(cell, placement)
		"rest":
			_spawn_campfire(cell)
		_:
			pass

func spawn_ambient_dressing() -> void:
	for cell in [Vector2i(3, 5), Vector2i(4, 4), Vector2i(5, 5), Vector2i(6, 3)]:
		for index in range(3):
			var mote := MeshInstance3D.new()
			var mote_mesh := SphereMesh.new()
			mote_mesh.radius = 0.035
			mote_mesh.height = 0.07
			mote.mesh = mote_mesh
			mote.material_override = _flat_color_material(Color("c9c39a"))
			var base_offset := Vector3(
				-0.18 + float(index) * 0.16,
				0.72 + float(index) * 0.09,
				-0.12 + float((cell.x + index) % 3) * 0.1
			)
			mote.position = Vector3(cell.x, 0.0, cell.y) + base_offset
			_world_root().add_child(mote)
			register_ambient_node(mote, "mote", {
				"bob": 0.07 + float(index) * 0.02,
				"drift": 0.09 + float(index) * 0.02,
				"speed": 0.65 + float(index) * 0.18
			})

func update_focus_visuals(selected_id: String) -> void:
	_update_focus_anchor(selected_id)
	_update_focus_path(selected_id)

func animate_focus_anchor() -> void:
	if not focus_anchor_node or not is_instance_valid(focus_anchor_node) or not focus_anchor_node.visible:
		return
	var pulse := 1.0 + 0.1 * sin(Time.get_ticks_msec() / 160.0)
	var base_scale: Vector3 = focus_anchor_node.get_meta("base_scale", Vector3.ONE)
	focus_anchor_node.scale = Vector3(base_scale.x * pulse, base_scale.y, base_scale.z * pulse)
	focus_anchor_node.position.y = 0.03 + 0.01 * sin(Time.get_ticks_msec() / 220.0)

func _ensure_focus_anchor_node() -> void:
	if focus_anchor_node and is_instance_valid(focus_anchor_node):
		return
	var node := MeshInstance3D.new()
	node.mesh = _focus_anchor_mesh("")
	node.material_override = _flat_color_material(Color("f3e7b3"))
	node.visible = false
	_world_root().add_child(node)
	focus_anchor_node = node

func _clear_focus_path_nodes() -> void:
	for node in focus_path_nodes:
		if node and is_instance_valid(node):
			node.queue_free()
	focus_path_nodes.clear()

func _update_focus_anchor(selected_id: String) -> void:
	_ensure_focus_anchor_node()
	if not focus_anchor_node or not is_instance_valid(focus_anchor_node):
		return
	if selected_id == "":
		focus_anchor_node.visible = false
		return
	var map_data: Dictionary = scene_ref.get("map_data")
	for placement in map_data.get("placements", []):
		if String(placement.get("id", "")) != selected_id:
			continue
		var kind := String(placement.get("type", ""))
		var anchor: Vector2i = scene_ref.call("_town_interaction_anchor_cell", placement)
		focus_anchor_node.visible = true
		focus_anchor_node.mesh = _focus_anchor_mesh(kind)
		focus_anchor_node.position = Vector3(anchor.x, 0.03, anchor.y)
		focus_anchor_node.material_override = _focus_anchor_material(kind)
		var base_scale := _focus_anchor_scale(kind)
		focus_anchor_node.scale = base_scale
		focus_anchor_node.set_meta("base_scale", base_scale)
		return
	focus_anchor_node.visible = false

func _update_focus_path(selected_id: String) -> void:
	_clear_focus_path_nodes()
	if selected_id == "":
		return
	var map_data: Dictionary = scene_ref.get("map_data")
	for placement in map_data.get("placements", []):
		if String(placement.get("id", "")) != selected_id:
			continue
		var anchor: Vector2i = scene_ref.call("_town_interaction_anchor_cell", placement)
		var path: Array = scene_ref.call("_town_path_to_anchor", anchor)
		if path.size() <= 1:
			return
		var color: Color = scene_ref.call("_placement_runtime_color", placement)
		color = color.lightened(0.08)
		for idx in range(1, path.size()):
			var cell: Vector2i = path[idx]
			var node := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.08 if idx < path.size() - 1 else 0.12
			mesh.height = 0.16 if idx < path.size() - 1 else 0.24
			node.mesh = mesh
			node.material_override = _flat_color_material(color)
			node.position = Vector3(cell.x, 0.08, cell.y)
			_world_root().add_child(node)
			focus_path_nodes.append(node)
		return

func _focus_anchor_material(kind: String) -> StandardMaterial3D:
	var color: Color = scene_ref.call("_placement_runtime_color", {"type": kind})
	return _flat_color_material(color.lightened(0.18))

func _focus_anchor_scale(kind: String) -> Vector3:
	match kind:
		"quest_board":
			return Vector3(1.18, 1.0, 1.18)
		"skill_shop", "trade":
			return Vector3(1.06, 1.0, 1.06)
		"npc_service":
			return Vector3(0.98, 1.0, 0.98)
		"healer", "rest":
			return Vector3(0.9, 1.0, 0.9)
		_:
			return Vector3.ONE

func _focus_anchor_mesh(kind: String) -> PrimitiveMesh:
	match kind:
		"quest_board":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.7, 0.03, 0.7)
			return mesh
		"healer", "rest":
			var mesh := SphereMesh.new()
			mesh.radius = 0.22
			mesh.height = 0.12
			return mesh
		"skill_shop":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.18
			mesh.bottom_radius = 0.34
			mesh.height = 0.05
			return mesh
		"trade":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.34
			mesh.bottom_radius = 0.18
			mesh.height = 0.05
			return mesh
		"npc_service":
			var mesh := SphereMesh.new()
			mesh.radius = 0.16
			mesh.height = 0.3
			return mesh
		_:
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.34
			mesh.bottom_radius = 0.34
			mesh.height = 0.03
			return mesh

func _spawn_board(cell: Vector2i, wood_color: Color, face_color: Color) -> void:
	_spawn_post_pair(cell, wood_color)
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.72, 0.6, 0.1)
	board.mesh = board_mesh
	board.material_override = _flat_color_material(face_color)
	board.position = Vector3(cell.x, 0.75, cell.y - 0.18)
	_world_root().add_child(board)

func _spawn_tent(cell: Vector2i, cloth_color: Color, pole_color: Color) -> void:
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(0.9, 0.45, 0.8)
	roof.mesh = roof_mesh
	roof.material_override = _flat_color_material(cloth_color)
	roof.position = Vector3(cell.x, 0.82, cell.y)
	_world_root().add_child(roof)
	register_ambient_node(roof, "sway", {"yawAmplitude": 2.2, "rollAmplitude": 1.8, "speed": 0.95 + float(cell.x % 3) * 0.07})
	_spawn_post_pair(cell, pole_color)

func _spawn_stall(cell: Vector2i, cloth_color: Color, wood_color: Color) -> void:
	_spawn_tent(cell, cloth_color, wood_color)
	var counter := MeshInstance3D.new()
	var counter_mesh := BoxMesh.new()
	counter_mesh.size = Vector3(0.86, 0.44, 0.34)
	counter.mesh = counter_mesh
	counter.material_override = _flat_color_material(wood_color)
	counter.position = Vector3(cell.x, 0.2, cell.y + 0.26)
	_world_root().add_child(counter)

func _spawn_gate(cell: Vector2i, placement: Dictionary) -> void:
	var is_open := String(scene_ref.call("_route_block_message", placement)) == ""
	for side in [-1, 1]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.22, 1.35, 0.22)
		pillar.mesh = pillar_mesh
		pillar.material_override = _flat_color_material(Color("8d7758"))
		pillar.position = Vector3(cell.x + 0.34 * side, 0.62, cell.y)
		_world_root().add_child(pillar)
	var arch := MeshInstance3D.new()
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(0.95, 0.18, 0.24)
	arch.mesh = arch_mesh
	arch.material_override = _flat_color_material(Color("c9b07c") if is_open else Color("8c6551"))
	arch.position = Vector3(cell.x, 1.18, cell.y)
	_world_root().add_child(arch)
	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(0.52, 0.44, 0.06)
	banner.mesh = banner_mesh
	banner.material_override = _flat_color_material(Color("d7c27a") if is_open else Color("9a6c57"))
	banner.position = Vector3(cell.x, 0.86, cell.y - 0.18)
	_world_root().add_child(banner)
	register_ambient_node(banner, "banner", {"yawAmplitude": 5.0, "rollAmplitude": 3.0, "speed": 1.15})
	for side in [-1, 1]:
		var lamp := MeshInstance3D.new()
		var lamp_mesh := SphereMesh.new()
		lamp_mesh.radius = 0.08
		lamp_mesh.height = 0.16
		lamp.mesh = lamp_mesh
		lamp.material_override = _flat_color_material(Color("f0cf7b"))
		lamp.position = Vector3(cell.x + 0.26 * side, 0.72, cell.y - 0.06)
		_world_root().add_child(lamp)
		var glow := OmniLight3D.new()
		glow.light_color = Color("ffd18a")
		glow.light_energy = 0.8
		glow.omni_range = 3.0
		glow.position = lamp.position
		_world_root().add_child(glow)
		register_ambient_node(glow, "light", {"energy": 0.8, "flicker": 0.18, "speed": 1.4 + float(side) * 0.1})

func _spawn_campfire(cell: Vector2i) -> void:
	var logs := MeshInstance3D.new()
	var logs_mesh := CylinderMesh.new()
	logs_mesh.top_radius = 0.08
	logs_mesh.bottom_radius = 0.08
	logs_mesh.height = 0.54
	logs.mesh = logs_mesh
	logs.rotation_degrees = Vector3(0, 0, 90)
	logs.material_override = _flat_color_material(Color("6d4d2d"))
	logs.position = Vector3(cell.x, 0.08, cell.y)
	_world_root().add_child(logs)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.16
	flame_mesh.height = 0.28
	flame.mesh = flame_mesh
	flame.material_override = _flat_color_material(Color("f39d53"))
	flame.position = Vector3(cell.x, 0.24, cell.y)
	_world_root().add_child(flame)
	register_ambient_node(flame, "flame", {"scale": Vector3(1.0, 1.0, 1.0), "flicker": 0.18, "speed": 2.4})
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffb66b")
	glow.light_energy = 1.1
	glow.omni_range = 3.8
	glow.position = Vector3(cell.x, 0.34, cell.y)
	_world_root().add_child(glow)
	register_ambient_node(glow, "light", {"energy": 1.1, "flicker": 0.22, "speed": 2.2})
	for index in range(5):
		var ember := MeshInstance3D.new()
		var ember_mesh := SphereMesh.new()
		ember_mesh.radius = 0.04
		ember_mesh.height = 0.08
		ember.mesh = ember_mesh
		ember.material_override = _flat_color_material(Color("ffcc7a"))
		var offset := Vector3(
			-0.16 + float(index) * 0.08,
			0.22 + float(index % 2) * 0.05,
			-0.08 + float(index % 3) * 0.06
		)
		ember.position = Vector3(cell.x, 0.0, cell.y) + offset
		_world_root().add_child(ember)
		register_ambient_node(ember, "ember", {
			"rise": 0.26 + float(index) * 0.03,
			"drift": 0.08 + float(index) * 0.01,
			"speed": 1.35 + float(index) * 0.22
		})

func _spawn_npc_landmark(placement: Dictionary, cell: Vector2i) -> void:
	var npc_id := String(placement.get("npcId", ""))
	match npc_id:
		"npc_scholar":
			_spawn_board(cell, Color("5f4c36"), Color("d4d0bf"))
			_spawn_table(cell + Vector2i(0, 1), Color("b8aa8b"))
			_spawn_actor(cell + Vector2i(0, 1), "scholar")
		"npc_exile_scout":
			_spawn_tent(cell, Color("967a57"), Color("ddd3c1"))
			_spawn_actor(cell + Vector2i(0, 1), "scout")
		"npc_trainer":
			_spawn_tent(cell, Color("8d5f4e"), Color("efe4d3"))
			_spawn_weapon_rack(cell + Vector2i(-1, 0))
			_spawn_actor(cell + Vector2i(0, 1), "trainer")
		"npc_gatekeeper":
			_spawn_board(cell, Color("72573d"), Color("cab48f"))
			_spawn_actor(cell + Vector2i(0, 1), "gatekeeper")
		"npc_wounded_mystic":
			_spawn_tent(cell, Color("5b6d84"), Color("d8d4c8"))
			_spawn_actor(cell + Vector2i(0, 1), "mystic")
		"npc_deserter_captain":
			_spawn_board(cell, Color("7c5a48"), Color("d6c29b"))
			_spawn_actor(cell + Vector2i(0, 1), "captain")
		_:
			_spawn_table(cell, Color("bca889"))
			_spawn_actor(cell + Vector2i(0, 1), "townsfolk")

func _spawn_table(cell: Vector2i, color: Color) -> void:
	var table := MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(0.62, 0.28, 0.38)
	table.mesh = table_mesh
	table.material_override = _flat_color_material(color)
	table.position = Vector3(cell.x, 0.16, cell.y)
	_world_root().add_child(table)

func _spawn_crates(cell: Vector2i) -> void:
	for offset in [Vector3(-0.18, 0.12, 0.04), Vector3(0.16, 0.12, -0.08)]:
		var crate := MeshInstance3D.new()
		var crate_mesh := BoxMesh.new()
		crate_mesh.size = Vector3(0.26, 0.24, 0.26)
		crate.mesh = crate_mesh
		crate.material_override = _flat_color_material(Color("a7794e"))
		crate.position = Vector3(cell.x, 0, cell.y) + offset
		_world_root().add_child(crate)

func _spawn_weapon_rack(cell: Vector2i) -> void:
	var rack := MeshInstance3D.new()
	var rack_mesh := BoxMesh.new()
	rack_mesh.size = Vector3(0.62, 0.72, 0.14)
	rack.mesh = rack_mesh
	rack.material_override = _flat_color_material(Color("8c7150"))
	rack.position = Vector3(cell.x, 0.36, cell.y)
	_world_root().add_child(rack)
	for side in [-1, 1]:
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.08, 0.54, 0.04)
		blade.mesh = blade_mesh
		blade.material_override = _flat_color_material(Color("cfd7dc"))
		blade.position = Vector3(cell.x + 0.14 * side, 0.52, cell.y)
		_world_root().add_child(blade)

func _spawn_actor(cell: Vector2i, role: String) -> void:
	var palette := _actor_palette(role)
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.14
	body_mesh.bottom_radius = 0.16
	body_mesh.height = 0.64
	body.mesh = body_mesh
	body.material_override = _flat_color_material(palette.get("body", Color("8a7b68")))
	body.position = Vector3(cell.x, 0.38, cell.y)
	_world_root().add_child(body)
	register_ambient_node(body, "actor_body", {"bob": 0.035, "speed": 1.2 + float(abs(hash(role)) % 5) * 0.09})

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.12
	head_mesh.height = 0.24
	head.mesh = head_mesh
	head.material_override = _flat_color_material(palette.get("skin", Color("d7b18a")))
	head.position = Vector3(cell.x, 0.9, cell.y - 0.02)
	_world_root().add_child(head)
	register_ambient_node(head, "actor_head", {"bob": 0.028, "speed": 1.35 + float(abs(hash(role)) % 7) * 0.05})

	if bool(palette.get("hood", false)):
		var hood := MeshInstance3D.new()
		var hood_mesh := SphereMesh.new()
		hood_mesh.radius = 0.145
		hood_mesh.height = 0.2
		hood.mesh = hood_mesh
		hood.material_override = _flat_color_material(palette.get("hoodColor", palette.get("body", Color("6c5c74"))))
		hood.position = Vector3(cell.x, 0.94, cell.y - 0.02)
		hood.scale = Vector3(1.0, 0.72, 1.0)
		_world_root().add_child(hood)
		register_ambient_node(hood, "actor_head", {"bob": 0.025, "speed": 1.28 + float(abs(hash(role + "_hood")) % 5) * 0.04})

	if bool(palette.get("staff", false)):
		var staff := MeshInstance3D.new()
		var staff_mesh := CylinderMesh.new()
		staff_mesh.top_radius = 0.03
		staff_mesh.bottom_radius = 0.03
		staff_mesh.height = 0.92
		staff.mesh = staff_mesh
		staff.material_override = _flat_color_material(Color("7d6549"))
		staff.position = Vector3(cell.x + 0.18, 0.48, cell.y + 0.08)
		_world_root().add_child(staff)
		register_ambient_node(staff, "sway", {"yawAmplitude": 1.6, "rollAmplitude": 1.2, "speed": 0.85})

	if bool(palette.get("crate", false)):
		var satchel := MeshInstance3D.new()
		var satchel_mesh := BoxMesh.new()
		satchel_mesh.size = Vector3(0.18, 0.16, 0.12)
		satchel.mesh = satchel_mesh
		satchel.material_override = _flat_color_material(Color("8a6b47"))
		satchel.position = Vector3(cell.x - 0.18, 0.18, cell.y + 0.04)
		_world_root().add_child(satchel)

	if bool(palette.get("banner", false)):
		var sash := MeshInstance3D.new()
		var sash_mesh := BoxMesh.new()
		sash_mesh.size = Vector3(0.08, 0.42, 0.04)
		sash.mesh = sash_mesh
		sash.material_override = _flat_color_material(palette.get("accent", Color("d7c27a")))
		sash.position = Vector3(cell.x + 0.08, 0.46, cell.y + 0.02)
		sash.rotation_degrees = Vector3(0, 0, 16)
		_world_root().add_child(sash)
		register_ambient_node(sash, "banner", {"yawAmplitude": 0.0, "rollAmplitude": 6.0, "speed": 1.55})

func _actor_palette(role: String) -> Dictionary:
	match role:
		"scribe":
			return {"body": Color("7b6b55"), "skin": Color("d8b78f"), "hood": false, "crate": true}
		"healer":
			return {"body": Color("73a58c"), "skin": Color("d9bea0"), "hood": true, "hoodColor": Color("5f8b75"), "staff": false}
		"merchant":
			return {"body": Color("557ba0"), "skin": Color("d8b28a"), "hood": false, "crate": true, "banner": true, "accent": Color("cfd7dc")}
		"apothecary":
			return {"body": Color("b17e4b"), "skin": Color("ddb78d"), "hood": false, "crate": true}
		"scholar":
			return {"body": Color("7b756b"), "skin": Color("d3b08a"), "hood": true, "hoodColor": Color("64605a"), "staff": true}
		"scout":
			return {"body": Color("8c7252"), "skin": Color("cfab84"), "hood": false, "banner": true, "accent": Color("ddd3c1")}
		"trainer":
			return {"body": Color("8d5f4e"), "skin": Color("d5af86"), "hood": false, "banner": true, "accent": Color("e8d7c2")}
		"gatekeeper":
			return {"body": Color("6b573f"), "skin": Color("d7b28b"), "hood": false, "staff": true, "banner": true, "accent": Color("d7c27a")}
		"mystic":
			return {"body": Color("5a6786"), "skin": Color("d8b597"), "hood": true, "hoodColor": Color("45526f"), "staff": true}
		"captain":
			return {"body": Color("7d5649"), "skin": Color("d6ae85"), "hood": false, "staff": true, "banner": true, "accent": Color("caa06b")}
		_:
			return {"body": Color("7f7568"), "skin": Color("d7b692"), "hood": false}

func _spawn_post_pair(cell: Vector2i, color: Color) -> void:
	for side in [-1, 1]:
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.04
		post_mesh.bottom_radius = 0.04
		post_mesh.height = 1.0
		post.mesh = post_mesh
		post.material_override = _flat_color_material(color)
		post.position = Vector3(cell.x + 0.24 * side, 0.5, cell.y + 0.1)
		_world_root().add_child(post)

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

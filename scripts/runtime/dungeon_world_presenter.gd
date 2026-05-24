extends RefCounted

const DIRS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]

var scene_ref: Node
var cached_materials: Dictionary = {}
var decor_cells: Dictionary = {}
var chunk_overlay_nodes: Array[Node3D] = []

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func clear() -> void:
	cached_materials.clear()
	decor_cells.clear()
	chunk_overlay_nodes.clear()

func build_world() -> void:
	cached_materials.clear()
	chunk_overlay_nodes.clear()
	decor_cells = build_decor_cells()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(1.0, 0.12, 1.0)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1.0, 1.8, 1.0)
	var ceiling_mesh := BoxMesh.new()
	ceiling_mesh.size = Vector3(1.0, 0.1, 1.0)
	var map_data: Dictionary = scene_ref.get("map_data")
	var wall_material := resolve_surface_material(String(map_data.get("wallMaterialId", "")), Color("7a6a57"))
	var ceiling_material := resolve_surface_material(String(map_data.get("ceilingMaterialId", "")), Color("42382d"))
	var cells: Array = map_data.get("cells", [])
	for y in range(cells.size()):
		var row := String(cells[y])
		for x in range(row.length()):
			var tile := row[x]
			if tile == "#":
				var wall := MeshInstance3D.new()
				wall.mesh = wall_mesh
				wall.material_override = wall_material
				wall.position = Vector3(x, 0.5, y)
				wall.scale = Vector3(1, 1, 1)
				_world_root().add_child(wall)
			else:
				var tile_role := tile_role_at(Vector2i(x, y))
				var floor := MeshInstance3D.new()
				floor.mesh = floor_mesh
				floor.material_override = material_for_tile_role(tile_role)
				floor.position = Vector3(x, -0.06, y)
				_world_root().add_child(floor)
				var ceiling := MeshInstance3D.new()
				ceiling.mesh = ceiling_mesh
				ceiling.material_override = ceiling_material
				ceiling.position = Vector3(x, 1.78, y)
				_world_root().add_child(ceiling)
				spawn_decor_for_cell(Vector2i(x, y), tile_role)
	for placement in map_data.get("placements", []):
		scene_ref.call("_spawn_dungeon_placement", placement)
	scene_ref.call("_spawn_dungeon_focus_marker")
	spawn_chunk_overlay()

func active_chunk_label() -> String:
	var compiled_preview: Dictionary = scene_ref.get("compiled_preview")
	var layout_entries: Array = compiled_preview.get("chunkLayout", [])
	if layout_entries.is_empty():
		return "-"
	var map_data: Dictionary = scene_ref.get("map_data")
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var map_size: Array = map_data.get("size", [8, 8])
	var normalized_x := clampf(float(player_cell.x) / maxi(float(map_size[0]) - 1.0, 1.0), 0.0, 0.9999)
	var normalized_y := clampf(float(player_cell.y) / maxi(float(map_size[1]) - 1.0, 1.0), 0.0, 0.9999)
	var grid_meta: Dictionary = compiled_preview.get("chunkGrid", {})
	var grid_width := maxi(int(grid_meta.get("width", 1)), 1)
	var grid_height := maxi(int(grid_meta.get("height", 1)), 1)
	var target_x := mini(int(floor(normalized_x * float(grid_width))), grid_width - 1)
	var target_y := mini(int(floor(normalized_y * float(grid_height))), grid_height - 1)
	for entry in layout_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var layout_pos: Array = entry.get("layoutPos", [0, 0])
		if int(layout_pos[0]) == target_x and int(layout_pos[1]) == target_y:
			return "%s (%s)" % [String(entry.get("id", "")), String(entry.get("presetId", ""))]
	return "-"

func spawn_chunk_overlay() -> void:
	var compiled_preview: Dictionary = scene_ref.get("compiled_preview")
	var layout_entries: Array = compiled_preview.get("chunkLayout", [])
	if layout_entries.is_empty():
		return
	var grid_meta: Dictionary = compiled_preview.get("chunkGrid", {})
	var grid_width := maxi(int(grid_meta.get("width", 1)), 1)
	var grid_height := maxi(int(grid_meta.get("height", 1)), 1)
	var map_data: Dictionary = scene_ref.get("map_data")
	var map_size: Array = map_data.get("size", [8, 8])
	var map_width := maxi(float(map_size[0]) - 2.0, 1.0)
	var map_height := maxi(float(map_size[1]) - 2.0, 1.0)
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.55, 0.18, 0.55)
	for entry in layout_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var layout_pos: Array = entry.get("layoutPos", [0, 0])
		var gx := float(layout_pos[0])
		var gy := float(layout_pos[1])
		var world_x := 1.0 + ((gx + 0.5) / float(grid_width)) * map_width
		var world_y := 1.0 + ((gy + 0.5) / float(grid_height)) * map_height
		var node := MeshInstance3D.new()
		node.mesh = box_mesh
		node.material_override = chunk_overlay_material(entry)
		node.position = Vector3(world_x, 0.11, world_y)
		_world_root().add_child(node)
		chunk_overlay_nodes.append(node)
	var anchor_mesh := SphereMesh.new()
	anchor_mesh.radius = 0.1
	anchor_mesh.height = 0.2
	for anchor in compiled_preview.get("anchorLayout", []):
		if typeof(anchor) != TYPE_DICTIONARY:
			continue
		var ax := float(anchor.get("x", 0))
		var ay := float(anchor.get("y", 0))
		var chunk_cell_width := maxi(float(grid_meta.get("cellWidth", 1)), 1.0)
		var chunk_cell_height := maxi(float(grid_meta.get("cellHeight", 1)), 1.0)
		var preview_width := maxi(float(grid_width) * chunk_cell_width, 1.0)
		var preview_height := maxi(float(grid_height) * chunk_cell_height, 1.0)
		var world_x := 1.0 + ((ax + 0.5) / preview_width) * map_width
		var world_y := 1.0 + ((ay + 0.5) / preview_height) * map_height
		var node := MeshInstance3D.new()
		node.mesh = anchor_mesh
		node.material_override = anchor_overlay_material(String(anchor.get("kind", "")))
		node.position = Vector3(world_x, 0.3, world_y)
		_world_root().add_child(node)
		chunk_overlay_nodes.append(node)
	for placement in compiled_preview.get("generatedPlacements", []):
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var pos: Array = placement.get("position", [0, 0])
		var node := MeshInstance3D.new()
		node.mesh = BoxMesh.new()
		node.material_override = generated_overlay_material(String(placement.get("type", "")))
		node.position = Vector3(float(pos[0]), 0.52, float(pos[1]))
		node.scale = Vector3(0.22, 0.22, 0.22)
		_world_root().add_child(node)
		chunk_overlay_nodes.append(node)

func chunk_overlay_material(entry: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var role_tags: Array = entry.get("roleTags", [])
	var color := Color("4d7ea8")
	if role_tags.has("boss"):
		color = Color("9a4d4d")
	elif role_tags.has("reward"):
		color = Color("8f7a38")
	elif role_tags.has("combat"):
		color = Color("6b5aa8")
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func anchor_overlay_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var color := Color("d7d7d7")
	match kind:
		"loot":
			color = Color("d9bd5a")
		"boss_spawn":
			color = Color("c85f5f")
		"encounter":
			color = Color("9961c9")
		"junction":
			color = Color("59a7b5")
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func generated_overlay_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var color := Color("c2c2c2")
	match kind:
		"loot":
			color = Color("d8b74e")
		"field_monster":
			color = Color("b95c7a")
		"rest":
			color = Color("58a36b")
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func tile_role_at(cell: Vector2i) -> String:
	var openings: Array[String] = []
	for pair in [
		{"dir": Vector2i(0, -1), "name": "north"},
		{"dir": Vector2i(1, 0), "name": "east"},
		{"dir": Vector2i(0, 1), "name": "south"},
		{"dir": Vector2i(-1, 0), "name": "west"}
	]:
		if not is_wall(cell + pair["dir"]):
			openings.append(String(pair["name"]))
	if openings.size() <= 1:
		return "end_cap"
	if openings.size() == 2:
		var straight := openings.has("north") and openings.has("south") or openings.has("east") and openings.has("west")
		return "corridor" if straight else "corner"
	if openings.size() == 3:
		return "junction"
	return "intersection"

func is_wall(cell: Vector2i) -> bool:
	var map_data: Dictionary = scene_ref.get("map_data")
	var cells: Array = map_data.get("cells", [])
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := String(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	return row[cell.x] == "#"

func material_for_tile_role(tile_role: String) -> Material:
	var map_data: Dictionary = scene_ref.get("map_data")
	var map_profile: Dictionary = scene_ref.get("map_profile")
	var theme_id := String(map_data.get("themeId", map_profile.get("theme", "")))
	for substitution in ContentRegistry.find_tile_substitutions(theme_id, "floor"):
		var roles: Array = substitution.get("whenTileRoles", [])
		if roles.has(tile_role):
			var variants: Array = substitution.get("variants", [])
			if not variants.is_empty():
				var variant_index: int = int(abs(hash("%s:%s:%s" % [map_data.get("id", ""), tile_role, map_profile.get("id", "")])) % variants.size())
				var variant: Dictionary = variants[variant_index]
				return resolve_surface_material(String(variant.get("materialId", "")), Color("443c34"))
	return resolve_surface_material(String(map_data.get("defaultFloorMaterialId", "")), Color("443c34"))

func resolve_surface_material(material_id: String, fallback_color: Color) -> StandardMaterial3D:
	if cached_materials.has(material_id):
		return cached_materials[material_id]
	var material := StandardMaterial3D.new()
	var definition := ContentRegistry.get_definition("materials", material_id)
	var color_string := String(definition.get("baseColor", definition.get("fallbackColor", "")))
	material.albedo_color = Color(color_string) if color_string != "" else fallback_color
	material.roughness = float(definition.get("roughness", 1.0))
	material.metallic = float(definition.get("metalness", 0.0))
	material.emission_enabled = float(definition.get("emissiveIntensity", 0.0)) > 0.0
	if material.emission_enabled:
		material.emission = Color(String(definition.get("emissive", "#000000")))
		material.emission_energy_multiplier = float(definition.get("emissiveIntensity", 0.0))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if material_id != "":
		cached_materials[material_id] = material
	return material

func build_decor_cells() -> Dictionary:
	var result := {}
	var object_theme: Dictionary = scene_ref.get("object_theme")
	var map_data: Dictionary = scene_ref.get("map_data")
	var decor_list: Array = object_theme.get("decor", [])
	if decor_list.is_empty():
		return result
	var open_cells: Array[Vector2i] = []
	var start: Array = map_data.get("start", [0, 0])
	var start_cell := Vector2i(int(start[0]), int(start[1]))
	var cells: Array = map_data.get("cells", [])
	for y in range(cells.size()):
		var row := String(cells[y])
		for x in range(row.length()):
			if row[x] != "#":
				open_cells.append(Vector2i(x, y))
	open_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return abs(a.x - start_cell.x) + abs(a.y - start_cell.y) < abs(b.x - start_cell.x) + abs(b.y - start_cell.y)
	)
	for decor in decor_list:
		if typeof(decor) != TYPE_DICTIONARY:
			continue
		var max_per_map := maxi(int(decor.get("maxPerMap", 0)), 0)
		if max_per_map <= 0:
			continue
		var placed := 0
		for cell in open_cells:
			if placed >= max_per_map:
				break
			if cell == start_cell:
				continue
			if cell_has_placement(cell):
				continue
			var tile_role := tile_role_at(cell)
			if not decor.get("tileRoles", []).has(tile_role):
				continue
			if placed > 0:
				var pick: int = int(abs(hash("%s:%s:%s" % [decor.get("kind", ""), cell, map_data.get("id", "")])) % 100)
				if pick >= int(decor.get("weight", 1)) * 14:
					continue
			result["%d,%d" % [cell.x, cell.y]] = decor
			placed += 1
	return result

func cell_has_placement(cell: Vector2i) -> bool:
	var map_data: Dictionary = scene_ref.get("map_data")
	for placement in map_data.get("placements", []):
		var pos: Array = placement.get("position", [0, 0])
		if Vector2i(pos[0], pos[1]) == cell:
			return true
	return false

func spawn_decor_for_cell(cell: Vector2i, tile_role: String) -> void:
	var decor: Dictionary = decor_cells.get("%d,%d" % [cell.x, cell.y], {})
	if decor.is_empty():
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = decor_mesh(String(decor.get("kind", "")))
	mesh_instance.material_override = decor_material(String(decor.get("color", "#a98d68")))
	mesh_instance.position = Vector3(cell.x, 0.18, cell.y)
	mesh_instance.scale = decor_scale(String(decor.get("kind", "")), tile_role)
	_world_root().add_child(mesh_instance)

func decor_mesh(kind: String) -> Mesh:
	match kind:
		"torch", "broken_pillar":
			return CylinderMesh.new()
		"bones", "ritual_bowl":
			return SphereMesh.new()
		_:
			return BoxMesh.new()

func decor_material(color_code: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color_code)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func decor_scale(kind: String, tile_role: String) -> Vector3:
	match kind:
		"torch":
			return Vector3(0.16, 1.4, 0.16)
		"broken_pillar":
			return Vector3(0.3, 1.25, 0.3)
		"bones":
			return Vector3(0.18, 0.08, 0.28)
		"ritual_bowl":
			return Vector3(0.18, 0.08, 0.18)
		_:
			return Vector3(0.28, 0.24 if tile_role == "corridor" else 0.32, 0.28)

func _world_root() -> Node3D:
	return scene_ref.get("world_root")

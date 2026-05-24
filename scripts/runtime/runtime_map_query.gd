extends RefCounted

const DIRS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]

var scene_ref: Node

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

func is_blocked(cell: Vector2i) -> bool:
	var map_data: Dictionary = scene_ref.get("map_data")
	var cells: Array = map_data.get("cells", [])
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := String(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	if row[cell.x] == "#":
		return true
	for placement in map_data.get("placements", []):
		var placement_cell := placement_runtime_cell(placement)
		if placement_cell != cell:
			continue
		if String(placement.get("type", "")) == "locked_door" and bool(placement.get("blocking", false)):
			var slot_data: Dictionary = SaveService.load_slot(int(scene_ref.get("current_slot")))
			var runtime: Dictionary = slot_data.get("runtime", {})
			var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
			if not bool(unlocked_doors.get(String(placement.get("id", "")), false)):
				return true
		if String(placement.get("type", "")) == "secret_door":
			var slot_data: Dictionary = SaveService.load_slot(int(scene_ref.get("current_slot")))
			var runtime: Dictionary = slot_data.get("runtime", {})
			var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
			if not bool(discovered_secrets.get(String(placement.get("id", "")), false)):
				return true
		if String(placement.get("type", "")) == "field_monster" and bool(placement.get("blocking", false)):
			var slot_data: Dictionary = SaveService.load_slot(int(scene_ref.get("current_slot")))
			var runtime: Dictionary = slot_data.get("runtime", {})
			var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
			var state: Dictionary = field_monsters.get(String(placement.get("id", "")), {})
			if not bool(state.get("defeated", false)):
				return true
	return false

func front_interaction_placement() -> Dictionary:
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var facing := int(scene_ref.get("facing"))
	var target_cell: Vector2i = player_cell + DIRS[facing]
	var map_data: Dictionary = scene_ref.get("map_data")
	for placement in map_data.get("placements", []):
		if placement_runtime_cell(placement) == target_cell:
			return placement
	return {}

func dungeon_path_to_cell(target: Vector2i) -> Array[Vector2i]:
	var player_cell: Vector2i = scene_ref.get("player_cell")
	if target == player_cell:
		return [player_cell]
	var queue: Array[Vector2i] = [player_cell]
	var came_from := {player_cell: player_cell}
	var found := false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == target:
			found = true
			break
		for dir in DIRS:
			var candidate: Vector2i = current + dir
			if came_from.has(candidate):
				continue
			if candidate != target and cell_hard_blocked(candidate):
				continue
			came_from[candidate] = current
			queue.append(candidate)
	if not found:
		return [player_cell]
	var reversed_path: Array[Vector2i] = [target]
	var step: Vector2i = target
	while step != player_cell:
		step = came_from.get(step, player_cell)
		reversed_path.append(step)
	reversed_path.reverse()
	return reversed_path

func cell_hard_blocked(cell: Vector2i) -> bool:
	var map_data: Dictionary = scene_ref.get("map_data")
	var cells: Array = map_data.get("cells", [])
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := String(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	if row[cell.x] == "#":
		return true
	for placement in map_data.get("placements", []):
		var placement_type := String(placement.get("type", ""))
		if placement_type == "field_monster":
			continue
		if placement_runtime_cell(placement) != cell:
			continue
		if placement_type == "locked_door" and bool(placement.get("blocking", false)):
			var slot_data: Dictionary = SaveService.load_slot(int(scene_ref.get("current_slot")))
			var runtime: Dictionary = slot_data.get("runtime", {})
			var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
			if not bool(unlocked_doors.get(String(placement.get("id", "")), false)):
				return true
		if placement_type == "secret_door":
			var slot_data: Dictionary = SaveService.load_slot(int(scene_ref.get("current_slot")))
			var runtime: Dictionary = slot_data.get("runtime", {})
			var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
			if not bool(discovered_secrets.get(String(placement.get("id", "")), false)):
				return true
	return false

func cell_blocks_vision(cell: Vector2i) -> bool:
	var map_data: Dictionary = scene_ref.get("map_data")
	var cells: Array = map_data.get("cells", [])
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := String(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	if row[cell.x] == "#":
		return true
	var slot_data: Dictionary = SaveService.load_slot(int(scene_ref.get("current_slot")))
	var runtime: Dictionary = slot_data.get("runtime", {})
	var unlocked_doors: Dictionary = runtime.get("unlockedDoors", {})
	var discovered_secrets: Dictionary = runtime.get("discoveredSecrets", {})
	for placement in map_data.get("placements", []):
		var placement_type := String(placement.get("type", ""))
		if placement_type not in ["locked_door", "secret_door"]:
			continue
		var pos := placement_runtime_cell(placement, runtime)
		if pos != cell:
			continue
		if placement_type == "locked_door" and bool(placement.get("blocking", false)):
			if not bool(unlocked_doors.get(String(placement.get("id", "")), false)):
				return true
		elif placement_type == "secret_door":
			if not bool(discovered_secrets.get(String(placement.get("id", "")), false)):
				return true
	return false

func placement_runtime_cell(placement: Dictionary, runtime: Dictionary = {}) -> Vector2i:
	if runtime.is_empty():
		runtime = SaveService.load_slot(int(scene_ref.get("current_slot"))).get("runtime", {})
	if String(placement.get("type", "")) == "field_monster":
		var state: Dictionary = runtime.get("fieldMonsters", {}).get(String(placement.get("id", "")), {})
		return scene_ref.call("_state_cell", state, "currentCell", placement)
	var pos: Array = placement.get("position", [0, 0])
	return Vector2i(int(pos[0]), int(pos[1]))

func cell_visit_key(cell: Vector2i) -> String:
	var map_data: Dictionary = scene_ref.get("map_data")
	return "%s:%d,%d" % [String(map_data.get("id", scene_ref.get("default_map_id"))), cell.x, cell.y]

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

func ensure_runtime() -> void:
	var slot_data: Dictionary = SaveService.load_slot(int(scene_ref.get("current_slot")))
	if slot_data.is_empty():
		return
	var runtime: Dictionary = slot_data.get("runtime", {})
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	var changed := false
	for placement in _placements():
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		var pos: Array = placement.get("position", [0, 0])
		var start_cell := [int(pos[0]), int(pos[1])]
		var state: Dictionary = field_monsters.get(placement_id, {})
		if not state.has("startCell"):
			state["startCell"] = start_cell
			changed = true
		if not state.has("currentCell"):
			state["currentCell"] = start_cell
			changed = true
		if String(state.get("aiState", "")).strip_edges() == "":
			var behavior := ai_behavior(placement)
			if behavior == "patrol":
				state["aiState"] = "patrolling"
			elif behavior == "ambush":
				state["aiState"] = "ambushing"
			else:
				state["aiState"] = "idle"
			changed = true
		if String(state.get("monsterId", "")).strip_edges() == "":
			state["monsterId"] = String(placement.get("monsterId", placement_id))
			changed = true
		if not state.has("patrolIndex"):
			state["patrolIndex"] = 0
			changed = true
		if not state.has("warningCounter"):
			state["warningCounter"] = 0
			changed = true
		if not state.has("lostSightCounter"):
			state["lostSightCounter"] = 0
			changed = true
		if not state.has("lastKnownPlayerCell"):
			state["lastKnownPlayerCell"] = start_cell
			changed = true
		if not state.has("revealed"):
			state["revealed"] = ai_behavior(placement) != "ambush"
			changed = true
		field_monsters[placement_id] = state
	runtime["fieldMonsters"] = field_monsters
	slot_data["runtime"] = runtime
	if changed:
		SaveService.save_slot(int(scene_ref.get("current_slot")), slot_data)

func tick() -> Dictionary:
	var current_slot := int(scene_ref.get("current_slot"))
	var slot_data: Dictionary = SaveService.load_slot(current_slot)
	if slot_data.is_empty():
		return {}
	var runtime: Dictionary = slot_data.get("runtime", {})
	var field_monsters: Dictionary = runtime.get("fieldMonsters", {})
	var occupied := {}
	var pending_combat: Dictionary = {}
	for placement in _placements():
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		var state: Dictionary = field_monsters.get(placement_id, {})
		if bool(state.get("defeated", false)):
			continue
		var current := state_cell(state, "currentCell", placement)
		occupied["%d,%d" % [current.x, current.y]] = placement_id
	for placement in _placements():
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		var state: Dictionary = field_monsters.get(placement_id, {})
		if bool(state.get("defeated", false)):
			continue
		var current := state_cell(state, "currentCell", placement)
		var start := state_cell(state, "startCell", placement)
		var player_cell: Vector2i = scene_ref.get("player_cell")
		var field_ai := ai_config(placement)
		var chase_range := maxi(int(field_ai.get("chaseRange", 2)), 0)
		var approach_range := maxi(int(field_ai.get("approachRange", 4)), chase_range)
		var hearing_range := maxi(int(field_ai.get("hearingRange", 1)), 0)
		var leash_range := maxi(int(field_ai.get("leashRange", 5)), approach_range)
		var distance: int = abs(current.x - player_cell.x) + abs(current.y - player_cell.y)
		var leash_distance: int = abs(start.x - player_cell.x) + abs(start.y - player_cell.y)
		var next_state := String(state.get("aiState", "idle"))
		var previous_state := next_state
		var behavior := ai_behavior(placement)
		var revealed := bool(state.get("revealed", behavior != "ambush"))
		var warning_turns := int(field_ai.get("warningTurns", 0))
		var wake_range := maxi(int(field_ai.get("wakeRange", 0)), 0)
		var lose_sight_turns := maxi(int(field_ai.get("loseSightTurns", 1)), 0)
		var warning_counter := int(state.get("warningCounter", 0))
		var lost_sight_counter := maxi(int(state.get("lostSightCounter", 0)), 0)
		var route := patrol_route(placement)
		var last_known := state_cell(state, "lastKnownPlayerCell", placement)
		var player_visible := has_cardinal_line_of_sight(current, player_cell)
		var player_heard := distance <= hearing_range
		var player_detected := leash_distance <= leash_range and ((player_visible and distance <= approach_range) or player_heard)
		if warning_counter < 0:
			warning_counter = 0
		if player_detected:
			last_known = player_cell
			lost_sight_counter = 0
		if behavior == "ambush" and not revealed:
			if (player_visible or player_heard) and distance <= chase_range:
				revealed = true
				next_state = "chasing"
				warning_counter = 0
			elif leash_distance <= leash_range and ((player_visible and distance <= wake_range) or player_heard):
				revealed = true
				if warning_turns > 0:
					next_state = "warning"
					warning_counter = warning_turns
				else:
					next_state = "approaching"
					warning_counter = 0
			else:
				next_state = "ambushing"
				warning_counter = 0
		elif player_detected and distance <= chase_range:
			next_state = "chasing"
			warning_counter = 0
		elif player_detected:
			if warning_turns > 0 and next_state not in ["warning", "approaching", "chasing"]:
				next_state = "warning"
				warning_counter = warning_turns
			elif next_state == "warning" and warning_counter > 1:
				next_state = "warning"
				warning_counter -= 1
			else:
				next_state = "approaching"
				warning_counter = 0
		elif next_state in ["warning", "approaching", "chasing", "giving_up"]:
			if current != last_known and lost_sight_counter <= lose_sight_turns:
				next_state = "giving_up"
				lost_sight_counter += 1
				warning_counter = 0
			elif current != start:
				next_state = "returning"
				warning_counter = 0
			elif behavior == "patrol" and route.size() > 1:
				next_state = "patrolling"
				lost_sight_counter = 0
			elif behavior == "ambush":
				next_state = "ambushing"
				revealed = false
				lost_sight_counter = 0
			else:
				next_state = "idle"
				lost_sight_counter = 0
		elif current != start:
			next_state = "returning"
			warning_counter = 0
		elif behavior == "patrol" and route.size() > 1:
			next_state = "patrolling"
			warning_counter = 0
		else:
			next_state = "idle"
			warning_counter = 0
		var goal := start
		if next_state in ["approaching", "chasing"]:
			goal = player_cell
		elif next_state == "giving_up":
			goal = last_known
		elif next_state == "patrolling":
			goal = patrol_target(state, placement)
		var moved := current
		if next_state not in ["idle", "warning", "ambushing"]:
			moved = step_monster_toward(current, goal, occupied, placement_id)
		if next_state == "giving_up" and moved == goal:
			next_state = "returning" if moved != start else ("ambushing" if behavior == "ambush" else ("patrolling" if behavior == "patrol" and route.size() > 1 else "idle"))
			if next_state == "ambushing":
				revealed = false
			lost_sight_counter = 0
		if next_state == "returning" and moved == start:
			if behavior == "patrol" and route.size() > 1:
				next_state = "patrolling"
			elif behavior == "ambush":
				next_state = "ambushing"
				revealed = false
			else:
				next_state = "idle"
			lost_sight_counter = 0
		if next_state == "patrolling":
			var patrol_index := int(state.get("patrolIndex", 0))
			if moved == goal and route.size() > 1:
				patrol_index = posmod(patrol_index + 1, route.size())
			state["patrolIndex"] = patrol_index
		occupied.erase("%d,%d" % [current.x, current.y])
		occupied["%d,%d" % [moved.x, moved.y]] = placement_id
		state["currentCell"] = [moved.x, moved.y]
		state["aiState"] = next_state
		state["warningCounter"] = warning_counter
		state["lostSightCounter"] = lost_sight_counter
		state["lastKnownPlayerCell"] = [last_known.x, last_known.y]
		state["revealed"] = revealed
		state["updatedAt"] = Time.get_datetime_string_from_system()
		field_monsters[placement_id] = state
		if next_state in ["warning", "approaching", "chasing"] and previous_state not in ["warning", "approaching", "chasing"]:
			broadcast_alert(placement, field_monsters)
		if pending_combat.is_empty() and revealed and next_state in ["approaching", "chasing"] and should_auto_engage(moved, placement):
			pending_combat = placement
	runtime["fieldMonsters"] = field_monsters
	slot_data["runtime"] = runtime
	SaveService.save_slot(current_slot, slot_data)
	scene_ref.call("_refresh_field_monsters")
	return pending_combat

func ai_config(placement: Dictionary) -> Dictionary:
	var field_ai: Dictionary = placement.get("fieldAi", {})
	var patrol_points: Array = []
	for point_variant in field_ai.get("patrolPoints", []):
		if typeof(point_variant) != TYPE_ARRAY:
			continue
		var point: Array = point_variant
		if point.size() != 2:
			continue
		patrol_points.append([int(point[0]), int(point[1])])
	return {
		"behavior": ai_behavior(placement),
		"approachRange": maxi(int(field_ai.get("approachRange", 4)), 0),
		"chaseRange": maxi(int(field_ai.get("chaseRange", 2)), 0),
		"hearingRange": maxi(int(field_ai.get("hearingRange", 1)), 0),
		"leashRange": maxi(int(field_ai.get("leashRange", 5)), 0),
		"wakeRange": maxi(int(field_ai.get("wakeRange", 0)), 0),
		"loseSightTurns": maxi(int(field_ai.get("loseSightTurns", 1)), 0),
		"alertGroup": String(field_ai.get("alertGroup", "")),
		"alertRadius": maxi(int(field_ai.get("alertRadius", 0)), 0),
		"warningTurns": maxi(int(field_ai.get("warningTurns", 0)), 0),
		"patrolPoints": patrol_points
	}

func ai_behavior(placement: Dictionary) -> String:
	var field_ai: Dictionary = placement.get("fieldAi", {})
	var behavior := String(field_ai.get("behavior", "guard"))
	return behavior if behavior in ["guard", "patrol", "ambush"] else "guard"

func alert_group_id(placement: Dictionary) -> String:
	var config := ai_config(placement)
	var explicit_group := String(config.get("alertGroup", ""))
	if explicit_group != "":
		return explicit_group
	return String(placement.get("encounterId", ""))

func patrol_route(placement: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var base_cell := state_cell({}, "currentCell", placement)
	result.append(base_cell)
	for point in ai_config(placement).get("patrolPoints", []):
		if typeof(point) != TYPE_ARRAY:
			continue
		var point_array: Array = point
		if point_array.size() != 2:
			continue
		var patrol_cell := Vector2i(int(point_array[0]), int(point_array[1]))
		if patrol_cell not in result:
			result.append(patrol_cell)
	return result

func patrol_target(state: Dictionary, placement: Dictionary) -> Vector2i:
	var route := patrol_route(placement)
	if route.is_empty():
		return state_cell(state, "startCell", placement)
	var index := clampi(int(state.get("patrolIndex", 0)), 0, route.size() - 1)
	return route[index]

func step_monster_toward(current: Vector2i, goal: Vector2i, occupied: Dictionary, placement_id: String) -> Vector2i:
	var routed_step := monster_path_next_step(current, goal, occupied, placement_id)
	if routed_step != current:
		return routed_step
	var candidates: Array[Vector2i] = []
	var delta := goal - current
	if abs(delta.x) >= abs(delta.y):
		candidates.append(current + Vector2i(sign(delta.x), 0))
		candidates.append(current + Vector2i(0, sign(delta.y)))
	else:
		candidates.append(current + Vector2i(0, sign(delta.y)))
		candidates.append(current + Vector2i(sign(delta.x), 0))
	var player_cell: Vector2i = scene_ref.get("player_cell")
	for candidate in candidates:
		if candidate == current:
			continue
		if candidate == player_cell:
			continue
		if bool(scene_ref.call("_cell_hard_blocked", candidate)):
			continue
		var key := "%d,%d" % [candidate.x, candidate.y]
		if occupied.has(key) and String(occupied.get(key, "")) != placement_id:
			continue
		return candidate
	return current

func monster_path_next_step(current: Vector2i, goal: Vector2i, occupied: Dictionary, placement_id: String) -> Vector2i:
	if current == goal:
		return current
	var player_cell: Vector2i = scene_ref.get("player_cell")
	var queue: Array[Vector2i] = [current]
	var came_from := {"%d,%d" % [current.x, current.y]: current}
	var found := false
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			found = true
			break
		for dir in DIRS:
			var candidate: Vector2i = cell + dir
			var key := "%d,%d" % [candidate.x, candidate.y]
			if came_from.has(key):
				continue
			if candidate != goal and candidate == player_cell:
				continue
			if bool(scene_ref.call("_cell_hard_blocked", candidate)):
				continue
			if occupied.has(key) and String(occupied.get(key, "")) != placement_id:
				continue
			came_from[key] = cell
			queue.append(candidate)
	if not found:
		return current
	var step := goal
	while came_from.has("%d,%d" % [step.x, step.y]):
		var previous: Vector2i = came_from["%d,%d" % [step.x, step.y]]
		if previous == current:
			return step
		if previous == step:
			break
		step = previous
	return current

func has_cardinal_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if from.x != to.x and from.y != to.y:
		return false
	if from == to:
		return true
	if from.x == to.x:
		var step_y := 1 if to.y > from.y else -1
		for y in range(from.y + step_y, to.y, step_y):
			if bool(scene_ref.call("_cell_blocks_vision", Vector2i(from.x, y))):
				return false
		return true
	var step_x := 1 if to.x > from.x else -1
	for x in range(from.x + step_x, to.x, step_x):
		if bool(scene_ref.call("_cell_blocks_vision", Vector2i(x, from.y))):
			return false
	return true

func broadcast_alert(source_placement: Dictionary, field_monsters: Dictionary) -> void:
	var group_id := alert_group_id(source_placement)
	if group_id == "":
		return
	var runtime := {"fieldMonsters": field_monsters}
	var source_cell: Vector2i = scene_ref.call("_placement_runtime_cell", source_placement, runtime)
	var source_radius := int(ai_config(source_placement).get("alertRadius", 0))
	var player_cell: Vector2i = scene_ref.get("player_cell")
	for placement in _placements():
		if String(placement.get("type", "")) != "field_monster":
			continue
		var placement_id := String(placement.get("id", ""))
		if placement_id == String(source_placement.get("id", "")):
			continue
		if alert_group_id(placement) != group_id:
			continue
		var state: Dictionary = field_monsters.get(placement_id, {}).duplicate(true)
		if state.is_empty() or bool(state.get("defeated", false)):
			continue
		var ally_cell := state_cell(state, "currentCell", placement)
		var ally_radius := int(ai_config(placement).get("alertRadius", 0))
		var effective_radius := maxi(source_radius, ally_radius)
		if effective_radius > 0 and abs(source_cell.x - ally_cell.x) + abs(source_cell.y - ally_cell.y) > effective_radius:
			continue
		var ai_state := String(state.get("aiState", "idle"))
		if ai_state in ["warning", "approaching", "chasing", "combat"]:
			continue
		var behavior := ai_behavior(placement)
		if behavior == "ambush":
			state["revealed"] = true
		var ally_config := ai_config(placement)
		var warning_turns := int(ally_config.get("warningTurns", 0))
		state["aiState"] = "warning" if warning_turns > 0 else "approaching"
		state["warningCounter"] = warning_turns
		state["lostSightCounter"] = 0
		state["lastKnownPlayerCell"] = [player_cell.x, player_cell.y]
		state["updatedAt"] = Time.get_datetime_string_from_system()
		field_monsters[placement_id] = state

func should_auto_engage(monster_cell: Vector2i, placement: Dictionary) -> bool:
	if not bool(placement.get("blocking", false)):
		return false
	var player_cell: Vector2i = scene_ref.get("player_cell")
	return abs(monster_cell.x - player_cell.x) + abs(monster_cell.y - player_cell.y) <= 1

func marker_color(state: Dictionary) -> Color:
	match String(state.get("aiState", "idle")):
		"ambushing":
			return Color("6f5a8e")
		"warning":
			return Color("d8a84e")
		"approaching":
			return Color("d47f4a")
		"chasing":
			return Color("d04f4f")
		"returning":
			return Color("8f79c9")
		"giving_up":
			return Color("8d6767")
		"patrolling":
			return Color("c25ac2")
		_:
			return Color("d04f4f")

func state_cell(state: Dictionary, key: String, placement: Dictionary) -> Vector2i:
	var fallback: Array = placement.get("position", [0, 0])
	var raw: Array = state.get(key, fallback)
	return Vector2i(int(raw[0]), int(raw[1]))

func _placements() -> Array:
	var map_data: Dictionary = scene_ref.get("map_data")
	return map_data.get("placements", [])

extends RefCounted

var scene_ref: Node

func configure(target_scene: Node) -> RefCounted:
	scene_ref = target_scene
	return self

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

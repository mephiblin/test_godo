extends RefCounted

const EDITOR_WORKSPACE_SCENE := preload("res://scenes/editor_tools/EditorWorkspace.tscn")

func snapshot(map_id: String, route_entry: String, file_name: String, options: Dictionary = {}, capture_callback: Callable = Callable()) -> Dictionary:
	var packed: PackedScene = EDITOR_WORKSPACE_SCENE
	if packed == null:
		return {"ok": false, "message": "Missing EditorWorkspace scene."}
	var scene_router := _scene_router()
	if scene_router == null or scene_router.get("scene_host") == null:
		return {"ok": false, "message": "Missing SceneRouter host."}
	var workspace: Control = packed.instantiate()
	scene_router.get("scene_host").add_child(workspace)
	await _next_frame()
	if workspace.has_method("smoke_set_selected_map"):
		workspace.call("smoke_set_selected_map", map_id)
	await _next_frame()
	var selected_ok := false
	if workspace.has_method("smoke_set_route_preview_entry"):
		selected_ok = bool(workspace.call("smoke_set_route_preview_entry", route_entry))
	await _next_frame()
	if file_name != "" and capture_callback.is_valid():
		await capture_callback.call(file_name)
	var result := {
		"ok": selected_ok,
		"mapId": map_id,
		"routeEntry": route_entry,
		"summary": "",
		"detail": "",
		"variants": {}
	}
	if workspace.has_method("smoke_get_summary_text"):
		result["summary"] = String(workspace.call("smoke_get_summary_text"))
	if workspace.has_method("smoke_get_route_preview_detail_text"):
		result["detail"] = String(workspace.call("smoke_get_route_preview_detail_text"))
	var variants := await _collect_variants(workspace, options)
	if not variants.is_empty():
		result["variants"] = variants
		for variant in variants.values():
			if typeof(variant) == TYPE_DICTIONARY:
				result["ok"] = bool(result["ok"]) and bool((variant as Dictionary).get("ok", false))
	workspace.queue_free()
	await _next_frame()
	return result

func variant_contains(snapshot: Dictionary, variant_key: String, expected_text: String) -> bool:
	var variants: Dictionary = snapshot.get("variants", {})
	if expected_text == "":
		return bool((variants.get(variant_key, {}) as Dictionary).get("ok", false))
	var variant: Dictionary = variants.get(variant_key, {})
	return bool(variant.get("ok", false)) and String(variant.get("detail", "")).contains(expected_text)

func _collect_variants(workspace: Control, options: Dictionary) -> Dictionary:
	var variants: Dictionary = {}
	var event_choice_indices: Array = options.get("eventChoiceIndices", [])
	for index_variant in event_choice_indices:
		var index := int(index_variant)
		var variant_key := "eventChoice:%d" % index
		var switch_ok := false
		if workspace.has_method("smoke_set_route_target_event_choice_index"):
			switch_ok = bool(workspace.call("smoke_set_route_target_event_choice_index", index))
		await _next_frame()
		variants[variant_key] = {
			"ok": switch_ok,
			"detail": String(workspace.call("smoke_get_route_preview_detail_text")) if workspace.has_method("smoke_get_route_preview_detail_text") else ""
		}
	var event_step_ids: Array = options.get("eventStepIds", [])
	for step_variant in event_step_ids:
		var step_id := String(step_variant)
		var variant_key := "eventStep:%s" % step_id
		var switch_ok := false
		if workspace.has_method("smoke_set_route_target_event_step_id"):
			switch_ok = bool(workspace.call("smoke_set_route_target_event_step_id", step_id))
		await _next_frame()
		variants[variant_key] = {
			"ok": switch_ok,
			"detail": String(workspace.call("smoke_get_route_preview_detail_text")) if workspace.has_method("smoke_get_route_preview_detail_text") else ""
		}
	var npc_service_indices: Array = options.get("npcServiceIndices", [])
	for index_variant in npc_service_indices:
		var index := int(index_variant)
		var variant_key := "npcService:%d" % index
		var switch_ok := false
		if workspace.has_method("smoke_set_route_target_service_index"):
			switch_ok = bool(workspace.call("smoke_set_route_target_service_index", index))
		await _next_frame()
		variants[variant_key] = {
			"ok": switch_ok,
			"detail": String(workspace.call("smoke_get_route_preview_detail_text")) if workspace.has_method("smoke_get_route_preview_detail_text") else ""
		}
	return variants

func _scene_router() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("SceneRouter")

func _next_frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame

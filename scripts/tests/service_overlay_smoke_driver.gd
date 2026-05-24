extends RefCounted

func select_service_type(overlay: Node, service_type: String) -> void:
	if overlay == null:
		return
	if not bool(overlay.call("_show_npc_service_menu")):
		return
	var placement: Dictionary = overlay.get("placement")
	var npc_service := _npc_service()
	if npc_service == null:
		return
	for service_state in npc_service.call("describe_services_for_slot", int(overlay.get("slot")), String(placement.get("npcId", ""))):
		var service: Dictionary = service_state.get("service", {})
		if String(service.get("type", "")) != service_type:
			continue
		if not bool(service_state.get("available", false)):
			return
		overlay.call("_select_service", service)
		return

func _npc_service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("NpcService")

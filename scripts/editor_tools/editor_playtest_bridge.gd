extends Node

var payload: Dictionary = {}

func set_payload(next_payload: Dictionary) -> void:
	payload = next_payload.duplicate(true)

func consume_payload(expected_route: String = "") -> Dictionary:
	if payload.is_empty():
		return {}
	var next_payload := payload.duplicate(true)
	var route := String(next_payload.get("route", ""))
	if expected_route != "" and route != "" and route != expected_route:
		return {}
	payload.clear()
	return next_payload

func clear_payload() -> void:
	payload.clear()

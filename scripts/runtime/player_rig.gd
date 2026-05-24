extends Node3D

@onready var camera: Camera3D = $Camera3D

func apply_cell(cell: Vector2i, facing: int, view_profile: Dictionary = {}) -> void:
	position = Vector3(cell.x, 1.3, cell.y)
	rotation = Vector3.ZERO
	rotation.y = deg_to_rad(float(facing) * 90.0)
	camera.position = view_profile.get("cameraPosition", Vector3(0, 0.9, 0))
	camera.rotation_degrees = view_profile.get("cameraRotationDegrees", Vector3(-18, 180, 0))

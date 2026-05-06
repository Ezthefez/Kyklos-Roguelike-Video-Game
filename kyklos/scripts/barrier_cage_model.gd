extends Node3D

@export var spin_speed_x_deg: float = 8.0
@export var spin_speed_y_deg: float = 11.0
@export var spin_dir_x: float = 1.0
@export var spin_dir_y: float = 1.0

func _process(delta: float) -> void:
	rotation.x += deg_to_rad(spin_speed_x_deg * spin_dir_x) * delta
	rotation.y += deg_to_rad(spin_speed_y_deg * spin_dir_y) * delta

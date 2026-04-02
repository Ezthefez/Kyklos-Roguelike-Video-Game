#cluster.gd script

extends Node3D

@export var rotation_speed_degrees_per_sec: float = 15.0

var remaining_targets: int = 0

func _ready() -> void:
	# Count target spheres (they should be in the "targets" group).
	remaining_targets = get_tree().get_nodes_in_group("targets").size()

func _process(delta: float) -> void:
	# Rotate the whole cluster continuously.
	rotate_y(deg_to_rad(rotation_speed_degrees_per_sec) * delta)

func notify_target_destroyed() -> void:
	remaining_targets -= 1
	if remaining_targets <= 0:
		# All spheres were destroyed. Remove the entire cluster root.
		queue_free()

extends Node3D

@export var rotation_speed_degrees_per_sec: float = 15.0
@export var target_radius: float = 0.5
@export var projectile_radius: float = 0.25
@export var extra_hit_margin: float = 0.05

# 1.0 = perfectly elastic, lower = less bouncy
@export var restitution: float = 0.9

# Optional center gravity after release
@export var gravity_enabled: bool = false
@export var gravity_strength: float = 12.0
@export var gravity_damping: float = 0.995
@export var min_distance: float = 0.75
@export var max_force: float = 20.0

var tracked_targets: Array[RigidBody3D] = []
var released_targets: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is RigidBody3D:
			var body := child as RigidBody3D
			tracked_targets.append(body)
			released_targets[body] = false

			# IMPORTANT:
			# Untouched targets must stay frozen so manual rotation does not fight physics.
			body.freeze = true
			body.sleeping = true

func _process(delta: float) -> void:
	var angle := deg_to_rad(rotation_speed_degrees_per_sec) * delta

	for body in tracked_targets:
		if body == null:
			continue
		if released_targets.get(body, false):
			continue

		var offset: Vector3 = body.global_position - global_position
		offset = offset.rotated(Vector3.UP, angle)
		body.global_position = global_position + offset
		body.rotate_y(angle)

func _physics_process(delta: float) -> void:
	# Projectile vs still-frozen targets
	for node in get_tree().get_nodes_in_group("projectiles"):
		if node is RigidBody3D:
			var projectile := node as RigidBody3D

			for target in tracked_targets:
				if target == null:
					continue
				if released_targets.get(target, false):
					continue

				var d := projectile.global_position.distance_to(target.global_position)
				if d <= (projectile_radius + target_radius + extra_hit_margin):
					release_single_target(projectile, target, projectile_radius + target_radius)
					return

	# Released targets vs still-frozen targets
	for source in tracked_targets:
		if source == null:
			continue
		if not released_targets.get(source, false):
			continue

		for target in tracked_targets:
			if target == null or target == source:
				continue
			if released_targets.get(target, false):
				continue

			var d2 := source.global_position.distance_to(target.global_position)
			if d2 <= (target_radius * 2.0 + extra_hit_margin):
				release_single_target(source, target, target_radius * 2.0)
				return

	# Optional gravity, only for already released targets
	if gravity_enabled:
		for body in tracked_targets:
			if body == null:
				continue
			if not released_targets.get(body, false):
				continue

			apply_center_gravity(body, delta)

func release_single_target(other_body: RigidBody3D, hit_target: RigidBody3D, desired_distance: float) -> void:
	if hit_target == null or other_body == null:
		return
	if released_targets.get(hit_target, false):
		return

	released_targets[hit_target] = true
	hit_target.freeze = false
	hit_target.sleeping = false

	var normal := hit_target.global_position - other_body.global_position
	if normal.length_squared() < 0.000001:
		normal = Vector3.RIGHT
	normal = normal.normalized()

	var current_distance := hit_target.global_position.distance_to(other_body.global_position)
	var penetration := desired_distance - current_distance
	if penetration > 0.0:
		hit_target.global_position += normal * (penetration + 0.01)

	var angular_speed := deg_to_rad(rotation_speed_degrees_per_sec)
	var radial := hit_target.global_position - global_position
	var tangential := Vector3.UP.cross(radial) * angular_speed
	hit_target.linear_velocity = tangential

	var v1 := other_body.linear_velocity
	var v2 := hit_target.linear_velocity
	var m1 := other_body.mass
	var m2 := hit_target.mass
	var e := restitution

	var v1n := normal * v1.dot(normal)
	var v2n := normal * v2.dot(normal)
	var v1t := v1 - v1n
	var v2t := v2 - v2n

	var a1 := v1.dot(normal)
	var a2 := v2.dot(normal)

	if a1 - a2 <= 0.0:
		hit_target.linear_velocity += normal * max(0.5, other_body.linear_velocity.length() * 0.35)
		return

	var new_a1 := (a1 * (m1 - e * m2) + a2 * (1.0 + e) * m2) / (m1 + m2)
	var new_a2 := (a2 * (m2 - e * m1) + a1 * (1.0 + e) * m1) / (m1 + m2)

	other_body.linear_velocity = v1t + normal * new_a1
	hit_target.linear_velocity = v2t + normal * new_a2

func apply_center_gravity(body: RigidBody3D, delta: float) -> void:
	var dir: Vector3 = global_position - body.global_position
	var dist: float = max(dir.length(), min_distance)

	var force: Vector3 = dir.normalized() * (gravity_strength / dist)

	if force.length() > max_force:
		force = force.normalized() * max_force

	# IMPORTANT: scale by delta so it does not explode
	body.linear_velocity += force * delta
	body.linear_velocity *= gravity_damping

	if body.linear_velocity.length() < 0.05:
		body.linear_velocity = Vector3.ZERO

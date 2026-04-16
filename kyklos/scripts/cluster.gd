extends Node3D

@export var rotation_speed_degrees_per_sec: float = 15.0
@export var target_radius: float = 0.5
@export var projectile_radius: float = 0.25
@export var extra_hit_margin: float = 0.05
@export var gravity_strength: float = 5.0
@export var damping: float = 0.97
@export var min_distance: float = 0.5
@export var max_force: float = 100.0

# 1.0 = perfectly elastic, lower = less bouncy
@export var restitution: float = 0.2

var tracked_targets: Array[RigidBody3D] = []
var released_targets: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is RigidBody3D:
			var body := child as RigidBody3D
			tracked_targets.append(body)
			released_targets[body] = false
			body.freeze = false
			body.sleeping = false
			body.linear_velocity = Vector3(
				randf_range(-0.5, 0.5),
				randf_range(-0.5, 0.5),
				randf_range(-0.5, 0.5)
		)

func _physics_process(_delta: float) -> void:
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
	
	# Apply gravity
		for body in tracked_targets:
			if body == null:
				continue
			
			apply_center_gravity(body)

func release_single_target(other_body: RigidBody3D, hit_target: RigidBody3D, desired_distance: float) -> void:
	if hit_target == null or other_body == null:
		return
	if released_targets.get(hit_target, false):
		return

	# Stop controlling this target manually from now on.
	released_targets[hit_target] = true
	hit_target.freeze = false
	hit_target.sleeping = false

	# Compute collision normal from hitter -> target
	var normal := hit_target.global_position - other_body.global_position
	if normal.length_squared() < 0.000001:
		normal = Vector3.RIGHT
	normal = normal.normalized()

	# Push the target just outside overlap so it doesn't keep intersecting.
	var current_distance := hit_target.global_position.distance_to(other_body.global_position)
	var penetration := desired_distance - current_distance
	if penetration > 0.0:
		hit_target.global_position += normal * (penetration + 0.01)

	# Keep the released target's orbital tangential motion from the spinning cluster.
	var angular_speed := deg_to_rad(rotation_speed_degrees_per_sec)
	var radial := hit_target.global_position - global_position
	var tangential := Vector3.UP.cross(radial) * angular_speed
	hit_target.linear_velocity = tangential

	# Solve 1D collision along the contact normal.
	# Tangential components stay as they are; only normal components change.
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

	# If they are not moving toward each other along the normal, still nudge the target,
	# but don't overwrite the projectile with a bad bounce.
	if a1 - a2 <= 0.0:
		hit_target.linear_velocity += normal * max(0.5, other_body.linear_velocity.length() * 0.35)
		return

	# Elastic / semi-elastic collision equations
	var new_a1 := (a1 * (m1 - e * m2) + a2 * (1.0 + e) * m2) / (m1 + m2)
	var new_a2 := (a2 * (m2 - e * m1) + a1 * (1.0 + e) * m1) / (m1 + m2)

	other_body.linear_velocity = v1t + normal * new_a1
	hit_target.linear_velocity = v2t + normal * new_a2

func apply_center_gravity(body: RigidBody3D) -> void:
	var dir = global_position - body.global_position
	var dist = max(dir.length(), min_distance)
	var normal = dir.normalized()

	# Strong pull when far, weaker when close
	var falloff = clamp(dist / 3.0, 0.2, 1.0)

	var force = normal * gravity_strength * falloff

	#allow escape if moving outward fast
	var outward_speed = body.linear_velocity.dot(-normal)
	#if outward_speed > 0.5:
	#	return

	# Clamp force
	if force.length() > max_force:
		force = force.normalized() * max_force

	body.linear_velocity += force

	# Damping
	body.linear_velocity *= damping

	if body.linear_velocity.length() < 0.05:
		body.linear_velocity = Vector3.ZERO
	
	var max_speed = 5.0
	if body.linear_velocity.length() > max_speed:
		body.linear_velocity = body.linear_velocity.normalized() * max_speed

func apply_mutual_gravity() -> void:
	for i in range(tracked_targets.size()):
		var a = tracked_targets[i]
		if a == null:
			continue

		for j in range(i + 1, tracked_targets.size()):
			var b = tracked_targets[j]
			if b == null:
				continue

			var dir = b.global_position - a.global_position
			var dist = max(dir.length(), min_distance)
			var normal = dir.normalized()
			
			var relative_velocity = a.linear_velocity - b.linear_velocity

			# If moving apart fast enough, weaken gravity
			if relative_velocity.dot(normal) > 0.5:
				continue

			#---Gravity---
			var softened_dist = sqrt(dist * dist + 1.0) # tweak 1.0
			var close_falloff = clamp(dist / 2.0, 0.2, 1.0)
			var force_mag = (gravity_strength * a.mass * b.mass) / (softened_dist * softened_dist)
			force_mag *= close_falloff
			var force = normal * force_mag

			# Clamp force (prevents explosions)
			if force.length() > max_force:
				force = force.normalized() * max_force

			a.linear_velocity += force / a.mass
			b.linear_velocity -= force / b.mass
			
			if dist < 0.001:
				var avg_vel = (a.linear_velocity + b.linear_velocity) * 0.5
				a.linear_velocity = a.linear_velocity.lerp(avg_vel, 0.02)
				b.linear_velocity = b.linear_velocity.lerp(avg_vel, 0.02)
	
	for body in tracked_targets:
		if body == null:
			continue

		body.linear_velocity *= damping

		if body.linear_velocity.length() < 0.05:
			body.linear_velocity = Vector3.ZERO

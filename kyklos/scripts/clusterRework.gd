extends Node3D

@export var cluster_seed: int = 0

@export var target_radius: float = 0.5
@export var projectile_radius: float = 0.25
@export var extra_hit_margin: float = 0.05

@export var target_scene: PackedScene
@export var min_spawn_count: int = 10
@export var max_spawn_count: int = 25
@export var spawn_radius: float = 3.0

@export var gravity_strength: float = 1.5
@export var damping: float = 0.9
@export var min_distance: float = 0.5
@export var max_speed: float = 3.0

@export var restitution: float = 0.0

@export var barrier_cage_scene: PackedScene
@export var barrier_scale: Vector3 = Vector3(2.0, 2.0, 2.0)

var tracked_targets: Array[RigidBody3D] = []
var gravity_enabled := false
var escape_timers: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame

	if GameManager.selected_seed != 0:
		cluster_seed = GameManager.selected_seed
	elif cluster_seed == 0:
		cluster_seed = randi()

	seed(cluster_seed)

	spawn_targets()
	_spawn_barrier_if_needed()

	GameManager.targets_remaining = tracked_targets.size()

	await get_tree().create_timer(0.2).timeout
	gravity_enabled = true

func _spawn_barrier_if_needed() -> void:
	if not GameManager.barrier_enabled:
		return

	if barrier_cage_scene == null:
		push_error("clusterRework.gd: barrier_cage_scene is not assigned.")
		return

	var barrier := barrier_cage_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(barrier)
	barrier.global_position = global_position
	barrier.scale = barrier_scale

	var rng := RandomNumberGenerator.new()
	rng.seed = int(cluster_seed) + 85433

	barrier.set("spin_speed_x_deg", rng.randf_range(5.0, 12.0))
	barrier.set("spin_speed_y_deg", rng.randf_range(5.0, 12.0))
	barrier.set("spin_dir_x", -1.0 if rng.randf() < 0.5 else 1.0)
	barrier.set("spin_dir_y", -1.0 if rng.randf() < 0.5 else 1.0)

func _physics_process(_delta: float) -> void:
	if not gravity_enabled:
		return

	for node in get_tree().get_nodes_in_group("projectiles"):
		if node is RigidBody3D:
			var projectile := node as RigidBody3D

			for target in tracked_targets:
				if target == null:
					continue

				var d := projectile.global_position.distance_to(target.global_position)
				if d <= (projectile_radius + target_radius + extra_hit_margin):
					apply_hit(projectile, target)
					return

	for body in escape_timers.keys():
		if body == null:
			continue

		escape_timers[body] -= _delta
		if escape_timers[body] <= 0.0:
			escape_timers.erase(body)

	for body in tracked_targets:
		if body == null:
			continue
		if escape_timers.has(body):
			continue

		apply_center_gravity(body)

func apply_hit(projectile: RigidBody3D, target: RigidBody3D) -> void:
	var normal := (target.global_position - projectile.global_position).normalized()
	var hit_force := projectile.linear_velocity.length()

	target.linear_velocity += normal * max(1.0, hit_force * 0.5)
	escape_timers[target] = 0.5

func apply_center_gravity(body: RigidBody3D) -> void:
	var dir = global_position - body.global_position
	var dist = dir.length()

	if dist < 0.001:
		return

	var normal = dir.normalized()
	var softened_dist = sqrt(dist * dist + 2.0)
	var force = normal * gravity_strength * (dist / softened_dist)

	body.linear_velocity += force / body.mass

	var center_damping = lerp(0.85, damping, clamp(dist / 3.0, 0.0, 1.0))
	body.linear_velocity *= center_damping

	if body.linear_velocity.length() > max_speed:
		body.linear_velocity = body.linear_velocity.normalized() * max_speed

	if body.linear_velocity.length() < 0.05:
		body.linear_velocity = Vector3.ZERO

func spawn_targets() -> void:
	var count = randi_range(min_spawn_count, max_spawn_count)

	for i in range(count):
		var target := target_scene.instantiate() as RigidBody3D
		add_child(target)
		target.linear_velocity = Vector3.ZERO
		target.angular_velocity = Vector3.ZERO

		var attempts := 0
		var valid_position := false
		var pos: Vector3

		while not valid_position and attempts < 10:
			pos = Vector3(
				randf_range(-1, 1),
				randf_range(-1, 1),
				randf_range(-1, 1)
			).normalized() * randf_range(0.5, spawn_radius)

			valid_position = true

			for other in tracked_targets:
				if other.global_position.distance_to(global_position + pos) < (target_radius * 2.0):
					valid_position = false
					break

			attempts += 1

		target.global_position = global_position + pos
		tracked_targets.append(target)

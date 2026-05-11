extends Node3D

@export var cluster_seed: int = 0

@export var target_radius: float = 0.5
@export var projectile_radius: float = 0.25
@export var extra_hit_margin: float = 0.05

@export var target_scene: PackedScene
@export var min_spawn_count_base: int = 5
@export var max_spawn_count_base: int = 10
@export var spawn_radius: float = 3.0

@export var gravity_strength: float = 1.5
@export var damping: float = 0.9
@export var min_distance: float = 0.5
@export var max_speed: float = 3.0

@export var restitution: float = 0.0

@export var barrier_cage_scene: PackedScene
@export var barrier_scale: Vector3 = Vector3(2.0, 2.0, 2.0)

@export var ring_barrier_scene: PackedScene
@export var ring_barrier_scale: Vector3 = Vector3(2.0, 2.0, 2.0)

# Testing: 50% chance
@export var zero_g_cluster_chance: float = 0.50

# Orbital cluster settings
@export var zero_g_rotation_speed_degrees_per_sec: float = 18.0
@export var zero_g_release_speed_multiplier: float = 1.0
@export var zero_g_release_extra_push: float = 1.5
@export var zero_g_spin_multiplier: float = 0.08
@export var zero_g_collision_margin: float = 0.05

var tracked_targets: Array[RigidBody3D] = []
var gravity_enabled := false
var escape_timers: Dictionary = {}

var use_zero_g_cluster: bool = false
var zero_g_orbit_tilt_x_deg: float = 0.0
var zero_g_orbit_tilt_y_deg: float = 0.0
var zero_g_orbit_speed_multiplier: float = 1.0

var orbital_root: Node3D = null
var orbital_targets: Array[RigidBody3D] = []
var released_zero_g_targets: Array[RigidBody3D] = []

func _ready() -> void:
	await get_tree().process_frame

	if GameManager.selected_seed != 0:
		cluster_seed = GameManager.selected_seed
	elif cluster_seed == 0:
		cluster_seed = randi()

	seed(cluster_seed)

	_choose_cluster_variant()
	spawn_targets()
	_spawn_barrier_if_needed()
	_spawn_ring_barrier_if_needed()

	GameManager.targets_remaining = tracked_targets.size()

	await get_tree().create_timer(0.2).timeout
	gravity_enabled = true

func _choose_cluster_variant() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cluster_seed) + 190731
	use_zero_g_cluster = rng.randf() < zero_g_cluster_chance

	var tilt_rng := RandomNumberGenerator.new()
	tilt_rng.seed = int(cluster_seed) + 481923

	# Mix common cardinal-feeling directions with occasional diagonal/corner-feeling ones.
	var mode_roll: float = tilt_rng.randf()

	if mode_roll < 0.65:
		# More common: clean up/down/left/right style tilts.
		var cardinal_x_choices: Array[float] = [-75.0, -50.0, -30.0, 0.0, 30.0, 50.0, 75.0]
		var cardinal_y_choices: Array[float] = [0.0, 90.0, 180.0, 270.0]
		zero_g_orbit_tilt_x_deg = cardinal_x_choices[tilt_rng.randi_range(0, cardinal_x_choices.size() - 1)]
		zero_g_orbit_tilt_y_deg = cardinal_y_choices[tilt_rng.randi_range(0, cardinal_y_choices.size() - 1)]
	else:
		# Still sometimes diagonal/corner directions.
		zero_g_orbit_tilt_x_deg = tilt_rng.randf_range(-75.0, 75.0)
		zero_g_orbit_tilt_y_deg = tilt_rng.randf_range(0.0, 360.0)

	# 0.2% compounded per completed round.
	var wins: int = max(GameManager.player_level - 1, 0)
	zero_g_orbit_speed_multiplier = pow(1.002, float(wins))

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

	var spin_x: float = rng.randf_range(5.0, 12.0)
	var spin_y: float = rng.randf_range(5.0, 12.0)
	var dir_x: float = -1.0 if rng.randf() < 0.5 else 1.0
	var dir_y: float = -1.0 if rng.randf() < 0.5 else 1.0

	barrier.set("spin_speed_x_deg", spin_x)
	barrier.set("spin_speed_y_deg", spin_y)
	barrier.set("spin_dir_x", dir_x)
	barrier.set("spin_dir_y", dir_y)

func _spawn_ring_barrier_if_needed() -> void:
	if not GameManager.ring_barrier_enabled:
		return

	if ring_barrier_scene == null:
		push_error("clusterRework.gd: ring_barrier_scene is not assigned.")
		return

	var ring := ring_barrier_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	ring.scale = ring_barrier_scale

	var rng := RandomNumberGenerator.new()
	rng.seed = int(cluster_seed) + 85433

	var spin_x: float = rng.randf_range(5.0, 12.0)
	var spin_y: float = rng.randf_range(5.0, 12.0)
	var dir_x: float = -1.0 if rng.randf() < 0.5 else 1.0
	var dir_y: float = -1.0 if rng.randf() < 0.5 else 1.0

	ring.set("spin_speed_x_deg", spin_x)
	ring.set("spin_speed_y_deg", spin_y)
	ring.set("spin_dir_x", -dir_x)
	ring.set("spin_dir_y", -dir_y)

func _physics_process(delta: float) -> void:
	if not gravity_enabled:
		return

	if use_zero_g_cluster:
		_update_zero_g_cluster_rotation(delta)
		_check_zero_g_projectile_hits()
		_check_released_zero_g_target_collisions()
		return

	for node in get_tree().get_nodes_in_group("projectiles"):
		if node is RigidBody3D:
			var projectile := node as RigidBody3D

			for target in tracked_targets:
				if target == null:
					continue

				var d: float = projectile.global_position.distance_to(target.global_position)
				if d <= (projectile_radius + target_radius + extra_hit_margin):
					apply_hit(projectile, target)
					return

	for body in escape_timers.keys():
		if body == null:
			continue

		escape_timers[body] -= delta
		if escape_timers[body] <= 0.0:
			escape_timers.erase(body)

	for body in tracked_targets:
		if body == null:
			continue
		if escape_timers.has(body):
			continue

		apply_center_gravity(body)

func _update_zero_g_cluster_rotation(delta: float) -> void:
	if orbital_root == null:
		return

	var angular_speed: float = deg_to_rad(zero_g_rotation_speed_degrees_per_sec) * zero_g_orbit_speed_multiplier
	orbital_root.rotate_y(angular_speed * delta)

func _check_zero_g_projectile_hits() -> void:
	for node in get_tree().get_nodes_in_group("projectiles"):
		if not (node is RigidBody3D):
			continue

		var projectile := node as RigidBody3D

		for target in orbital_targets.duplicate():
			if not is_instance_valid(target):
				continue

			var d: float = projectile.global_position.distance_to(target.global_position)
			if d <= (projectile_radius + target_radius + extra_hit_margin):
				_release_zero_g_target(target, projectile)

func _check_released_zero_g_target_collisions() -> void:
	var released: Array[RigidBody3D] = released_zero_g_targets.duplicate()

	for i in range(released.size()):
		var a: RigidBody3D = released[i]
		if not is_instance_valid(a):
			continue

		for j in range(i + 1, released.size()):
			var b: RigidBody3D = released[j]
			if not is_instance_valid(b):
				continue

			var d: float = a.global_position.distance_to(b.global_position)
			if d <= (target_radius * 2.0 + zero_g_collision_margin):
				_apply_zero_g_target_bounce(a, b)

func _apply_zero_g_target_bounce(a: RigidBody3D, b: RigidBody3D) -> void:
	var normal: Vector3 = b.global_position - a.global_position
	if normal.length() < 0.001:
		return
	normal = normal.normalized()

	var va: Vector3 = a.linear_velocity
	var vb: Vector3 = b.linear_velocity

	var rel: Vector3 = vb - va
	var rel_normal_speed: float = rel.dot(normal)

	if rel_normal_speed >= 0.0:
		return

	var impulse_strength: float = -rel_normal_speed * 0.5

	a.linear_velocity -= normal * impulse_strength
	b.linear_velocity += normal * impulse_strength

func apply_hit(projectile: RigidBody3D, target: RigidBody3D) -> void:
	var normal := (target.global_position - projectile.global_position).normalized()
	var hit_force := projectile.linear_velocity.length()

	target.linear_velocity += normal * max(1.0, hit_force * 0.5)
	escape_timers[target] = 0.5

func apply_center_gravity(body: RigidBody3D) -> void:
	var dir: Vector3 = global_position - body.global_position
	var dist: float = dir.length()

	if dist < 0.001:
		return

	var normal: Vector3 = dir.normalized()
	var softened_dist: float = sqrt(dist * dist + 2.0)
	var force: Vector3 = normal * gravity_strength * (dist / softened_dist)

	body.linear_velocity += force / body.mass

	var center_damping: float = lerp(0.85, damping, clamp(dist / 3.0, 0.0, 1.0))
	body.linear_velocity *= center_damping

	if body.linear_velocity.length() > max_speed:
		body.linear_velocity = body.linear_velocity.normalized() * max_speed

	if body.linear_velocity.length() < 0.05:
		body.linear_velocity = Vector3.ZERO

func spawn_targets() -> void:
	if use_zero_g_cluster:
		_spawn_zero_g_targets_old_style()
	else:
		_spawn_regular_targets()

func _spawn_regular_targets() -> void:
	var min_spawn_count: int = min_spawn_count_base * GameManager.player_level
	var max_spawn_count: int = max_spawn_count_base * GameManager.player_level
	var count: int = randi_range(min_spawn_count, max_spawn_count)

	for i in range(count):
		var target := target_scene.instantiate() as RigidBody3D
		add_child(target)
		target.linear_velocity = Vector3.ZERO
		target.angular_velocity = Vector3.ZERO

		var attempts: int = 0
		var valid_position: bool = false
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

func _spawn_zero_g_targets_old_style() -> void:
	var min_spawn_count: int = min_spawn_count_base * GameManager.player_level
	var max_spawn_count: int = max_spawn_count_base * GameManager.player_level
	var count: int = randi_range(min_spawn_count, max_spawn_count)

	orbital_root = Node3D.new()
	orbital_root.name = "OrbitalRoot"
	add_child(orbital_root)
	orbital_root.position = Vector3.ZERO
	orbital_root.rotation_degrees = Vector3(
		zero_g_orbit_tilt_x_deg,
		zero_g_orbit_tilt_y_deg,
		0.0
	)

	var positions: Array[Vector3] = _generate_even_points_in_sphere(
		count,
		spawn_radius * 0.08,
		spawn_radius * 1.5
	)

	for local_pos in positions:
		var target := target_scene.instantiate() as RigidBody3D
		orbital_root.add_child(target)

		target.position = local_pos
		target.linear_velocity = Vector3.ZERO
		target.angular_velocity = Vector3.ZERO
		target.gravity_scale = 0.0
		target.freeze = true
		target.sleeping = false
		target.contact_monitor = true
		target.max_contacts_reported = 8

		tracked_targets.append(target)
		orbital_targets.append(target)

func _generate_even_points_in_sphere(count: int, inner_radius: float, outer_radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []

	if count <= 0:
		return points

	var rng := RandomNumberGenerator.new()
	rng.seed = int(cluster_seed) + 918273

	var shell_count: int = max(2, int(round(pow(float(count), 1.0 / 3.0))) + 1)
	var placed: int = 0

	var inner_r3: float = inner_radius * inner_radius * inner_radius
	var outer_r3: float = outer_radius * outer_radius * outer_radius
	var golden_angle: float = PI * (3.0 - sqrt(5.0))

	for shell_idx in range(shell_count):
		if placed >= count:
			break

		var shells_left: int = shell_count - shell_idx
		var remaining: int = count - placed
		var points_in_shell: int = max(1, int(round(float(remaining) / float(shells_left))))

		if shell_idx == shell_count - 1:
			points_in_shell = remaining

		var t0: float = float(shell_idx) / float(shell_count)
		var t1: float = float(shell_idx + 1) / float(shell_count)
		var radius_t: float = (t0 + t1) * 0.5

		var radius: float = pow(lerp(inner_r3, outer_r3, radius_t), 1.0 / 3.0)

		var yaw: float = rng.randf_range(0.0, TAU)
		var pitch: float = rng.randf_range(0.0, TAU)
		var shell_basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)

		for i in range(points_in_shell):
			if placed >= count:
				break

			var fi: float = float(i)
			var fn: float = float(points_in_shell)

			var y: float = 1.0 - 2.0 * ((fi + 0.5) / fn)
			var circle_r: float = sqrt(max(0.0, 1.0 - y * y))
			var theta: float = golden_angle * fi

			var dir := Vector3(
				cos(theta) * circle_r,
				y,
				sin(theta) * circle_r
			)

			dir = shell_basis * dir
			points.append(dir * radius)
			placed += 1

	return points

func _release_zero_g_target(target: RigidBody3D, projectile: RigidBody3D) -> void:
	if not is_instance_valid(target):
		return

	if not orbital_targets.has(target):
		return

	var old_global_pos: Vector3 = target.global_position

	var radial: Vector3 = old_global_pos - global_position

	var orbit_axis: Vector3 = orbital_root.global_transform.basis.y.normalized()
	var tangent: Vector3 = orbit_axis.cross(radial).normalized()

	if tangent.length() < 0.001:
		var fallback_axis := Vector3.RIGHT
		if abs(orbit_axis.dot(fallback_axis)) > 0.95:
			fallback_axis = Vector3.FORWARD
		tangent = fallback_axis.cross(radial).normalized()

	if tangent.length() < 0.001:
		tangent = Vector3.RIGHT

	var orbit_speed_rad: float = deg_to_rad(zero_g_rotation_speed_degrees_per_sec) * zero_g_orbit_speed_multiplier
	var tangential_speed: float = radial.length() * orbit_speed_rad

	var projectile_velocity: Vector3 = projectile.linear_velocity
	var hit_normal: Vector3 = old_global_pos - projectile.global_position
	if hit_normal.length() < 0.001:
		hit_normal = radial.normalized()
	hit_normal = hit_normal.normalized()

	var inherited_orbit_velocity: Vector3 = tangent * tangential_speed
	var hit_push: Vector3 = hit_normal * max(projectile_velocity.length() * zero_g_release_speed_multiplier, zero_g_release_extra_push)

	orbital_root.remove_child(target)
	add_child(target)

	target.global_position = old_global_pos
	target.freeze = false
	target.sleeping = false
	target.gravity_scale = 0.0
	target.linear_damp = 0.0
	target.angular_damp = 0.05
	target.linear_velocity = inherited_orbit_velocity + hit_push

	var spin_axis: Vector3 = hit_normal.cross(projectile_velocity)
	if spin_axis.length() < 0.001:
		spin_axis = Vector3.UP

	target.angular_velocity = spin_axis.normalized() * projectile_velocity.length() * zero_g_spin_multiplier

	orbital_targets.erase(target)
	released_zero_g_targets.append(target)

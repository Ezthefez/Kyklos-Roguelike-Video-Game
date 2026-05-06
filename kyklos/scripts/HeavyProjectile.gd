extends RigidBody3D

@export var target_group_name: StringName = &"targetspheres"
@export var barrier_group_name: StringName = &"barrier"

@export var straight_speed_multiplier: float = 1.0
@export var max_lifetime: float = 8.0

@export var sweep_radius: float = 0.55
@export var barrier_collision_mask: int = 1
@export var bounce_damping: float = 0.92
@export var min_speed_after_bounce: float = 3.0
@export var hit_skin: float = 0.04

var _launch_direction: Vector3 = Vector3.ZERO
var _launch_speed: float = 0.0
var _life_timer: float = 0.0

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 100.0
	lock_rotation = true
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	sleeping = false
	add_to_group("projectiles")

func launch(direction: Vector3, base_impulse: float) -> void:
	_launch_direction = direction.normalized()
	_launch_speed = base_impulse * straight_speed_multiplier
	linear_velocity = _launch_direction * _launch_speed
	angular_velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	_life_timer += delta
	if _life_timer >= max_lifetime:
		queue_free()
		return

	if _launch_direction == Vector3.ZERO:
		return

	_sweep_and_bounce_only_on_barrier(delta)

	linear_velocity = _launch_direction * _launch_speed
	angular_velocity = Vector3.ZERO

func _sweep_and_bounce_only_on_barrier(delta: float) -> void:
	var travel: float = _launch_speed * delta
	if travel <= 0.0:
		return

	var from_pos: Vector3 = global_position
	var to_pos: Vector3 = from_pos + _launch_direction * travel

	var ray := PhysicsRayQueryParameters3D.create(from_pos, to_pos, barrier_collision_mask, [self])
	ray.collide_with_bodies = true
	ray.collide_with_areas = false
	ray.hit_back_faces = true
	ray.hit_from_inside = true

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)

	if result.is_empty():
		return

	var collider: Object = result.get("collider")
	if collider == null:
		return

	if not _is_barrier_collider(collider):
		return

	var hit_position: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"].normalized()

	if hit_normal.length_squared() < 0.0001:
		return

	global_position = hit_position + hit_normal * (sweep_radius + hit_skin)
	_launch_direction = _launch_direction.bounce(hit_normal).normalized()
	_launch_speed = max(_launch_speed * bounce_damping, min_speed_after_bounce)

func _is_barrier_collider(collider: Object) -> bool:
	if not (collider is Node):
		return false

	var node := collider as Node

	if node.is_in_group(target_group_name):
		return false

	if node.is_in_group(barrier_group_name):
		return true

	var current: Node = node
	while current != null:
		if current.is_in_group(barrier_group_name):
			return true
		current = current.get_parent()

	return false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.get_contact_count() <= 0:
		return

	for i in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(i)
		if collider == null:
			continue

		if not _is_barrier_collider(collider):
			continue

		var v: Vector3 = state.linear_velocity
		if v.length_squared() > 0.0001:
			_launch_direction = v.normalized()
			_launch_speed = max(v.length(), min_speed_after_bounce)
		return

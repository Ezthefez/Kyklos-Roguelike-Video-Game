extends RigidBody3D

@export var target_group_name: StringName = &"targetspheres"
@export var push_radius: float = 0.65
@export var target_push_impulse: float = 80.0
@export var straight_speed_multiplier: float = 1.0
@export var max_lifetime: float = 8.0
@export var query_collision_mask: int = 0

var _launch_direction: Vector3 = Vector3.ZERO
var _launch_speed: float = 0.0
var _life_timer: float = 0.0
var _hit_ids: Dictionary = {}

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 100.0
	lock_rotation = true
	continuous_cd = true
	contact_monitor = false
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

	# Force exact straight travel every physics frame.
	linear_velocity = _launch_direction * _launch_speed
	angular_velocity = Vector3.ZERO

	# Manually detect target spheres in a radius around the heavy projectile.
	var sphere := SphereShape3D.new()
	sphere.radius = push_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	if query_collision_mask != 0:
		query.collision_mask = query_collision_mask

	var results := get_world_3d().direct_space_state.intersect_shape(query, 32)

	for result in results:
		var body: Object = result["collider"]

		if body == null:
			continue
		if not body.is_in_group(target_group_name):
			continue

		var body_id := body.get_instance_id()
		if _hit_ids.has(body_id):
			continue
		_hit_ids[body_id] = true

		if body is RigidBody3D:
			var target_body := body as RigidBody3D

			var push_dir: Vector3 = target_body.global_position - global_position
			if push_dir.length_squared() < 0.0001:
				push_dir = _launch_direction
			else:
				push_dir = push_dir.normalized()

			target_body.apply_central_impulse(push_dir * target_push_impulse)

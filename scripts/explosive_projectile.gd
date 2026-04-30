extends RigidBody3D

@export var target_group_name: StringName = &"targetspheres"

@export var max_explosion_radius: float = 2.5
@export var explosion_duration: float = 0.18
@export var explosion_force: float = 35.0
@export var max_lifetime: float = 8.0

var _launch_direction: Vector3 = Vector3.ZERO
var _launch_speed: float = 0.0
var _life_timer: float = 0.0

var _has_exploded: bool = false
var _explosion_timer: float = 0.0
var _current_radius: float = 0.01
var _last_radius: float = 0.01

# Each target only gets blasted once, at the moment the shock front reaches it
var _blasted_ids: Dictionary = {}

@onready var projectile_mesh: MeshInstance3D = $Mesh
@onready var projectile_collision: CollisionShape3D = $CollisionShape3D
@onready var explosion_visual: MeshInstance3D = $ExplosionVisual

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	add_to_group("projectiles")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if explosion_visual != null:
		explosion_visual.visible = false

func launch(direction: Vector3, base_impulse: float) -> void:
	_launch_direction = direction.normalized()
	_launch_speed = base_impulse
	linear_velocity = _launch_direction * _launch_speed

func _physics_process(delta: float) -> void:
	_life_timer += delta

	if not _has_exploded and _life_timer >= max_lifetime:
		queue_free()
		return

	if _has_exploded:
		_update_explosion(delta)

func _on_body_entered(body: Node) -> void:
	if _has_exploded:
		return
	if body == null:
		return
	if not body.is_in_group(target_group_name):
		return

	_trigger_explosion()

func _trigger_explosion() -> void:
	_has_exploded = true
	_explosion_timer = 0.0
	_current_radius = 0.01
	_last_radius = 0.01
	_blasted_ids.clear()

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	freeze = false

	if projectile_mesh != null:
		projectile_mesh.visible = false

	if explosion_visual != null:
		explosion_visual.visible = true

	_set_explosion_radius(_current_radius)

func _update_explosion(delta: float) -> void:
	_explosion_timer += delta

	var t: float = clamp(_explosion_timer / explosion_duration, 0.0, 1.0)

	# Fast expansion
	var growth_t: float = 1.0 - pow(1.0 - t, 4.0)

	_last_radius = _current_radius
	_current_radius = lerp(0.01, max_explosion_radius, growth_t)

	_set_explosion_radius(_current_radius)
	_blast_targets_when_wave_reaches_them()

	if _explosion_timer >= explosion_duration:
		queue_free()

func _blast_targets_when_wave_reaches_them() -> void:
	var targets := get_tree().get_nodes_in_group(target_group_name)

	for node in targets:
		if node == null:
			continue
		if not node is RigidBody3D:
			continue

		var target := node as RigidBody3D
		var target_id := target.get_instance_id()

		if _blasted_ids.has(target_id):
			continue

		var offset: Vector3 = target.global_position - global_position
		var distance: float = offset.length()

		# Only blast when the expanding wave FRONT reaches the target
		if distance <= _last_radius:
			continue
		if distance > _current_radius:
			continue

		var dir: Vector3
		if distance < 0.0001:
			dir = Vector3.UP
		else:
			dir = offset / distance

		# Wake target so the force actually applies
		target.freeze = false
		target.sleeping = false

		# Pure radial blast, physically more realistic
		target.linear_velocity += dir * explosion_force

		_blasted_ids[target_id] = true

func _set_explosion_radius(radius: float) -> void:
	var shape := projectile_collision.shape as SphereShape3D
	if shape != null:
		shape.radius = radius

	if explosion_visual != null:
		explosion_visual.scale = Vector3.ONE * radius * 2.0

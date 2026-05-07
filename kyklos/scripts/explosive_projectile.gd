extends RigidBody3D

@export var target_group_name: StringName = &"targetspheres"

@export var max_explosion_radius: float = 2.5
@export var explosion_duration: float = 0.18
@export var explosion_force: float = 35.0
@export var max_lifetime: float = 8.0

@export var trail_scene: PackedScene = preload("res://scenes/ProjectileTrailHelix.tscn")
@export var trail_color: Color = Color(1.0, 0.1, 0.75, 1.0)
@export var trail_visible_seconds: float = 0.95
@export var trail_absolute_max_seconds: float = 25.0
@export var trail_helix_radius: float = 0.08
@export var trail_turns_per_unit: float = 2.8
@export var trail_width: float = 0.045
@export var trail_fade_speed_multiplier: float = 1.0

var _trail_instance: Node = null

var _launch_direction: Vector3 = Vector3.ZERO
var _launch_speed: float = 0.0
var _life_timer: float = 0.0

var _has_exploded: bool = false
var _explosion_timer: float = 0.0
var _current_radius: float = 0.01
var _last_radius: float = 0.01
var _locked_explosion_position: Vector3 = Vector3.ZERO

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
	_spawn_trail()

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
		global_position = _locked_explosion_position
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		_update_explosion(delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _has_exploded:
		return

	state.transform.origin = _locked_explosion_position
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO

func _on_body_entered(body: Node) -> void:
	if _has_exploded:
		return
	if body == null:
		return
	if not body.is_in_group(target_group_name):
		return

	_trigger_explosion()

func _trigger_explosion() -> void:
	if _has_exploded:
		return

	_has_exploded = true
	_explosion_timer = 0.0
	_current_radius = 0.01
	_last_radius = 0.01
	_blasted_ids.clear()
	_locked_explosion_position = global_position

	global_position = _locked_explosion_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	freeze = true

	collision_layer = 0
	collision_mask = 0

	if projectile_collision != null:
		projectile_collision.disabled = true

	if projectile_mesh != null:
		projectile_mesh.visible = false

	if explosion_visual != null:
		explosion_visual.visible = true
		explosion_visual.global_position = _locked_explosion_position

	_set_explosion_radius(_current_radius)

func _update_explosion(delta: float) -> void:
	_explosion_timer += delta

	var total_duration: float = explosion_duration * 2.0

	global_position = _locked_explosion_position
	if explosion_visual != null:
		explosion_visual.global_position = _locked_explosion_position

	if _explosion_timer <= explosion_duration:
		var grow_t: float = clamp(_explosion_timer / explosion_duration, 0.0, 1.0)
		var growth_curve: float = 1.0 - pow(1.0 - grow_t, 4.0)

		_last_radius = _current_radius
		_current_radius = lerp(0.01, max_explosion_radius, growth_curve)

		_set_explosion_radius(_current_radius)
		_blast_targets_when_wave_reaches_them()
		return

	var shrink_t: float = clamp((_explosion_timer - explosion_duration) / explosion_duration, 0.0, 1.0)
	var shrink_curve: float = 1.0 - pow(1.0 - shrink_t, 4.0)

	_last_radius = _current_radius
	_current_radius = lerp(max_explosion_radius, 0.01, shrink_curve)

	_set_explosion_radius(_current_radius)

	if _explosion_timer >= total_duration:
		queue_free()

func _blast_targets_when_wave_reaches_them() -> void:
	var targets := get_tree().get_nodes_in_group(target_group_name)

	for node in targets:
		if node == null:
			continue
		if not (node is RigidBody3D):
			continue

		var target := node as RigidBody3D
		var target_id := target.get_instance_id()

		if _blasted_ids.has(target_id):
			continue

		var offset: Vector3 = target.global_position - _locked_explosion_position
		var distance: float = offset.length()

		if distance <= _last_radius:
			continue
		if distance > _current_radius:
			continue

		var dir: Vector3
		if distance < 0.0001:
			dir = Vector3.UP
		else:
			dir = offset / distance

		target.freeze = false
		target.sleeping = false
		target.linear_velocity += dir * explosion_force

		_blasted_ids[target_id] = true

func _set_explosion_radius(radius: float) -> void:
	var safe_radius: float = max(radius, 0.01)

	if explosion_visual != null:
		explosion_visual.scale = Vector3.ONE * safe_radius * 2.0
		explosion_visual.global_position = _locked_explosion_position

func _spawn_trail() -> void:
	if trail_scene == null:
		return
	if _trail_instance != null:
		return

	_trail_instance = trail_scene.instantiate()
	get_tree().current_scene.add_child(_trail_instance)

	if _trail_instance.has_method("attach_to_target"):
		_trail_instance.call("attach_to_target", self)

	_trail_instance.set("trail_color", trail_color)
	_trail_instance.set("visible_seconds", trail_visible_seconds)
	_trail_instance.set("absolute_max_seconds", trail_absolute_max_seconds)
	_trail_instance.set("helix_radius", trail_helix_radius)
	_trail_instance.set("helix_turns_per_unit", trail_turns_per_unit)
	_trail_instance.set("helix_width", trail_width)
	_trail_instance.set("fade_speed_multiplier", trail_fade_speed_multiplier)

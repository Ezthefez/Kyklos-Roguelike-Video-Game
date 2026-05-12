extends RigidBody3D

@export var target_group_name: StringName = &"targetspheres"
@export var explosion_duration: float = 4.0
@export var max_visual_radius: float = 50.0
@export var max_lifetime: float = 10.0
@export var win_delay_after_hit: float = 7.0

@export var detonation_probe_radius: float = 0.9
@export var detonation_collision_mask: int = 0

@export var trail_scene: PackedScene = preload("res://scenes/ProjectileTrailHelix.tscn")
@export var trail_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var trail_visible_seconds: float = 1.10
@export var trail_absolute_max_seconds: float = 25.0
@export var trail_helix_radius: float = 0.11
@export var trail_turns_per_unit: float = 2.0
@export var trail_width: float = 0.055
@export var trail_fade_speed_multiplier: float = 0.85

var _trail_instance: Node = null

var _launch_direction: Vector3 = Vector3.ZERO
var _launch_speed: float = 0.0
var _life_timer: float = 0.0

var _has_detonated: bool = false
var _detonation_timer: float = 0.0
var _already_resolved_targets: bool = false

@onready var projectile_mesh: MeshInstance3D = $Mesh
@onready var projectile_collision: CollisionShape3D = $CollisionShape3D
@onready var nuclear_visual: MeshInstance3D = $NuclearVisual

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 32
	add_to_group("projectiles")
	_spawn_trail()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if nuclear_visual != null:
		nuclear_visual.visible = false

func launch(direction: Vector3, base_impulse: float) -> void:
	_launch_direction = direction.normalized()
	_launch_speed = base_impulse
	linear_velocity = _launch_direction * _launch_speed

func _physics_process(delta: float) -> void:
	_life_timer += delta

	if not _has_detonated and _life_timer >= max_lifetime:
		queue_free()
		return

	if not _has_detonated:
		_fail_safe_overlap_detonation()

	if _has_detonated:
		_update_detonation(delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _has_detonated:
		return

	if state.get_contact_count() > 0:
		_trigger_detonation()

func _on_body_entered(body: Node) -> void:
	if _has_detonated:
		return
	if body == null:
		return

	_trigger_detonation()

func _fail_safe_overlap_detonation() -> void:
	if _has_detonated:
		return

	var sphere := SphereShape3D.new()
	sphere.radius = detonation_probe_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	if detonation_collision_mask != 0:
		query.collision_mask = detonation_collision_mask

	var results := get_world_3d().direct_space_state.intersect_shape(query, 64)

	for result in results:
		var collider: Object = result.get("collider")
		if collider == null:
			continue
		if collider == self:
			continue
		if collider is Node and (collider as Node).is_in_group("projectiles"):
			continue

		_trigger_detonation()
		return

func _trigger_detonation() -> void:
	if _has_detonated:
		return

	_has_detonated = true
	_detonation_timer = 0.0

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = true

	if projectile_mesh != null:
		projectile_mesh.visible = false

	if projectile_collision != null:
		projectile_collision.disabled = true

	collision_layer = 0
	collision_mask = 0

	if nuclear_visual != null:
		nuclear_visual.visible = true
		nuclear_visual.scale = Vector3.ONE * 0.2

	if GameManager != null:
		GameManager.emit_signal("nuclear_detonated", global_position)

	_resolve_all_remaining_targets()

	if GameManager != null:
		GameManager.schedule_nuclear_win(win_delay_after_hit)

func _resolve_all_remaining_targets() -> void:
	if _already_resolved_targets:
		return
	_already_resolved_targets = true

	var targets := get_tree().get_nodes_in_group(target_group_name)
	var collected_now: int = 0

	for node in targets:
		if node == null:
			continue
		if not (node is RigidBody3D):
			continue

		var target := node as RigidBody3D
		collected_now += 1

		target.collision_layer = 0
		target.collision_mask = 0
		target.freeze = true
		target.sleeping = true

		if target.has_method("begin_boundary_harvest"):
			target.call_deferred("begin_boundary_harvest")
		else:
			target.call_deferred("queue_free")

	if GameManager != null:
		GameManager.targets_collected += collected_now
		GameManager.targets_remaining = 0

		# Nuclear harvest rewards NORMAL ammo
		GameManager.normal_ammo += collected_now
		GameManager.emit_ammo_changed()

func _update_detonation(delta: float) -> void:
	_detonation_timer += delta

	var t: float = clamp(_detonation_timer / explosion_duration, 0.0, 1.0)
	var growth_t: float = 1.0 - pow(1.0 - t, 3.0)

	if nuclear_visual != null:
		nuclear_visual.scale = Vector3.ONE * lerp(0.2, max_visual_radius, growth_t)

	if _detonation_timer >= explosion_duration:
		queue_free()

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

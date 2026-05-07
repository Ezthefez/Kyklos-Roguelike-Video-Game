extends RigidBody3D

@export var projectile_mass: float = 1.0
@export var projectile_gravity_scale: float = 0.0
@export var projectile_linear_damp: float = 0.0
@export var projectile_angular_damp: float = 0.0

@export var projectile_collision_layer: int = 1
@export var projectile_collision_mask: int = 1

@export var trail_scene: PackedScene = preload("res://scenes/ProjectileTrailHelix.tscn")
@export var trail_color: Color = Color(0.1, 0.75, 1.0, 1.0)
@export var trail_visible_seconds: float = 0.75
@export var trail_absolute_max_seconds: float = 25.0
@export var trail_helix_radius: float = 0.06
@export var trail_turns_per_unit: float = 3.0
@export var trail_width: float = 0.035
@export var trail_fade_speed_multiplier: float = 1.0

var _trail_instance: Node = null

func _ready() -> void:
	mass = projectile_mass
	gravity_scale = projectile_gravity_scale
	linear_damp = projectile_linear_damp
	angular_damp = projectile_angular_damp

	collision_layer = projectile_collision_layer
	collision_mask = projectile_collision_mask

	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true

	add_to_group("projectiles")
	_spawn_trail()

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

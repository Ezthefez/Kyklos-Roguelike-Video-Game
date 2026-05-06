extends RigidBody3D

@export var projectile_mass: float = 1.0
@export var projectile_gravity_scale: float = 0.0
@export var projectile_linear_damp: float = 0.0
@export var projectile_angular_damp: float = 0.0

@export var projectile_collision_layer: int = 1
@export var projectile_collision_mask: int = 1

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

extends RigidBody3D

@export var projectile_mass: float = 1.0
@export var projectile_gravity_scale: float = 0.0
@export var projectile_linear_damp: float = 0.0
@export var projectile_angular_damp: float = 0.0

func _ready() -> void:
	mass = projectile_mass
	gravity_scale = projectile_gravity_scale
	linear_damp = projectile_linear_damp
	angular_damp = projectile_angular_damp
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true

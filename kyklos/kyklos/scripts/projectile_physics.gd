extends RigidBody3D

func _ready() -> void:
	mass = 1.0
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true

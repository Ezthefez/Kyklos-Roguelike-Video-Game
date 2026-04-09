extends RigidBody3D

@export var start_angular_velocity: Vector3 = Vector3.ZERO
@export var target_group_name: StringName = &"targetspheres"
@export var harvest_duration: float = 0.35
@export var harvest_scale_multiplier: float = 1.22

func _ready() -> void:
	mass = 2.0
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 8
	add_to_group(target_group_name)
	angular_velocity = start_angular_velocity

func begin_boundary_harvest() -> void:
	freeze = true
	sleeping = true

	var mesh := _find_mesh()
	if mesh == null:
		queue_free()
		return

	var mat := _ensure_unique_material(mesh)
	var start_scale := mesh.scale
	var end_scale := start_scale * harvest_scale_multiplier

	if mat is StandardMaterial3D:
		var std := mat as StandardMaterial3D
		std.emission_enabled = true
		std.emission = Color(1.6, 2.2, 2.8)
		std.albedo_color = Color(std.albedo_color.r, std.albedo_color.g, std.albedo_color.b, 1.0)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mesh, "scale", end_scale, harvest_duration)
		tween.tween_property(std, "emission_energy_multiplier", 3.5, harvest_duration)
		tween.tween_property(std, "albedo_color:a", 0.0, harvest_duration)
		tween.finished.connect(queue_free)
	else:
		var tween := create_tween()
		tween.tween_property(mesh, "scale", end_scale, harvest_duration)
		tween.finished.connect(queue_free)

func _find_mesh() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null

func _ensure_unique_material(mesh: MeshInstance3D) -> Material:
	var mat := mesh.material_override
	if mat == null and mesh.mesh != null:
		mat = mesh.mesh.surface_get_material(0)

	if mat == null:
		var std := StandardMaterial3D.new()
		mesh.material_override = std
		return std

	var dup := mat.duplicate()
	mesh.material_override = dup
	return dup

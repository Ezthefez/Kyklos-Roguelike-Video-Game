extends MeshInstance3D

@export var follow_camera: bool = true
@export var distance_from_camera: float = 0.0

var _camera: Camera3D = null
var _material: ShaderMaterial = null

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()

	if material_override is ShaderMaterial:
		_material = material_override as ShaderMaterial
	else:
		push_error("NebulaSphere needs a ShaderMaterial in material_override.")
		return

	_material.render_priority = -10
	_randomize_milky_way()

func _process(_delta: float) -> void:
	if follow_camera and _camera != null:
		global_position = _camera.global_position

func _randomize_milky_way() -> void:
	var rng := RandomNumberGenerator.new()

	if has_node("/root/GameManager"):
		var gm := get_node("/root/GameManager")
		if "selected_seed" in gm:
			rng.seed = int(gm.selected_seed) + 91357
		else:
			rng.randomize()
	else:
		rng.randomize()

	# No black palettes. All are visible and fairly bright.
	var palettes: Array = [
		[
			Color(0.18, 0.28, 0.75, 1.0),
			Color(0.70, 0.28, 0.85, 1.0),
			Color(1.00, 0.82, 0.62, 1.0)
		],
		[
			Color(0.16, 0.45, 0.85, 1.0),
			Color(0.82, 0.30, 0.72, 1.0),
			Color(1.00, 0.74, 0.48, 1.0)
		],
		[
			Color(0.24, 0.32, 0.90, 1.0),
			Color(0.55, 0.35, 0.95, 1.0),
			Color(1.00, 0.88, 0.70, 1.0)
		],
		[
			Color(0.14, 0.36, 0.72, 1.0),
			Color(0.88, 0.36, 0.66, 1.0),
			Color(1.00, 0.80, 0.55, 1.0)
		],
		[
			Color(0.20, 0.26, 0.68, 1.0),
			Color(0.76, 0.26, 0.96, 1.0),
			Color(1.00, 0.90, 0.72, 1.0)
		]
	]

	var palette: Array = palettes[rng.randi_range(0, palettes.size() - 1)]

	_material.set_shader_parameter("color_a", palette[0])
	_material.set_shader_parameter("color_b", palette[1])
	_material.set_shader_parameter("color_c", palette[2])

	# Stronger values so it is easier to see in-game.
	_material.set_shader_parameter("brightness", rng.randf_range(5.0, 8.0))
	_material.set_shader_parameter("band_width", rng.randf_range(0.22, 0.34))
	_material.set_shader_parameter("band_softness", rng.randf_range(1.2, 2.2))
	_material.set_shader_parameter("dust_strength", rng.randf_range(1.2, 1.9))
	_material.set_shader_parameter("broad_scale", rng.randf_range(2.4, 3.8))
	_material.set_shader_parameter("detail_scale", rng.randf_range(12.0, 20.0))
	_material.set_shader_parameter("fine_scale", rng.randf_range(26.0, 42.0))
	_material.set_shader_parameter("core_strength", rng.randf_range(3.2, 5.5))
	_material.set_shader_parameter("haze_strength", rng.randf_range(0.35, 0.65))

	var band_normal := Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-0.25, 0.25),
		rng.randf_range(-1.0, 1.0)
	).normalized()

	if band_normal.length() < 0.001:
		band_normal = Vector3.UP

	var core_direction := Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-0.15, 0.15),
		rng.randf_range(-1.0, 1.0)
	).normalized()

	if core_direction.length() < 0.001:
		core_direction = Vector3(0.8, 0.0, -0.6)

	_material.set_shader_parameter("band_normal", band_normal)
	_material.set_shader_parameter("core_direction", core_direction)

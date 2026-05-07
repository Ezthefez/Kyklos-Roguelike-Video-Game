extends Node3D

@export var trail_color: Color = Color(0.2, 0.8, 1.0, 1.0)
@export var point_spacing: float = 0.18
@export var visible_seconds: float = 0.85
@export var absolute_max_seconds: float = 25.0

@export var helix_radius: float = 0.08
@export var helix_turns_per_unit: float = 2.4
@export var helix_width: float = 0.045
@export var fade_speed_multiplier: float = 1.0

@export var start_delay_seconds: float = 0.03
@export var min_distance_before_visible: float = 1.4

var _target: Node3D = null
var _ages: Array[float] = []
var _points: Array[Vector3] = []
var _alive_time: float = 0.0
var _last_added_point: Vector3 = Vector3.ZERO
var _has_last_point: bool = false
var _anchor_position: Vector3 = Vector3.ZERO
var _spawn_position: Vector3 = Vector3.ZERO
var _capture_enabled: bool = false

var _mat_a: StandardMaterial3D
var _mat_b: StandardMaterial3D

@onready var helix_a: MeshInstance3D = $HelixA
@onready var helix_b: MeshInstance3D = $HelixB

func _ready() -> void:
	top_level = true
	_mat_a = _make_material()
	_mat_b = _make_material()

	helix_a.material_override = _mat_a
	helix_b.material_override = _mat_b

func attach_to_target(target: Node3D) -> void:
	_target = target
	if is_instance_valid(_target):
		_spawn_position = _target.global_position
		_anchor_position = _spawn_position
		global_position = _anchor_position
		_last_added_point = _spawn_position
		_has_last_point = false
		_capture_enabled = false
		_points.clear()
		_ages.clear()

func _process(delta: float) -> void:
	_alive_time += delta
	if _alive_time >= absolute_max_seconds:
		queue_free()
		return

	_age_points(delta * fade_speed_multiplier)
	_try_enable_capture()
	_capture_target_position()
	_drop_dead_points()
	_rebuild_meshes()

	if _points.size() <= 1 and not is_instance_valid(_target):
		queue_free()

func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = trail_color
	mat.emission_enabled = true
	mat.emission = trail_color
	mat.emission_energy_multiplier = 3.0
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _age_points(delta: float) -> void:
	for i in range(_ages.size()):
		_ages[i] += delta

func _try_enable_capture() -> void:
	if _capture_enabled:
		return
	if not is_instance_valid(_target):
		return
	if _alive_time < start_delay_seconds:
		return

	var dist: float = _target.global_position.distance_to(_spawn_position)
	if dist < min_distance_before_visible:
		return

	_capture_enabled = true

	var p: Vector3 = _target.global_position
	_anchor_position = p
	global_position = _anchor_position

	_points.clear()
	_ages.clear()

	_points.append(p)
	_ages.append(0.0)
	_last_added_point = p
	_has_last_point = true

func _capture_target_position() -> void:
	if not is_instance_valid(_target):
		_target = null
		return

	if not _capture_enabled:
		return

	var p: Vector3 = _target.global_position

	if not _has_last_point:
		_points.append(p)
		_ages.append(0.0)
		_last_added_point = p
		_has_last_point = true
		return

	if p.distance_to(_last_added_point) >= point_spacing:
		_points.append(p)
		_ages.append(0.0)
		_last_added_point = p

func _drop_dead_points() -> void:
	while _ages.size() > 0 and _ages[0] > visible_seconds:
		_ages.remove_at(0)
		_points.remove_at(0)

	if _points.size() == 0:
		_has_last_point = false
		return

	_anchor_position = _points[0]
	global_position = _anchor_position

func _rebuild_meshes() -> void:
	_build_helix_mesh(helix_a, 0.0)
	_build_helix_mesh(helix_b, PI)

func _build_helix_mesh(mesh_instance: MeshInstance3D, phase_offset: float) -> void:
	if _points.size() < 2:
		mesh_instance.mesh = null
		return

	var cam: Camera3D = get_viewport().get_camera_3d()
	var cam_pos: Vector3 = Vector3.ZERO
	if cam != null:
		cam_pos = cam.global_position

	var immediate := ImmediateMesh.new()
	immediate.clear_surfaces()
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var traveled: float = 0.0
	var half_width: float = helix_width * 0.5

	for i in range(_points.size()):
		var p: Vector3 = _points[i]
		var tangent: Vector3

		if i == 0:
			tangent = (_points[i + 1] - p).normalized()
		elif i == _points.size() - 1:
			tangent = (p - _points[i - 1]).normalized()
		else:
			tangent = (_points[i + 1] - _points[i - 1]).normalized()

		if tangent.length_squared() < 0.0001:
			tangent = Vector3.FORWARD

		if i > 0:
			traveled += _points[i].distance_to(_points[i - 1])

		var side_1 := tangent.cross(Vector3.UP)
		if side_1.length_squared() < 0.0001:
			side_1 = tangent.cross(Vector3.RIGHT)
		side_1 = side_1.normalized()
		var side_2 := tangent.cross(side_1).normalized()

		var phase: float = traveled * TAU * helix_turns_per_unit + phase_offset
		var helix_center: Vector3 = p + side_1 * cos(phase) * helix_radius + side_2 * sin(phase) * helix_radius

		var ribbon_side: Vector3
		if cam != null:
			var to_camera := (cam_pos - helix_center).normalized()
			ribbon_side = tangent.cross(to_camera)
			if ribbon_side.length_squared() < 0.0001:
				ribbon_side = side_1
			else:
				ribbon_side = ribbon_side.normalized()
		else:
			ribbon_side = side_1

		var alpha: float = 1.0 - clamp(_ages[i] / visible_seconds, 0.0, 1.0)
		var c := trail_color
		c.a = alpha

		var left_v: Vector3 = (helix_center - ribbon_side * half_width) - _anchor_position
		var right_v: Vector3 = (helix_center + ribbon_side * half_width) - _anchor_position

		immediate.surface_set_color(c)
		immediate.surface_add_vertex(left_v)
		immediate.surface_set_color(c)
		immediate.surface_add_vertex(right_v)

	immediate.surface_end()
	mesh_instance.mesh = immediate

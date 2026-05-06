extends Node3D
class_name ResourceHarvestEffect

@export var bead_radius: float = 0.055
@export var travel_time: float = 0.20
@export var fade_time: float = 0.08
@export var arc_strength: float = 1.1
@export var sideways_strength: float = 0.45
@export var brightness: float = 7.5
@export var bead_count: int = 14

var _start_position: Vector3
var _target_position: Vector3
var _control_position: Vector3

var _elapsed: float = 0.0
var _beads: Array[MeshInstance3D] = []

func setup(start_position: Vector3, target_position: Vector3) -> void:
	_start_position = start_position
	_target_position = target_position

	var mid: Vector3 = (_start_position + _target_position) * 0.5
	var dir: Vector3 = (_target_position - _start_position).normalized()

	var camera: Camera3D = get_viewport().get_camera_3d()
	var side: Vector3 = Vector3.ZERO
	if camera != null:
		side = dir.cross(camera.global_transform.basis.y).normalized()

	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT

	_control_position = mid + Vector3.UP * arc_strength + side * sideways_strength

	_build_beads()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _build_beads() -> void:
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = bead_radius
	sphere_mesh.height = bead_radius * 2.0

	for i in range(bead_count):
		var bead := MeshInstance3D.new()
		bead.mesh = sphere_mesh

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 1.0, 1.0)
		mat.emission_energy_multiplier = brightness
		mat.no_depth_test = true

		bead.material_override = mat
		add_child(bead)
		_beads.append(bead)

func _process(delta: float) -> void:
	_elapsed += delta

	var duration: float = travel_time + fade_time
	var life_t: float = clamp(_elapsed / duration, 0.0, 1.0)

	var head_t: float = clamp(_elapsed / travel_time, 0.0, 1.0)

	for i in range(_beads.size()):
		var bead: MeshInstance3D = _beads[i]
		var denom: float = max(float(_beads.size() - 1), 1.0)
		var offset_t: float = float(i) / denom
		var bead_t: float = clamp(head_t - offset_t * 0.12, 0.0, 1.0)

		bead.global_position = _quadratic_bezier(_start_position, _control_position, _target_position, bead_t)

		var fade: float = 1.0 - life_t
		var bead_alpha: float = max(0.0, fade * (1.0 - offset_t * 0.35))
		bead.scale = Vector3.ONE * lerp(1.0, 0.35, bead_t)

		var mat := bead.get_active_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = bead_alpha

	if _elapsed >= duration:
		queue_free()

func _quadratic_bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var ab: Vector3 = a.lerp(b, t)
	var bc: Vector3 = b.lerp(c, t)
	return ab.lerp(bc, t)

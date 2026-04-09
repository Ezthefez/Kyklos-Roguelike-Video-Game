extends Node3D
# Kyklos Orbit Camera + Constrained Look + Charge Shot + Charge Sway + Ammo

@export var orbit_center: Node3D
@export var orbit_speed: float = 2.0

@export var camera_yaw: Node3D
@export var camera_pitch: Node3D
@export var camera: Camera3D
@export var muzzle: Marker3D

@export var look_speed: float = 0.08
@export var max_yaw: float = 30.0
@export var max_pitch: float = 18.0
@export var max_vertical: float = 0.9

@export var projectile_scene: PackedScene
@export var fire_cooldown: float = 0.12

@export var charge_duration: float = 0.65
@export var min_shoot_impulse: float = 1.0
@export var max_shoot_impulse: float = 40.0

@export var charge_circle: TextureProgressBar

# Ammo
@export var starting_ammo: int = 7
@export var ammo_label: Label
@export var no_ammo_label: Label

# Sway settings
@export var strong_sway_duration: float = 0.3
@export var strong_sway_strength_yaw: float = 10.0
@export var strong_sway_strength_pitch: float = 5.0

@export var follow_sway_strength_yaw: float = 3.0
@export var follow_sway_strength_pitch: float = 3.0
@export var follow_sway_speed: float = 3.0
@export var sway_return_speed: float = -1.0

var yaw: float = 0.0
var pitch: float = 0.0
var can_fire: bool = true

var is_charging: bool = false
var charge_time: float = 0.0
var charge_hold_time: float = 0.0

var sway_yaw: float = 0.0
var sway_pitch: float = 0.0

var strong_sway_dir: Vector2 = Vector2.ZERO
var last_mouse_dir: Vector2 = Vector2.RIGHT
var current_follow_dir: Vector2 = Vector2.RIGHT

var current_ammo: int = 0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_charge_ui(0.0)

	current_ammo = starting_ammo
	_update_ammo_ui()

	if no_ammo_label != null:
		no_ammo_label.visible = false

func _process(delta: float) -> void:
	handle_movement(delta)
	update_camera(delta)

	if is_charging:
		charge_time += delta
		charge_hold_time += delta

		var ratio: float = _get_charge_ratio()
		_update_charge_ui(ratio)
		update_charge_sway(delta)
	else:
		sway_yaw = lerp(sway_yaw, 0.0, sway_return_speed * delta)
		sway_pitch = lerp(sway_pitch, 0.0, sway_return_speed * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mouse_vec: Vector2 = Vector2(-event.relative.x, -event.relative.y)

		if mouse_vec.length() > 0.001:
			last_mouse_dir = mouse_vec.normalized()
			current_follow_dir = last_mouse_dir

		yaw -= event.relative.x * look_speed
		pitch -= event.relative.y * look_speed
		_apply_circular_aim_clamp()

	if event.is_action_pressed("shoot"):
		start_charge()

	if event.is_action_released("shoot"):
		release_charge_and_fire()

func _apply_circular_aim_clamp() -> void:
	var nx: float = yaw / max_yaw
	var ny: float = pitch / max_pitch
	var len_sq: float = nx * nx + ny * ny

	if len_sq > 1.0:
		var len: float = sqrt(len_sq)
		nx /= len
		ny /= len
		yaw = nx * max_yaw
		pitch = ny * max_pitch

func _apply_circular_sway_clamp() -> void:
	var nx: float = sway_yaw / max_yaw
	var ny: float = sway_pitch / max_pitch
	var len_sq: float = nx * nx + ny * ny

	if len_sq > 1.0:
		var len: float = sqrt(len_sq)
		nx /= len
		ny /= len
		sway_yaw = nx * max_yaw
		sway_pitch = ny * max_pitch

func update_charge_sway(delta: float) -> void:
	if charge_hold_time <= strong_sway_duration:
		var t: float = 1.0 - (charge_hold_time / strong_sway_duration)
		sway_yaw = strong_sway_dir.x * strong_sway_strength_yaw * t
		sway_pitch = strong_sway_dir.y * strong_sway_strength_pitch * t
	else:
		var target_yaw: float = current_follow_dir.x * follow_sway_strength_yaw
		var target_pitch: float = current_follow_dir.y * follow_sway_strength_pitch

		sway_yaw = lerp(sway_yaw, target_yaw, follow_sway_speed * delta)
		sway_pitch = lerp(sway_pitch, target_pitch, follow_sway_speed * delta)

	_apply_circular_sway_clamp()

func handle_movement(delta: float) -> void:
	var input_x: float = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var input_y: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	if orbit_center == null:
		return

	var center: Vector3 = orbit_center.global_position
	var to_center: Vector3 = (global_position - center).normalized()

	var right_axis: Vector3 = Vector3.UP.cross(to_center).normalized()

	rotate_around(center, right_axis, input_y * orbit_speed * delta)
	rotate_around(center, Vector3.UP, -input_x * orbit_speed * delta)

	var new_dir: Vector3 = (global_position - center).normalized()
	var vertical_dot: float = new_dir.dot(Vector3.UP)

	if abs(vertical_dot) > max_vertical:
		var radius: float = (global_position - center).length()
		var clamped_y: float = signf(vertical_dot) * max_vertical
		var horizontal: float = sqrt(1.0 - clamped_y * clamped_y)
		var horiz_dir: Vector3 = Vector3(new_dir.x, 0.0, new_dir.z).normalized()
		var clamped_dir: Vector3 = Vector3(
			horiz_dir.x * horizontal,
			clamped_y,
			horiz_dir.z * horizontal
		)
		global_position = center + clamped_dir * radius

	look_at(center, Vector3.UP)

func rotate_around(center: Vector3, axis: Vector3, angle: float) -> void:
	var offset: Vector3 = global_position - center
	offset = offset.rotated(axis, angle)
	global_position = center + offset

func update_camera(delta: float) -> void:
	var final_yaw: float = yaw + sway_yaw
	var final_pitch: float = pitch + sway_pitch

	if camera_yaw != null:
		camera_yaw.rotation_degrees.y = lerp(camera_yaw.rotation_degrees.y, final_yaw, 10.0 * delta)
	if camera_pitch != null:
		camera_pitch.rotation_degrees.x = lerp(camera_pitch.rotation_degrees.x, final_pitch, 10.0 * delta)

func start_charge() -> void:
	if not can_fire:
		return
	if is_charging:
		return
	if not _has_ammo():
		_update_ammo_ui()
		return

	is_charging = true
	charge_time = 0.0
	charge_hold_time = 0.0
	_update_charge_ui(0.0)

	var angle: float = randf() * TAU
	strong_sway_dir = Vector2(cos(angle), sin(angle)).normalized()
	current_follow_dir = last_mouse_dir

func release_charge_and_fire() -> void:
	if not is_charging:
		return
	if not can_fire:
		is_charging = false
		_update_charge_ui(0.0)
		return

	var ratio: float = _get_charge_ratio()
	is_charging = false
	_update_charge_ui(0.0)

	sway_yaw = 0.0
	sway_pitch = 0.0

	fire_with_power(ratio)

func fire_with_power(charge_ratio: float) -> void:
	if not can_fire:
		return
	if projectile_scene == null:
		return
	if camera == null or muzzle == null:
		return
	if not _has_ammo():
		_update_ammo_ui()
		return

	can_fire = false

	current_ammo -= 1
	_update_ammo_ui()

	var projectile := projectile_scene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(projectile)
	projectile.global_transform = muzzle.global_transform

	var dir: Vector3 = -camera.global_transform.basis.z.normalized()
	var impulse: float = lerp(min_shoot_impulse, max_shoot_impulse, charge_ratio)

	projectile.apply_central_impulse(dir * impulse)

	await get_tree().create_timer(fire_cooldown).timeout
	can_fire = true

func _get_charge_ratio() -> float:
	if charge_duration <= 0.0:
		return 1.0

	return fposmod(charge_time, charge_duration) / charge_duration

func _update_charge_ui(ratio: float) -> void:
	if charge_circle == null:
		return

	charge_circle.min_value = 0.0
	charge_circle.max_value = 1.0
	charge_circle.value = clamp(ratio, 0.0, 1.0)
	charge_circle.queue_redraw()

func _update_ammo_ui() -> void:
	if ammo_label != null:
		ammo_label.text = "Kyklon Ammo: " + str(current_ammo)

	if no_ammo_label != null:
		no_ammo_label.visible = current_ammo <= 0

func _has_ammo() -> bool:
	return current_ammo > 0

#orbit_controller_kyklos.gd

extends Node3D
# Kyklos Orbit Camera + Charge Shot using screen-space crosshair aim + smooth 360 sway

@export var orbit_center: Node3D
@export var orbit_speed: float = 2.0

# Camera rig
@export var camera_yaw: Node3D
@export var camera_pitch: Node3D
@export var camera: Camera3D
@export var muzzle: Marker3D

# Normal mouse look when NOT charging
@export var look_speed: float = 0.08
@export var max_yaw: float = 30.0
@export var max_pitch: float = 18.0
@export var max_vertical: float = 0.9

# Shooting
@export var shoot_impulse: float = 25.0
@export var fire_cooldown: float = 0.12
@export var projectile_scene: PackedScene
@export var charge_time: float = 1.0

# Charge aim settings
@export var charge_aim_pixels_per_mouse_unit: float = 2.0
@export var charge_aim_smooth_speed: float = 14.0

# Smooth 360 sway settings
@export var sway_push_strength: float = 45.0
@export var sway_max_speed: float = 20.0
@export var sway_drag: float = 3.0
@export var sway_idle_strength: float = 3.0

# UI
# Assign this to UI/CanvasLayer/CrosshairRoot
@export var aim_pointer: Control
@export var pointer_visual_offset: Vector2 = Vector2(30, 50)

var yaw: float = 0.0
var pitch: float = 0.0
var can_fire: bool = true

var is_charging: bool = false
var charge_timer: float = 0.0
var charge_ui: TextureProgressBar = null

# Pointer center in screen coordinates
var aim_screen_target: Vector2 = Vector2.ZERO
var aim_screen_current: Vector2 = Vector2.ZERO
var aim_initialized: bool = false

# Smooth sway state
var sway_velocity: Vector2 = Vector2.ZERO
var last_mouse_delta: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if aim_pointer != null:
		aim_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aim_pointer.visible = false
		_center_pointer_now()

func _process(delta: float) -> void:
	handle_movement(delta)
	update_camera(delta)

	if is_charging:
		if not aim_initialized:
			_center_pointer_now()

		charge_timer += delta

		if charge_ui != null:
			charge_ui.min_value = 0.0
			charge_ui.max_value = 1.0
			charge_ui.value = _get_charge_ratio()
			charge_ui.queue_redraw()

		_apply_charge_sway(delta)

		aim_screen_current = aim_screen_current.lerp(
			aim_screen_target,
			clamp(charge_aim_smooth_speed * delta, 0.0, 1.0)
		)
	else:
		if charge_ui != null:
			charge_ui.value = 0.0

		if aim_initialized:
			var center := _get_screen_center()
			aim_screen_target = aim_screen_target.lerp(
				center,
				clamp(charge_aim_smooth_speed * delta, 0.0, 1.0)
			)
			aim_screen_current = aim_screen_current.lerp(
				center,
				clamp(charge_aim_smooth_speed * delta, 0.0, 1.0)
			)

		sway_velocity = sway_velocity.lerp(Vector2.ZERO, clamp(sway_drag * delta, 0.0, 1.0))

	_update_aim_pointer_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		return

	if get_tree().paused:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion:
		if is_charging:
			if not aim_initialized:
				_center_pointer_now()

			var mouse_delta: Vector2 = Vector2(event.relative.x, event.relative.y)

			# Mouse directly changes shot target
			aim_screen_target += mouse_delta * charge_aim_pixels_per_mouse_unit
			last_mouse_delta = mouse_delta

			# Mouse also injects smooth continuous sway velocity
			sway_velocity += mouse_delta * sway_push_strength

			if sway_velocity.length() > sway_max_speed:
				sway_velocity = sway_velocity.normalized() * sway_max_speed

			_clamp_pointer_to_viewport()

			# Immediate visible response
			aim_screen_current = aim_screen_target
		else:
			# Normal free look when not charging
			yaw -= event.relative.x * look_speed
			pitch -= event.relative.y * look_speed
			_apply_circular_camera_clamp()

	if event.is_action_pressed("shoot"):
		if can_fire:
			is_charging = true
			charge_timer = 0.0
			sway_velocity = Vector2.ZERO
			last_mouse_delta = Vector2.ZERO
			_center_pointer_now()

	if event.is_action_released("shoot"):
		if is_charging:
			var charge_ratio: float = _get_charge_ratio()
			is_charging = false
			fire_with_charge(charge_ratio)

func _apply_charge_sway(delta: float) -> void:
	# Apply continuous 360-degree drift from the current sway velocity
	aim_screen_target += sway_velocity * delta

	# Optional tiny idle continuation in the last direction, if desired
	if sway_idle_strength > 0.0 and last_mouse_delta.length() > 0.001:
		aim_screen_target += last_mouse_delta.normalized() * sway_idle_strength * delta

	_clamp_pointer_to_viewport()

	# Smooth drag, not direction snapping
	sway_velocity = sway_velocity.lerp(Vector2.ZERO, clamp(sway_drag * delta, 0.0, 1.0))

func _get_screen_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5

func _get_pointer_size() -> Vector2:
	if aim_pointer == null:
		return Vector2(64.0, 64.0)

	var s: Vector2 = aim_pointer.size

	if s.x <= 0.0 or s.y <= 0.0:
		s = aim_pointer.get_combined_minimum_size()

	if s.x <= 0.0 or s.y <= 0.0:
		s = Vector2(64.0, 64.0)

	return s

func _center_pointer_now() -> void:
	var center := _get_screen_center()
	aim_screen_target = center
	aim_screen_current = center
	aim_initialized = true

func _clamp_pointer_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var half_size := _get_pointer_size() * 0.5

	aim_screen_target.x = clamp(aim_screen_target.x, half_size.x, viewport_size.x - half_size.x)
	aim_screen_target.y = clamp(aim_screen_target.y, half_size.y, viewport_size.y - half_size.y)

func _apply_circular_camera_clamp() -> void:
	var nx: float = yaw / max_yaw
	var ny: float = pitch / max_pitch
	var mag_sq: float = nx * nx + ny * ny

	if mag_sq > 1.0:
		var mag: float = sqrt(mag_sq)
		nx /= mag
		ny /= mag
		yaw = nx * max_yaw
		pitch = ny * max_pitch

func handle_movement(delta: float) -> void:
	var input_x: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
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
	if camera_yaw != null:
		camera_yaw.rotation_degrees.y = lerp(camera_yaw.rotation_degrees.y, yaw, 10.0 * delta)
	if camera_pitch != null:
		camera_pitch.rotation_degrees.x = lerp(camera_pitch.rotation_degrees.x, pitch, 10.0 * delta)

func fire_with_charge(charge_ratio: float) -> void:
	if not can_fire:
		return
	if projectile_scene == null:
		return
	if camera == null or muzzle == null:
		return

	can_fire = false

	var projectile := projectile_scene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(projectile)
	projectile.global_transform = muzzle.global_transform

	# Projectile uses the exact same screen point the pointer is using
	var dir: Vector3 = camera.project_ray_normal(aim_screen_current).normalized()

	var final_impulse: float = shoot_impulse * lerp(0.5, 1.5, charge_ratio)
	projectile.apply_central_impulse(dir * final_impulse)

	# Reset after firing
	sway_velocity = Vector2.ZERO
	last_mouse_delta = Vector2.ZERO
	_center_pointer_now()

	await get_tree().create_timer(fire_cooldown).timeout
	can_fire = true

func _get_charge_ratio() -> float:
	if charge_time <= 0.0:
		return 1.0

	# One full cycle is:
	# charge up to 100%, then charge back down to 0%
	var full_cycle: float = charge_time * 2.0
	var t: float = fposmod(charge_timer, full_cycle)

	if t <= charge_time:
		# Charging up: 0 -> 1
		return t / charge_time
	else:
		# Charging down: 1 -> 0
		return 1.0 - ((t - charge_time) / charge_time)

func _update_aim_pointer_ui() -> void:
	if aim_pointer == null:
		return

	aim_pointer.visible = is_charging

	if not is_charging:
		return

	var half_size := _get_pointer_size() * 0.5
	aim_pointer.position = aim_screen_current - half_size + pointer_visual_offset

func toggle_pause() -> void:
	var pause_menu = get_tree().current_scene.get_node_or_null("UI/CanvasLayer/PauseMenu")

	if pause_menu == null:
		return

	if get_tree().paused:
		get_tree().paused = false
		pause_menu.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		get_tree().paused = true
		pause_menu.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

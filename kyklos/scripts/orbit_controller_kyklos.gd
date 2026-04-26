#orbit_controller_kyklos.gd

extends Node3D
# Kyklos Orbit Camera + Charge Shot using screen-space crosshair aim + smooth 360 sway

# cockpit
@onready var cockpit_scene = $"CameraYaw/CameraPitch/Cockpit_Scene"

# cockpit lag + drift
@export var orbit_acceleration: float = 1.0
@export var orbit_drag: float = 0.9
@export var max_input_speed: float = 1.2
var orbit_velocity := Vector2.ZERO

# smooth the mouse look + cockpit roll/tilt
@export var mouse_look_smoothness: float = 4.0
@export var drift_tilt_x_amount: float = 10.0
@export var drift_tilt_z_amount: float = 10.0
@export var drift_tilt_smoothness: float = 6.0
var smooth_yaw: float = 0.0
var smooth_pitch: float = 0.0
var cockpit_base_rotation: Vector3 = Vector3.ZERO

@export var orbit_center: Node3D
@export var orbit_speed: float = 2.0

# Camera rig
@export var camera_yaw: Node3D
@export var camera_pitch: Node3D
@export var camera: Camera3D
@export var muzzle: Marker3D
@export var recenter_speed: float = 5.0

# Normal mouse look when NOT charging
@export var look_speed: float = 0.02
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
	
	# cockpits starting rotation
	smooth_yaw = yaw
	smooth_pitch = pitch

	if aim_pointer != null:
		aim_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aim_pointer.visible = false
		_center_pointer_now()

	if cockpit_scene:
		cockpit_base_rotation = cockpit_scene.rotation_degrees
		
# Main loop
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
			
	# Joystick 
	var ws_input = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	var ad_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	cockpit_scene.set_joystick_input(ws_input, ad_input)

	var input_x: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var input_y: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	var is_moving: bool = abs(input_x) > 0.01 or abs(input_y) > 0.01

	if aim_initialized and not is_charging and is_moving:
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
			
			# Joystick movement from mouse
			if cockpit_scene:
				cockpit_scene.add_mouse_roll(-event.relative.x * 0.08)
				cockpit_scene.add_mouse_x(event.relative.y * 0.08)

	if event.is_action_pressed("shoot"):
		if GameManager.game_over:
			return

		if GameManager.ammo <= 0:
			GameManager.game_over = true
			GameManager.emit_signal("game_lost")
			return
			
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

	if event.is_action_pressed("open_canopy") and cockpit_scene:
		cockpit_scene.toggle_canopy()

	if event.is_action_pressed("open_laptop") and cockpit_scene:
		cockpit_scene.toggle_laptop()

	if event.is_action_pressed("open_secondary_screen") and cockpit_scene:
		cockpit_scene.toggle_secondary_screen()

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

	var input_vector: Vector2 = Vector2(input_x, input_y)

	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var target_velocity: Vector2 = input_vector * max_input_speed

	if input_vector.length() > 0.0:
		orbit_velocity = orbit_velocity.move_toward(target_velocity, orbit_acceleration * delta)
	else:
		orbit_velocity = orbit_velocity.move_toward(Vector2.ZERO, orbit_drag * delta)

	var center: Vector3 = orbit_center.global_position

	# Direction from center to player
	var to_center: Vector3 = (global_position - center).normalized()

	var right_axis: Vector3 = Vector3.UP.cross(to_center).normalized()

	# Rotate camera around center using velocity instead of raw input
	rotate_around(center, right_axis, orbit_velocity.y * orbit_speed * delta)
	rotate_around(center, Vector3.UP, -orbit_velocity.x * orbit_speed * delta)

	var new_dir: Vector3 = (global_position - center).normalized()
	var vertical_dot: float = new_dir.dot(Vector3.UP)

	if abs(vertical_dot) > max_vertical:
		var radius: float = (global_position - center).length()
		var clamped_y: float = signf(vertical_dot) * max_vertical
		var horizontal: float = sqrt(1.0 - clamped_y * clamped_y)

		var horiz_dir: Vector3 = Vector3(new_dir.x, 0.0, new_dir.z)
		if horiz_dir.length() > 0.0001:
			horiz_dir = horiz_dir.normalized()
		else:
			horiz_dir = Vector3.FORWARD

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
	# Recalculate movement input
	var input_x: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var input_y: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	# Determine if player is actively moving
	var is_moving: bool = abs(input_x) > 0.01 or abs(input_y) > 0.01

	# Recenter camera when moving (WASD pressed)
	if is_moving:
		yaw = lerp(yaw, 0.0, recenter_speed * delta) as float
		pitch = lerp(pitch, 0.0, recenter_speed * delta) as float

	# Smooth the camera movement so it doesn't snap instantly to mouse input
	# yaw/pitch = target values, smooth_yaw/pitch = actual displayed values
	smooth_yaw = lerp(smooth_yaw, yaw, mouse_look_smoothness * delta) as float
	smooth_pitch = lerp(smooth_pitch, pitch, mouse_look_smoothness * delta) as float

	# Apply smoothed camera movement
	if camera_yaw != null:
		camera_yaw.rotation_degrees.y = lerp(
			camera_yaw.rotation_degrees.y,
			smooth_yaw,
			mouse_look_smoothness * delta
		) as float

	if camera_pitch != null:
		camera_pitch.rotation_degrees.x = lerp(
			camera_pitch.rotation_degrees.x,
			smooth_pitch,
			mouse_look_smoothness * delta
		) as float

	update_cockpit_drift_tilt(delta)
	
func update_cockpit_drift_tilt(delta: float) -> void:
	if cockpit_scene == null:
		return

	# Use orbit velocity to determine how much the ship is drifting
	# This creates a visual "weight" effect for the cockpit


	# Tilt forward/back when moving up/down around the cluster
	var target_tilt_x: float = clamp(
		orbit_velocity.y * drift_tilt_x_amount,
		-drift_tilt_x_amount,
		drift_tilt_x_amount
	)

	# Roll left/right when moving sideways
	var target_tilt_z: float = clamp(
		-orbit_velocity.x * drift_tilt_z_amount,
		-drift_tilt_z_amount,
		drift_tilt_z_amount
	)
	
	# Combine tilt with original cockpit rotation
	var desired_x: float = cockpit_base_rotation.x + target_tilt_x
	var desired_y: float = cockpit_base_rotation.y
	var desired_z: float = cockpit_base_rotation.z + target_tilt_z

	# Smoothly apply tilt so it feels like inertia instead of snapping
	cockpit_scene.rotation_degrees.x = lerp(
		cockpit_scene.rotation_degrees.x,
		desired_x,
		drift_tilt_smoothness * delta
	) as float

	cockpit_scene.rotation_degrees.y = lerp(
		cockpit_scene.rotation_degrees.y,
		desired_y,
		drift_tilt_smoothness * delta
	) as float

	cockpit_scene.rotation_degrees.z = lerp(
		cockpit_scene.rotation_degrees.z,
		desired_z,
		drift_tilt_smoothness * delta
	) as float

func fire_with_charge(charge_ratio: float) -> void:
	if not can_fire:
		return
	if projectile_scene == null:
		return
	if camera == null or muzzle == null:
		return

	can_fire = false
	
	GameManager.ammo -= 1
	GameManager.emit_signal("ammo_changed", GameManager.ammo)

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

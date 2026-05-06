# orbit_controller_kyklos.gd

extends Node3D
# Kyklos Orbit Camera + Charge Shot using screen-space crosshair aim + smooth 360 sway
# Includes projectile type switching for Type 1 Regular, Type 2 Heavy, Type 3 Explosive, and Type 4 Nuclear

@onready var charge_sound: AudioStreamPlayer = $ChargeSound
@onready var shoot_sound: AudioStreamPlayer = $ShootSound
@onready var move_start: AudioStreamPlayer = $TakeoffSound
@onready var move_loop: AudioStreamPlayer = $MovingSound
@onready var move_stop: AudioStreamPlayer = $StoppingSound

var was_moving: bool = false
var move_loop_delay: float = 0.0
var waiting_for_loop: bool = false

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
@export var projectile_spawn_point: Marker3D
@export var spawn_forward_offset: float = 0.35
@export var recenter_speed: float = 5.0

# Nuclear shake
@export var nuclear_shake_strength: float = 1.2
@export var nuclear_shake_duration: float = 4.0
@export var nuclear_shake_speed: float = 35.0
var _nuclear_shake_active: bool = false
var _nuclear_shake_timer: float = 0.0

# Normal mouse look when NOT charging
@export var look_speed: float = 0.02
@export var max_yaw: float = 30.0
@export var max_pitch: float = 18.0
@export var max_vertical: float = 0.9

# Projectile type setup
@export var regular_projectile_scene: PackedScene
@export var heavy_projectile_scene: PackedScene
@export var explosive_projectile_scene: PackedScene
@export var nuclear_projectile_scene: PackedScene

@export var regular_shoot_impulse: float = 25.0
@export var heavy_shoot_impulse: float = 50.0
@export var explosive_shoot_impulse: float = 25.0
@export var nuclear_shoot_impulse: float = 10.0

@export var projectile_type_label: Label

# General firing settings
@export var fire_cooldown: float = 0.12
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

# 1 = Regular, 2 = Heavy, 3 = Explosive, 4 = Nuclear
var selected_projectile_type: int = 1

# Pointer center in screen coordinates
var aim_screen_target: Vector2 = Vector2.ZERO
var aim_screen_current: Vector2 = Vector2.ZERO
var aim_initialized: bool = false

# Smooth sway state
var sway_velocity: Vector2 = Vector2.ZERO
var last_mouse_delta: Vector2 = Vector2.ZERO

var seek_timer: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# cockpit starting rotation
	smooth_yaw = yaw
	smooth_pitch = pitch

	if aim_pointer != null:
		aim_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aim_pointer.visible = true
		_center_pointer_now()

	if cockpit_scene:
		cockpit_base_rotation = cockpit_scene.rotation_degrees

	if GameManager != null and not GameManager.is_connected("nuclear_detonated", Callable(self, "_on_nuclear_detonated")):
		GameManager.connect("nuclear_detonated", Callable(self, "_on_nuclear_detonated"))

	_update_projectile_type_ui()

# Main loop
func _process(delta: float) -> void:
	handle_movement(delta)
	update_camera(delta)

	if is_charging:
		if not aim_initialized:
			_center_pointer_now()

		charge_timer += delta
		
		if is_charging and charge_sound.playing and charge_sound.stream:
			seek_timer += delta

			if seek_timer > 0.03:
				seek_timer = 0.0
				
				var ratio := _get_charge_ratio()
				var length := charge_sound.stream.get_length()
				
				var target := ratio * length
				var current := charge_sound.get_playback_position()
				
				charge_sound.seek(lerp(current, target, 0.1))

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

		var center := _get_screen_center()
		aim_screen_target = center
		aim_screen_current = center

		sway_velocity = Vector2.ZERO
		last_mouse_delta = Vector2.ZERO

	# Joystick
	var ws_input: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	var ad_input: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	if cockpit_scene:
		cockpit_scene.set_joystick_input(ws_input, ad_input)

	_update_aim_pointer_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		return

	if get_tree().paused:
		return

	if event.is_action_pressed("next_projectile_type"):
		_cycle_projectile_type()

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

		# Nuclear uses its own one-per-round ammo
		if selected_projectile_type == 4:
			if GameManager.nuclear_ammo <= 0:
				return
		else:
			if GameManager.ammo <= 0:
				GameManager.game_over = true
				GameManager.emit_signal("game_lost")
				return

		if can_fire:
			is_charging = true
			charge_timer = 0.0
			charge_sound.play()
			sway_velocity = Vector2.ZERO
			last_mouse_delta = Vector2.ZERO
			_center_pointer_now()

	if event.is_action_released("shoot"):
		if is_charging:
			charge_sound.stop()
			var charge_ratio: float = _get_charge_ratio()
			is_charging = false
			fire_with_charge(charge_ratio)
			shoot_sound.play()

	if event.is_action_pressed("open_canopy") and cockpit_scene:
		cockpit_scene.toggle_canopy()

	if event.is_action_pressed("open_laptop") and cockpit_scene:
		cockpit_scene.toggle_laptop()

	if event.is_action_pressed("open_secondary_screen") and cockpit_scene:
		cockpit_scene.toggle_secondary_screen()

func _on_nuclear_detonated(_world_position: Vector3) -> void:
	_nuclear_shake_active = true
	_nuclear_shake_timer = 0.0

func _cycle_projectile_type() -> void:
	selected_projectile_type += 1
	if selected_projectile_type > 4:
		selected_projectile_type = 1
	_update_projectile_type_ui()

func _update_projectile_type_ui() -> void:
	if projectile_type_label == null:
		return

	if selected_projectile_type == 1:
		projectile_type_label.text = "Kyklon Type: Regular"
	elif selected_projectile_type == 2:
		projectile_type_label.text = "Kyklon Type: Heavy"
	elif selected_projectile_type == 3:
		projectile_type_label.text = "Kyklon Type: Explosive"
	elif selected_projectile_type == 4:
		projectile_type_label.text = "Kyklon Type: Nuclear"

func _get_selected_projectile_scene() -> PackedScene:
	if selected_projectile_type == 2:
		return heavy_projectile_scene
	elif selected_projectile_type == 3:
		return explosive_projectile_scene
	elif selected_projectile_type == 4:
		return nuclear_projectile_scene
	return regular_projectile_scene

func _get_selected_base_impulse() -> float:
	if selected_projectile_type == 2:
		return heavy_shoot_impulse
	elif selected_projectile_type == 3:
		return explosive_shoot_impulse
	elif selected_projectile_type == 4:
		return nuclear_shoot_impulse
	return regular_shoot_impulse

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
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var half_size: Vector2 = _get_pointer_size() * 0.5

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
	
	var is_moving: bool = abs(input_x) > 0.01 or abs(input_y) > 0.01
	
# ===== MOVEMENT AUDIO SYSTEM WITH DELAY =====

	# Movement STARTED
	if is_moving and not was_moving:
		move_start.play()
		move_loop.stop() # ensures clean restart
		move_loop_delay = 0.12   # <-- tweak this (0.08–0.2 feels good)
		waiting_for_loop = true

	# Handle delayed loop start
	if waiting_for_loop:
		move_loop_delay -= delta
		if move_loop_delay <= 0.0:
			if is_moving and not move_loop.playing:
				move_loop.play()
			waiting_for_loop = false

	# Movement STOPPED
	elif not is_moving and was_moving:
		move_loop.stop()
		move_stop.play()
		waiting_for_loop = false

	# Safety: keep loop alive if somehow stopped
	if is_moving and not move_loop.playing and not waiting_for_loop:
		move_loop.play()

	was_moving = is_moving

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
	smooth_yaw = lerp(smooth_yaw, yaw, mouse_look_smoothness * delta) as float
	smooth_pitch = lerp(smooth_pitch, pitch, mouse_look_smoothness * delta) as float

	var shake_yaw: float = 0.0
	var shake_pitch: float = 0.0

	if _nuclear_shake_active:
		_nuclear_shake_timer += delta
		var t: float = clamp(_nuclear_shake_timer / nuclear_shake_duration, 0.0, 1.0)
		var falloff: float = 1.0 - t
		var time_value: float = Time.get_ticks_msec() * 0.001

		shake_yaw = sin(time_value * nuclear_shake_speed * 0.91) * nuclear_shake_strength * falloff
		shake_pitch = cos(time_value * nuclear_shake_speed * 1.13) * nuclear_shake_strength * falloff

		if _nuclear_shake_timer >= nuclear_shake_duration:
			_nuclear_shake_active = false

	# Apply smoothed camera movement + shake without accumulating forever
	if camera_yaw != null:
		camera_yaw.rotation_degrees.y = lerp(
			camera_yaw.rotation_degrees.y,
			smooth_yaw + shake_yaw,
			mouse_look_smoothness * delta
		) as float

	if camera_pitch != null:
		camera_pitch.rotation_degrees.x = lerp(
			camera_pitch.rotation_degrees.x,
			smooth_pitch + shake_pitch,
			mouse_look_smoothness * delta
		) as float

	update_cockpit_drift_tilt(delta)

func update_cockpit_drift_tilt(delta: float) -> void:
	if cockpit_scene == null:
		return

	var target_tilt_x: float = clamp(
		orbit_velocity.y * drift_tilt_x_amount,
		-drift_tilt_x_amount,
		drift_tilt_x_amount
	)

	var target_tilt_z: float = clamp(
		-orbit_velocity.x * drift_tilt_z_amount,
		-drift_tilt_z_amount,
		drift_tilt_z_amount
	)

	var desired_x: float = cockpit_base_rotation.x + target_tilt_x
	var desired_y: float = cockpit_base_rotation.y
	var desired_z: float = cockpit_base_rotation.z + target_tilt_z

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
	if camera == null or projectile_spawn_point == null:
		return

	var selected_scene: PackedScene = _get_selected_projectile_scene()
	if selected_scene == null:
		can_fire = true
		return

	can_fire = false

	if selected_projectile_type == 4:
		GameManager.nuclear_ammo -= 1
		GameManager.emit_signal("nuclear_ammo_changed", GameManager.nuclear_ammo)
	else:
		GameManager.ammo -= 1
		GameManager.emit_signal("ammo_changed", GameManager.ammo)

	var projectile: Node = selected_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	var dir: Vector3 = camera.project_ray_normal(aim_screen_current).normalized()
	var spawn_pos: Vector3 = projectile_spawn_point.global_position + dir * spawn_forward_offset

	if projectile is Node3D:
		var projectile_node := projectile as Node3D
		projectile_node.global_position = spawn_pos
		projectile_node.look_at(spawn_pos + dir, Vector3.UP)

	var base_impulse: float = _get_selected_base_impulse()
	var final_impulse: float = base_impulse * lerp(0.5, 1.5, charge_ratio)

	if projectile.has_method("launch"):
		projectile.call("launch", dir, final_impulse)
	elif projectile is RigidBody3D:
		(projectile as RigidBody3D).apply_central_impulse(dir * final_impulse)

	sway_velocity = Vector2.ZERO
	last_mouse_delta = Vector2.ZERO
	_center_pointer_now()

	await get_tree().create_timer(fire_cooldown).timeout
	can_fire = true

func _get_charge_ratio() -> float:
	if charge_time <= 0.0:
		return 1.0

	var full_cycle: float = charge_time * 2.0
	var t: float = fposmod(charge_timer, full_cycle)

	if t <= charge_time:
		return t / charge_time
	else:
		return 1.0 - ((t - charge_time) / charge_time)

func _update_aim_pointer_ui() -> void:
	if aim_pointer == null:
		return

	aim_pointer.visible = true

	var half_size: Vector2 = _get_pointer_size() * 0.5
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

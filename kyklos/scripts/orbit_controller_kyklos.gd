extends Node3D
# Kyklos Orbit Camera + Constrained Look + Shooting (Godot 4.x)

# cockpit
@onready var cockpit_scene = $"CameraYaw/CameraPitch/Cockpit_Scene"

# cockpit lag + drift
@export var orbit_acceleration: float = 1.0
@export var orbit_drag: float = 0.9
@export var max_input_speed: float = 1.2
var orbit_velocity := Vector2.ZERO

# smooth the mouse look + cockpit roll/tilt
@export var mouse_look_smoothness: float = 6.0
@export var drift_tilt_x_amount: float = 6.0
@export var drift_tilt_z_amount: float = 6.0
@export var drift_tilt_smoothness: float = 6.0
var smooth_yaw: float = 0.0
var smooth_pitch: float = 0.0
var cockpit_base_rotation: Vector3 = Vector3.ZERO

@export var orbit_center: Node3D
@export var orbit_speed: float = 2.0

# Camera rig nodes
@export var camera_yaw: Node3D
@export var camera_pitch: Node3D
@export var camera: Camera3D
@export var muzzle: Marker3D

# Mouse look (constrained so you can't look away from the cluster)
@export var look_speed: float = 0.08
@export var recenter_speed: float = 4.0
@export var max_yaw: float = 30.0
@export var max_pitch: float = 18.0
@export var max_vertical: float = 0.9
@export var recenter_delay: float = 0.4

# Shooting
@export var shoot_impulse: float = 25.0
@export var fire_cooldown: float = 0.12
@export var projectile_scene: PackedScene
@export var charge_time: float = 0.6

var time_since_mouse: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0
var can_fire: bool = true
var is_charging: bool = false
var charge_timer: float = 0.0
var charge_ui: TextureProgressBar

# Captures mouse for FPS camera control
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# cockpits starting rotation
	smooth_yaw = yaw
	smooth_pitch = pitch

	if cockpit_scene:
		cockpit_base_rotation = cockpit_scene.rotation_degrees
		
# Main loop
func _process(delta: float) -> void:
	handle_movement(delta) #Orbit movement (WASD)
	update_camera(delta) # Camera Rotation & Recenter
	
	if is_charging:
		charge_timer += delta

		if charge_timer >= charge_time:
			fire()
			is_charging = false
			charge_timer = 0.0

	if charge_ui != null:
		if is_charging:
			charge_ui.value = clamp(charge_timer / charge_time, 0.0, 1.0)
		else:
			charge_ui.value = 0.0
			
	# Joystick 
	var ws_input = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	var ad_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	cockpit_scene.set_joystick_input(ws_input, ad_input)

	#Input Handling
func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	# Mouse input => move camera
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * look_speed
		pitch -= event.relative.y * look_speed

		var max_radius: float = max_yaw
		var length: float = sqrt(yaw * yaw + pitch * pitch)

		if length > max_radius:
			var scale: float = max_radius / length
			yaw *= scale
			pitch *= scale

		time_since_mouse = 0.0

		if cockpit_scene:
			cockpit_scene.add_mouse_roll((-event.relative.x - event.relative.y) * 0.18)
	
		# Joystick
		cockpit_scene.add_mouse_roll((-event.relative.x - event.relative.y) * 0.18)
	
	# Fire input
	if event.is_action_pressed("shoot"):
		is_charging = true
		charge_timer = 0.0

	if event.is_action_released("shoot"):
		is_charging = false
		charge_timer = 0.0
	
	#Release mouse from being captured (pseudo pause button)
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		
	# cockpit input
	if event.is_action_pressed("open_canopy") and cockpit_scene:
		cockpit_scene.toggle_canopy()

	if event.is_action_pressed("open_laptop") and cockpit_scene:
		cockpit_scene.toggle_laptop()

	if event.is_action_pressed("open_secondary_screen") and cockpit_scene:
		cockpit_scene.toggle_secondary_screen()

func handle_movement(delta: float) -> void:
	# WASD orbit using ui_left/ui_right/ui_up/ui_down
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

	# Clamp vertical orbit so you can't go over the poles
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

	# Always face the center
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

func fire() -> void:
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

	# Center of screen direction = camera forward
	var dir: Vector3 = -camera.global_transform.basis.z.normalized()
	projectile.apply_central_impulse(dir * shoot_impulse)

	await get_tree().create_timer(fire_cooldown).timeout
	can_fire = true

func toggle_pause():
	var pause_menu = get_tree().current_scene.get_node("UI/CanvasLayer/PauseMenu")
	
	if pause_menu == null:
		print("PauseMenu NOT FOUND")
		return

	if get_tree().paused:
		# Resume
		get_tree().paused = false
		pause_menu.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		# Pause
		get_tree().paused = true
		pause_menu.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

extends Node3D
# Kyklos Orbit Camera + Constrained Look + Shooting (Godot 4.x)

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

#Input Handling
func _input(event: InputEvent) -> void:
	# Mouse input => move camera
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * look_speed
		pitch -= event.relative.y * look_speed

		# circular clamp
		var max_radius: float = max_yaw  # look radius

		var length: float = sqrt(yaw * yaw + pitch * pitch)

		if length > max_radius:
			var scale: float = max_radius / length
			yaw *= scale
			pitch *= scale

		time_since_mouse = 0.0
	
	# Fire input
	if event.is_action_pressed("shoot"):
		is_charging = true
		charge_timer = 0.0

	if event.is_action_released("shoot"):
		is_charging = false
		charge_timer = 0.0
	
	#Release mouse from being captured (pseudo pause button)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func handle_movement(delta: float) -> void:
	# WASD orbit using ui_left/ui_right/ui_up/ui_down
	var input_x: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var input_y: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	if orbit_center == null:
		return

	var center: Vector3 = orbit_center.global_position
	
	#Direction from center to player
	var to_center: Vector3 = (global_position - center).normalized()
	
	var right_axis: Vector3 = Vector3.UP.cross(to_center).normalized()
	
	#Rotate camera around center
	rotate_around(center, right_axis, input_y * orbit_speed * delta)
	rotate_around(center, Vector3.UP, -input_x * orbit_speed * delta)

	# Clamp vertical orbit so you can't go over the poles
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

	# Always face the center
	look_at(center, Vector3.UP)

func rotate_around(center: Vector3, axis: Vector3, angle: float) -> void:
	var offset: Vector3 = global_position - center
	offset = offset.rotated(axis, angle)
	global_position = center + offset

func update_camera(delta: float) -> void:
	#Recalculate movement input
	var input_x: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var input_y: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	#Determine if player is actively moving
	var is_moving: bool = abs(input_x) > 0.01 or abs(input_y) > 0.01
	
	#Recenter camer when moving (WASD pressed)
	if is_moving:
		yaw = lerp(yaw, 0.0, recenter_speed * delta)
		pitch = lerp(pitch, 0.0, recenter_speed * delta)
	
	#Smooth application of camera movements
	if camera_yaw != null:
		camera_yaw.rotation_degrees.y = lerp(camera_yaw.rotation_degrees.y, yaw, 10.0 * delta)
	if camera_pitch != null:
		camera_pitch.rotation_degrees.x = lerp(camera_pitch.rotation_degrees.x, pitch, 10.0 * delta)

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

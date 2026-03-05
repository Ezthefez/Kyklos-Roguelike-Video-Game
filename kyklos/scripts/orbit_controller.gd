extends Node3D

@export var orbit_center : Node3D
@export var orbit_speed := 2.0

@export var camera_yaw : Node3D
@export var camera_pitch : Node3D

@export var look_speed := 0.08
@export var recenter_speed := 4.0

@export var max_yaw := 30.0
@export var max_pitch := 18.0
@export var max_vertical := 0.9

@export var recenter_delay := 0.4
var time_since_mouse := 0.0

var yaw := 0.0
var pitch := 0.0
var mouse_moving := false

func _process(delta):
	handle_movement(delta)
	update_camera(delta)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		
		mouse_moving = true
		
		yaw -= event.relative.x * look_speed
		pitch -= event.relative.y * look_speed
		
		yaw = clamp(yaw, -max_yaw, max_yaw)
		pitch = clamp(pitch, -max_pitch, max_pitch)
		
		time_since_mouse = 0.0
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func handle_movement(delta):

	var input_x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var input_y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	var center = orbit_center.global_position
	var to_center = (global_position - center).normalized()
	
	var right_axis = Vector3.UP.cross(to_center).normalized()
	
	# Apply movement
	rotate_around(center, right_axis, input_y * orbit_speed * delta)
	rotate_around(center, Vector3.UP, -input_x * orbit_speed * delta)
	
	# Clamp vertical orbit
	var new_dir = (global_position - center).normalized()
	var vertical_dot = new_dir.dot(Vector3.UP)
	
	if abs(vertical_dot) > max_vertical:
		var radius = (global_position - center).length()
		
		var clamped_y = sign(vertical_dot) * max_vertical
		var horizontal = sqrt(1.0 - clamped_y * clamped_y)
		
		var horiz_dir = Vector3(new_dir.x, 0, new_dir.z).normalized()
		
		var clamped_dir = Vector3(
			horiz_dir.x * horizontal,
			clamped_y,
			horiz_dir.z * horizontal
			)
		
		global_position = center + clamped_dir * radius
		
	look_at(center, Vector3.UP)

func rotate_around(center:Vector3, axis:Vector3, angle:float):

	var offset = global_position - center
	offset = offset.rotated(axis, angle)

	global_position = center + offset

func update_camera(delta):
	
	time_since_mouse += delta
	
	if time_since_mouse > recenter_delay:
		
		yaw = lerp(yaw, 0.0, recenter_speed * delta)
		pitch = lerp(pitch, 0.0, recenter_speed * delta)
		
	camera_yaw.rotation_degrees.y = lerp(camera_yaw.rotation_degrees.y, yaw, 10 * delta)
	camera_pitch.rotation_degrees.x = lerp(camera_pitch.rotation_degrees.x, pitch, 10 * delta)
		
	mouse_moving = false

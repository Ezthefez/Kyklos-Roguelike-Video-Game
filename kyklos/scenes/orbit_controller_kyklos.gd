extends Node3D

@onready var pause_button = $"../CanvasLayer/PauseButton"
@onready var pause_panel = $"../CanvasLayer/PausePanel"

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

var time_since_mouse: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0
var can_fire: bool = true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	handle_movement(delta)
	update_camera(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * look_speed
		pitch -= event.relative.y * look_speed

		yaw = clamp(yaw, -max_yaw, max_yaw)
		pitch = clamp(pitch, -max_pitch, max_pitch)

		time_since_mouse = 0.0

	if event.is_action_pressed("shoot"):
		fire()

	if event.is_action_pressed("ui_cancel"):
		if pause_panel.visible:
			# CLOSE pause menu
			pause_panel.visible = false
			pause_button.visible = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			# OPEN pause menu
			pause_panel.visible = true
			pause_button.visible = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			

func handle_movement(delta: float) -> void:
	# WASD orbit using ui_left/ui_right/ui_up/ui_down
	var input_x: float = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var input_y: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	if orbit_center == null:
		return

	var center: Vector3 = orbit_center.global_position
	var to_center: Vector3 = (global_position - center).normalized()

	var right_axis: Vector3 = Vector3.UP.cross(to_center).normalized()

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
	time_since_mouse += delta

	if time_since_mouse > recenter_delay:
		yaw = lerp(yaw, 0.0, recenter_speed * delta)
		pitch = lerp(pitch, 0.0, recenter_speed * delta)

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


func _on_pause_button_pressed() -> void:
	pause_panel.visible = true
	pause_button.visible = false

func _on_resume_button_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pause_panel.visible = false
	pause_button.visible = true

func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
func _on_maintenance_bay_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/maintenance_bay.tscn")

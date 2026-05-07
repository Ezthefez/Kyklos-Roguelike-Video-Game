extends Node3D

@export var player_camera: Camera3D
@export var laptop_zoom_point: Marker3D
@export var cockpit_scene: Node
@export var pause_menu: Control

@export var zoom_time: float = 2.0
@export var laptop_anim_wait: float = 1.0

var laptop_busy: bool = false
var laptop_zoomed: bool = false
var original_camera_transform: Transform3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_laptop"):
		if laptop_busy:
			return

		if laptop_zoomed:
			return

		await zoom_into_laptop(true)


func zoom_into_laptop(show_pause: bool = true) -> void:
	if laptop_busy:
		return
	if player_camera == null or laptop_zoom_point == null or cockpit_scene == null:
		return

	laptop_busy = true

	get_tree().paused = true

	original_camera_transform = player_camera.global_transform

	if cockpit_scene.has_method("toggle_laptop"):
		cockpit_scene.toggle_laptop()

	await get_tree().create_timer(laptop_anim_wait, true).timeout

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		player_camera,
		"global_transform",
		laptop_zoom_point.global_transform,
		zoom_time
	)

	await tween.finished

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if show_pause and pause_menu:
		pause_menu.visible = true

	laptop_zoomed = true
	laptop_busy = false


func zoom_out_of_laptop() -> void:
	if laptop_busy:
		return
	if player_camera == null or cockpit_scene == null:
		return

	laptop_busy = true

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if pause_menu:
		pause_menu.visible = false

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		player_camera,
		"global_transform",
		original_camera_transform,
		zoom_time
	)

	await tween.finished

	if cockpit_scene.has_method("toggle_laptop"):
		cockpit_scene.toggle_laptop()

	await get_tree().create_timer(laptop_anim_wait, true).timeout

	laptop_zoomed = false
	get_tree().paused = false
	laptop_busy = false

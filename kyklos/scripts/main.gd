extends Node

@onready var orbit_controller = $player
@onready var charge_circle = $UI/CanvasLayer/CenterContainer/CrosshairRoot/ChargeCircle

@onready var pause_menu = $UI/PauseMenu
@onready var resume_button = $UI/PauseMenu/CenterContainer/VBoxContainer/ResumeButton
@onready var quit_button = $UI/PauseMenu/CenterContainer/VBoxContainer/QuitButton

var is_paused_menu_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Charge wheel hookup
	if orbit_controller != null:
		orbit_controller.charge_circle = charge_circle

	if charge_circle != null:
		charge_circle.min_value = 0.0
		charge_circle.max_value = 1.0
		charge_circle.value = 0.0
		charge_circle.step = 0.001

	# Pause menu setup
	if pause_menu != null:
		pause_menu.visible = false
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	if resume_button != null and not resume_button.pressed.is_connected(_on_resume_button_pressed):
		resume_button.pressed.connect(_on_resume_button_pressed)

	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause_menu()

func toggle_pause_menu() -> void:
	is_paused_menu_open = not is_paused_menu_open

	if pause_menu != null:
		pause_menu.visible = is_paused_menu_open

	var tree := get_tree()
	if tree != null:
		tree.paused = is_paused_menu_open

	if is_paused_menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if resume_button != null:
			resume_button.grab_focus()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_button_pressed() -> void:
	if is_paused_menu_open:
		toggle_pause_menu()

func _go_to_main_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return

	tree.change_scene_to_file("res://scenes/main_menu.tscn")
	
func _on_quit_button_pressed() -> void:
	is_paused_menu_open = false

	var tree := get_tree()
	if tree == null:
		return

	tree.paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	call_deferred("_go_to_main_menu")

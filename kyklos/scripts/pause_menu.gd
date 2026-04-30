extends Control

@onready var resume_button = $CenterContainer/VBoxContainer/ResumeButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed():
	print("resume clicked")
	get_tree().paused = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_quit_pressed():
	get_tree().paused = false
	GameManager.reset_all()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

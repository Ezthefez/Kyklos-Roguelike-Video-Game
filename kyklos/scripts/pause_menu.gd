extends Control


func _ready():
	visible = false

func _on_resume_button_pressed() -> void:
	var laptop = get_tree().get_first_node_in_group("cockpit_laptop")
	if laptop:
		await laptop.zoom_out_of_laptop()

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

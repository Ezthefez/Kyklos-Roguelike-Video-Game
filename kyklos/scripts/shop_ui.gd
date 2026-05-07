extends Control

func _ready() -> void:
	if GameManager.open_shop_window_on_load:
		show_shop_window()
		GameManager.open_shop_window_on_load = false
	else:
		show_pause_window()

func show_pause_window() -> void:
	$PauseWindow.visible = true
	$ShopWindow.visible = false

func show_shop_window() -> void:
	$PauseWindow.visible = false
	$ShopWindow.visible = true


func _on_next_round_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

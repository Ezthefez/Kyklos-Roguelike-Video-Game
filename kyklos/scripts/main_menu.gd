extends Control

@onready var main_menu = $MainMenuButtons
@onready var settings_panel = $SettingsPanel
@onready var button_sound: AudioStreamPlayer = $ButtonSound

func _on_start_pressed() -> void:
	button_sound.play()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	button_sound.play()
	settings_panel.visible = true
	main_menu.visible = false

func _on_back_pressed() -> void:
	button_sound.play()
	settings_panel.visible = false
	main_menu.visible = true

func _on_quit_pressed() -> void:
	button_sound.play()
	get_tree().quit()

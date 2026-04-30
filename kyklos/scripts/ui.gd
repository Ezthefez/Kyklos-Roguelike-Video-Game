extends Node

@onready var ammo_label: Label = $CanvasLayer/AmmoLabel
@onready var report_menu: Control = $CanvasLayer/ReportMenu
@onready var lose_menu: Control = $CanvasLayer/LoseScreen
@onready var collected_label: Label = $CanvasLayer/ReportMenu/Panel/StatsContainer/CollectedLabel
@onready var bonus_label: Label = $CanvasLayer/ReportMenu/Panel/StatsContainer/BonusLabel
@onready var total_money_label: Label = $CanvasLayer/ReportMenu/Panel/StatsContainer/TotalMoneyLabel

func _ready() -> void:
	report_menu.visible = false
	lose_menu.visible = false

	_update_ammo(GameManager.ammo)

	GameManager.connect("ammo_changed", _on_ammo_changed)
	GameManager.connect("game_won", _on_game_won)
	GameManager.connect("game_lost", _on_game_lost)

func _on_ammo_changed(value: int) -> void:
	_update_ammo(value)

func _update_ammo(value: int) -> void:
	ammo_label.text = "Ammo: " + str(value)

func _on_game_won() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	report_menu.visible = true

	var collected: int = GameManager.ammo - 5
	var reward: int = GameManager.calculate_reward()

	GameManager.add_money(reward)

	collected_label.text = "Kyklons Collected: " + str(collected)
	bonus_label.text = "Reward: $" + str(reward)
	total_money_label.text = "Total Money: $" + str(GameManager.money)

func _on_game_lost() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	lose_menu.visible = true

func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/Shop.tscn")


func _on_new_run_button_pressed() -> void:
	GameManager.reset_all()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit_to_main_menu_button_pressed() -> void:
	GameManager.reset_all()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

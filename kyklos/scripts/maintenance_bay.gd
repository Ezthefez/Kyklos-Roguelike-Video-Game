extends Control

var kyklon_total: int = 1000

@onready var blur_overlay = $BlurOverlay
@onready var back_button = $BackButton
@onready var store_panel = $StorePanel
@onready var play_mainmenu = $Play_MainMenuButtons
@onready var store_gearup = $Store_GearUpButtons
@onready var gearup_back_button = $GearUpBackButton
@onready var gear_up_panel = $GearUpPanel
@onready var kyklon_label = $KyklonLabel

func _ready() -> void:
	update_kyklon_label()

func _on_play_pressed() -> void:
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_main_menu_pressed() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func update_kyklon_label() -> void:
	kyklon_label.text = "Kyklons: " + str(kyklon_total)


func _on_store_pressed() -> void:
	blur_overlay.visible = true
	back_button.visible = true
	store_panel.visible = true

func _on_back_pressed() -> void:
	blur_overlay.visible = false
	back_button.visible = false
	store_panel.visible = false


func _on_gear_up_pressed() -> void:
	play_mainmenu.visible = false
	store_gearup.visible = false
	gearup_back_button.visible = true
	gear_up_panel.visible = true

func _on_gear_up_back_button_pressed() -> void:
	gearup_back_button.visible = false
	play_mainmenu.visible = true
	store_gearup.visible = true
	gear_up_panel.visible = false


func buy_upgrade(cost: int) -> void:
	if kyklon_total >= cost:
		kyklon_total -= cost
		update_kyklon_label()


func _on_buy_button_pressed() -> void:
	buy_upgrade(50)

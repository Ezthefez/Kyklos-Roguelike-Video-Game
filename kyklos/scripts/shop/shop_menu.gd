extends Control

@export var item_pool: Array[ShopItem]
@export var ammo_pool: Array[AmmoItem]
@export var item_scene: PackedScene
@export var ammo_scene: PackedScene
@export var shop_item_container: HBoxContainer
@export var shop_ammo_container: HBoxContainer

@export var items_to_show: int = 2
@export var ammos_to_show: int = 2

@onready var current_money_label: Label = $CanvasLayer/Money/Amount
@onready var button_sound: AudioStreamPlayer = $ButtonSound

func _ready() -> void:
	print("SHOP READY")
	
	_update_money(GameManager.money) # set initial value

	if not GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.connect(_on_money_changed)
		print("Connected to GameManager signal")
		
	generate_shop_items()
	generate_shop_ammo()

func _on_next_round_button_pressed() -> void:
	button_sound.play()
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func generate_shop_items():
	# Clear old items
	for child in shop_item_container.get_children():
		child.queue_free()

	# Shuffle pool
	var pool = item_pool.duplicate()
	pool.shuffle()

	# Pick random items
	for i in range(min(items_to_show, pool.size())):
		var item_data = pool[i]

		var ui = item_scene.instantiate()
		shop_item_container.add_child(ui)
		ui.setup(item_data)
		
func generate_shop_ammo():
	# Clear old items
	for child in shop_ammo_container.get_children():
		child.queue_free()

	# Shuffle pool
	var pool = ammo_pool.duplicate()
	pool.shuffle()

	# Pick random items
	for i in range(min(ammos_to_show, pool.size())):
		var item_data = pool[i]

		var ui = ammo_scene.instantiate()
		shop_ammo_container.add_child(ui)
		ui.setup(item_data)
		
func _on_money_changed(new_amount: int) -> void:
	print("SHOP RECEIVED:", new_amount)
	_update_money(new_amount)

func _update_money(value: int) -> void:
	current_money_label.text = "$ " + str(value)

extends Control

@export var item_pool: Array[ShopItem]
@export var item_scene: PackedScene
@export var shop_container: HBoxContainer

@export var items_to_show: int = 2

@onready var current_money_label: Label = $CanvasLayer/Money/Amount

func _ready() -> void:
	_update_money(GameManager.money) # set initial value

	GameManager.connect("money_changed", _on_money_changed)
	generate_shop()

func _on_next_round_button_pressed() -> void:
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func generate_shop():
	# Clear old items
	for child in shop_container.get_children():
		child.queue_free()

	# Shuffle pool
	var pool = item_pool.duplicate()
	pool.shuffle()

	# Pick random items
	for i in range(min(items_to_show, pool.size())):
		var item_data = pool[i]

		var ui = item_scene.instantiate()
		shop_container.add_child(ui)
		ui.setup(item_data)
		
func _on_money_changed(new_amount: int) -> void:
	_update_money(new_amount)

func _update_money(value: int) -> void:
	current_money_label.text = "$ " + str(value)

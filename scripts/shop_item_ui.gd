extends Control

@onready var name_label = $Panel/Name
@onready var icon = $Panel/Icon
@onready var price_label = $Panel/Price
@onready var description_label = $Panel/Description
@onready var buy_button = $Panel/Buy

var item: ShopItem
var purchased := false

func setup(data: ShopItem) -> void:
	item = data
	name_label.text = item.name
	price_label.text = "$" + str(item.price)
	icon.texture = item.icon
	description_label.text = item.description
	
	buy_button.pressed.connect(_on_buy_pressed)

func _on_buy_pressed() -> void:
	if purchased:
		return
		
	if GameManager.money < item.price:
		print("Not enough money")
		return

	# Deduct money
	GameManager.money -= item.price
	GameManager.emit_signal("money_changed", GameManager.money)
	
	# Mark as purchased
	purchased = true
	
	# Disable button
	buy_button.disabled = true
	buy_button.text = "Purchased"
		#_apply_effect()
		#queue_free() # remove after purchase

func _apply_effect():
	match item.effect_type:
		"ammo":
			GameManager.ammo += int(item.effect_value)
		"damage":
			GameManager.player_damage += item.effect_value

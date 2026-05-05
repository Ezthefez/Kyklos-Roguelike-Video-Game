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
	GameManager.add_money(-item.price)
	#GameManager.money -= item.price
	#GameManager.emit_signal("money_changed", GameManager.money)
	
	GameManager.apply_upgrade(item)
	
	# Mark as purchased
	purchased = true
	
	# Disable button
	buy_button.disabled = true
	buy_button.text = "Purchased"

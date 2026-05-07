extends Control

@onready var name_label = $Panel/Name
@onready var icon = $Panel/Icon
@onready var price_label = $Panel/Price
@onready var buy_button = $Panel/Buy
@onready var button_sound: AudioStreamPlayer = $ButtonSound

var item: AmmoItem
var purchased := false

func setup(data: AmmoItem) -> void:
	item = data
	name_label.text = item.name
	price_label.text = "$" + str(item.price)
	icon.texture = item.icon
	
	buy_button.pressed.connect(_on_buy_pressed)

func _on_buy_pressed() -> void:
	button_sound.play()
	if purchased:
		return
		
	if GameManager.money < item.price:
		print("Not enough money")
		return

	# Deduct money
	GameManager.add_money(-item.price)
	#GameManager.money -= item.price
	#GameManager.emit_signal("money_changed", GameManager.money)
	
	GameManager.apply_ammo(item)
	

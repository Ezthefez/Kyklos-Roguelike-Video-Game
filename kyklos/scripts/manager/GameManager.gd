extends Node

var selected_seed: int = 0
var ammo: int = 5
var base_ammo: int = 5
var targets_remaining: int = 0
var game_over := false
var money: int = 0
var targets_collected: int = 0

signal ammo_changed(new_ammo)
signal game_won
signal game_lost
signal money_changed(new_amount)

func add_money(amount: int) -> void:
	money += amount
	emit_signal("money_changed", money)

func calculate_reward() -> int:
	var extra : int = max(0, ammo - 5)
	return extra * 50

func reset_run():
	ammo = base_ammo
	targets_collected = 0
	game_over = false
	
func reset_all():
	ammo = 5
	targets_remaining = 0
	targets_collected = 0
	money = 0
	game_over = false

func apply_upgrade(item: ShopItem) -> void:
	match item.effect_type:
		"ammo":
			var amount := int(item.effect_value)
			
			# future runs
			base_ammo += amount

			# current run (THIS is what you're missing)
			ammo += amount
			emit_signal("ammo_changed", ammo)
			
			print("Bought ammo upgrade:", item.effect_value)
			print("Ammo now:", ammo)
			print("Base ammo now:", base_ammo)

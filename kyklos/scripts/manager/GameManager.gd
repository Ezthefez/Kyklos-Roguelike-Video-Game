extends Node

var player_level: int = 1
var selected_seed: int = 0
var normal_ammo: int = 5
var base_normal_ammo: int = 5
var charge_speed_multiplier: float = 1.0
var charge_power_multiplier: float = 1.0
var heavy_ammo: int = 0
var explosive_ammo: int = 0
var nuclear_ammo: int = 1
var targets_remaining: int = 0
var game_over := false
var money: int = 0
var targets_collected: int = 0
var _nuclear_win_scheduled: bool = false
var current_projectile_type_name: String = "Regular"

var barrier_enabled: bool = false
var ring_barrier_enabled: bool = false

var payment_multiplier_bonus_percent: int = 0

signal ammo_changed(
	normal: int,
	heavy: int,
	explosive: int,
	nuclear: int
)
signal game_won
signal game_lost
signal nuclear_detonated(world_position: Vector3)
signal money_changed(new_amount: int)
signal projectile_type_changed(type_name)

var open_shop_window_on_load: bool = false

func reset_all() -> void:
	player_level = 1
	money = 0
	normal_ammo = 5
	base_normal_ammo = 5
	heavy_ammo = 0
	explosive_ammo = 0
	nuclear_ammo = 1
	game_over = false
	selected_seed = 0
	targets_remaining = 0
	targets_collected = 0
	_nuclear_win_scheduled = false
	charge_speed_multiplier = 1.0
	charge_power_multiplier = 1.0
	barrier_enabled = false
	ring_barrier_enabled = false
	payment_multiplier_bonus_percent = 0

	emit_ammo_changed()

func reset_for_new_round() -> void:
	player_level += 1
	selected_seed = 0
	normal_ammo = base_normal_ammo
	nuclear_ammo = 1
	game_over = false
	targets_remaining = 0
	targets_collected = 0
	_nuclear_win_scheduled = false

	barrier_enabled = false
	ring_barrier_enabled = false
	payment_multiplier_bonus_percent = 0

	emit_ammo_changed()

	print("player level:", player_level)

func reset_run() -> void:
	reset_for_new_round()

func set_selected_seed(seed_value: int) -> void:
	selected_seed = seed_value

func set_barrier_enabled(value: bool) -> void:
	barrier_enabled = value

func set_ring_barrier_enabled(value: bool) -> void:
	ring_barrier_enabled = value

func set_payment_multiplier_bonus_percent(value: int) -> void:
	payment_multiplier_bonus_percent = max(value, 0)

func add_money(amount: int) -> void:
	money += amount
	emit_signal("money_changed", money)

func calculate_reward() -> int:
	var base_reward: int = max((normal_ammo - base_normal_ammo) * 50, 0)
	var multiplier: float = 1.0 + float(payment_multiplier_bonus_percent) / 100.0
	return int(round(base_reward * multiplier))

func apply_upgrade(item: ShopItem) -> void:
	match item.effect_type:
		"ammo":
			var amount := int(item.effect_value)
			base_normal_ammo += amount
			normal_ammo += amount
			emit_ammo_changed()
			
		"max_charge":
			charge_power_multiplier += float(item.effect_value)
			
		"charge_rate":
			charge_speed_multiplier += float(item.effect_value)
			

func apply_ammo(item: AmmoItem) -> void:
	match item.effect_type:
		"normal_ammo":
			print("Normal Ammo Purchased")
			var amount := int(item.effect_value)
			normal_ammo += amount
			print(normal_ammo)
			emit_ammo_changed()
		
		"heavy_ammo":
			print("Heavy Ammo Purchased")
			var amount := int(item.effect_value)
			heavy_ammo += amount
			print(heavy_ammo)
			emit_ammo_changed()
			
		"explosive_ammo":
			print("Eplosive Ammo Purchased")
			var amount := int(item.effect_value)
			explosive_ammo += amount
			print(explosive_ammo)
			emit_ammo_changed()
		
		"nuke_ammo":
			print("Nuke Ammo Purchased")
			var amount := int(item.effect_value)
			nuclear_ammo += amount
			print(nuclear_ammo)
			emit_ammo_changed()

func emit_ammo_changed() -> void:
	emit_signal(
		"ammo_changed",
		normal_ammo,
		heavy_ammo,
		explosive_ammo,
		nuclear_ammo
	)

func get_ammo_count(projectile_type: int) -> int:
	match projectile_type:
		1:
			return normal_ammo
		2:
			return heavy_ammo
		3:
			return explosive_ammo
		4:
			return nuclear_ammo

	return 0

func consume_ammo(projectile_type: int) -> bool:
	match projectile_type:
		1:
			if normal_ammo <= 0:
				return false
			normal_ammo -= 1

		2:
			if heavy_ammo <= 0:
				return false
			heavy_ammo -= 1

		3:
			if explosive_ammo <= 0:
				return false
			explosive_ammo -= 1

		4:
			if nuclear_ammo <= 0:
				return false
			nuclear_ammo -= 1

	emit_ammo_changed()

	check_for_game_loss()

	return true

func total_ammo_remaining() -> int:
	return (
		normal_ammo +
		heavy_ammo +
		explosive_ammo +
		nuclear_ammo
	)

func check_for_game_loss() -> void:
	if total_ammo_remaining() <= 0 and not game_over:
		trigger_game_lost()

func trigger_game_won() -> void:
	if game_over:
		return
	game_over = true
	emit_signal("game_won")

func trigger_game_lost() -> void:
	if game_over:
		return
	game_over = true
	emit_signal("game_lost")

func schedule_nuclear_win(delay_time: float) -> void:
	if _nuclear_win_scheduled:
		return
	_nuclear_win_scheduled = true
	_start_nuclear_win_timer(delay_time)

func _start_nuclear_win_timer(delay_time: float) -> void:
	await get_tree().create_timer(delay_time).timeout

	if not game_over:
		game_over = true
		emit_signal("game_won")

	_nuclear_win_scheduled = false

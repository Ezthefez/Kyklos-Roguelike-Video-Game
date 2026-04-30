extends Node

signal ammo_changed(value: int)
signal nuclear_ammo_changed(value: int)
signal game_won
signal game_lost
signal nuclear_detonated(world_position: Vector3)

var ammo: int = 7
var nuclear_ammo: int = 1
var money: int = 0
var game_over: bool = false
var selected_seed: int = 0

var targets_remaining: int = 0
var targets_collected: int = 0

var _nuclear_win_scheduled: bool = false

func reset_all() -> void:
	ammo = 7
	nuclear_ammo = 1
	game_over = false
	selected_seed = 0
	targets_remaining = 0
	targets_collected = 0
	_nuclear_win_scheduled = false

	emit_signal("ammo_changed", ammo)
	emit_signal("nuclear_ammo_changed", nuclear_ammo)

func reset_for_new_round() -> void:
	ammo = 7
	nuclear_ammo = 1
	game_over = false
	targets_remaining = 0
	targets_collected = 0
	_nuclear_win_scheduled = false

	emit_signal("ammo_changed", ammo)
	emit_signal("nuclear_ammo_changed", nuclear_ammo)

func reset_run() -> void:
	reset_for_new_round()

func set_selected_seed(seed_value: int) -> void:
	selected_seed = seed_value

func add_money(amount: int) -> void:
	money += amount

func calculate_reward() -> int:
	return max(ammo * 10, 0)

func spend_nuclear_ammo() -> bool:
	if nuclear_ammo <= 0:
		return false

	nuclear_ammo -= 1
	emit_signal("nuclear_ammo_changed", nuclear_ammo)
	return true

func consume_regular_ammo() -> bool:
	if ammo <= 0:
		return false

	ammo -= 1
	emit_signal("ammo_changed", ammo)
	return true

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

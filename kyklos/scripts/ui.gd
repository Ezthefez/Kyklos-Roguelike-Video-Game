#ui.gd

extends Node

@onready var ammo_label: Label = $CanvasLayer/AmmoLabel
@onready var nuclear_flash: ColorRect = $CanvasLayer/NuclearFlash

@onready var report_menu: Control = $CanvasLayer/ReportMenu
@onready var lose_menu: Control = $CanvasLayer/LoseScreen
@onready var collected_label: Label = $CanvasLayer/ReportMenu/Panel/StatsContainer/CollectedLabel
@onready var bonus_label: Label = $CanvasLayer/ReportMenu/Panel/StatsContainer/BonusLabel
@onready var total_money_label: Label = $CanvasLayer/ReportMenu/Panel/StatsContainer/TotalMoneyLabel

var _gm: Node = null

var _nuclear_flash_active: bool = false
var _nuclear_flash_timer: float = 0.0
var _nuclear_flash_duration: float = 4.0

func _ready() -> void:
	report_menu.visible = false
	lose_menu.visible = false

	report_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	lose_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	if nuclear_flash != null:
		nuclear_flash.color.a = 0.0
		nuclear_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_gm = get_node_or_null("/root/GameManager")

	if _gm == null:
		push_error("GameManager autoload is missing or has no valid path.")
		_update_ammo(0)
		return

	_update_ammo(_gm.ammo)

	if not _gm.is_connected("ammo_changed", Callable(self, "_on_ammo_changed")):
		_gm.connect("ammo_changed", Callable(self, "_on_ammo_changed"))

	if not _gm.is_connected("game_won", Callable(self, "_on_game_won")):
		_gm.connect("game_won", Callable(self, "_on_game_won"))

	if not _gm.is_connected("game_lost", Callable(self, "_on_game_lost")):
		_gm.connect("game_lost", Callable(self, "_on_game_lost"))

	if not _gm.is_connected("nuclear_detonated", Callable(self, "_on_nuclear_detonated")):
		_gm.connect("nuclear_detonated", Callable(self, "_on_nuclear_detonated"))

func _process(delta: float) -> void:
	if _nuclear_flash_active:
		_nuclear_flash_timer += delta
		var t: float = clamp(_nuclear_flash_timer / _nuclear_flash_duration, 0.0, 1.0)

		var alpha: float
		if t < 0.35:
			alpha = lerp(0.0, 1.0, t / 0.35)
		elif t < 0.7:
			alpha = 1.0
		else:
			alpha = lerp(1.0, 0.0, (t - 0.7) / 0.3)

		if nuclear_flash != null:
			nuclear_flash.color.a = alpha

		if _nuclear_flash_timer >= _nuclear_flash_duration:
			_nuclear_flash_active = false
			if nuclear_flash != null:
				nuclear_flash.color.a = 0.0

func _on_ammo_changed(value: int) -> void:
	_update_ammo(value)

func _update_ammo(value: int) -> void:
	if ammo_label != null:
		ammo_label.text = "Ammo: " + str(value)

func _on_nuclear_detonated(_world_position: Vector3) -> void:
	_nuclear_flash_active = true
	_nuclear_flash_timer = 0.0
	if nuclear_flash != null:
		nuclear_flash.color.a = 0.0

func _on_game_won() -> void:
	if _gm == null:
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().gui_disable_input = false
	get_tree().paused = true
	report_menu.visible = true

	var collected: int = GameManager.ammo - GameManager.base_ammo
	var reward: int = GameManager.calculate_reward()

	_gm.add_money(reward)

	collected_label.text = "Kyklons Collected: " + str(collected)
	bonus_label.text = "Reward: $" + str(reward)
	total_money_label.text = "Total Money: $" + str(_gm.money)

func _on_game_lost() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().gui_disable_input = false
	get_tree().paused = true
	lose_menu.visible = true

func _on_continue_button_pressed() -> void:
	GameManager.reset_run()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().gui_disable_input = false
	get_tree().change_scene_to_file("res://scenes/Shop.tscn")

func _on_new_run_button_pressed() -> void:
	if _gm != null:
		_gm.reset_all()

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_viewport().gui_disable_input = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_to_main_menu_button_pressed() -> void:
	if _gm != null:
		_gm.reset_all()

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().gui_disable_input = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

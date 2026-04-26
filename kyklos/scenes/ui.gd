extends Node

@onready var ammo_label: Label = $CanvasLayer/AmmoLabel
@onready var win_screen: Control = $CanvasLayer/WinScreen
@onready var lose_screen: Control = $CanvasLayer/LoseScreen

func _ready() -> void:
	win_screen.visible = false
	lose_screen.visible = false

	_update_ammo(GameManager.ammo)

	GameManager.connect("ammo_changed", _on_ammo_changed)
	GameManager.connect("game_won", _on_game_won)
	GameManager.connect("game_lost", _on_game_lost)

func _on_ammo_changed(value: int) -> void:
	_update_ammo(value)

func _update_ammo(value: int) -> void:
	ammo_label.text = "Ammo: " + str(value)

func _on_game_won() -> void:
	win_screen.visible = true

func _on_game_lost() -> void:
	lose_screen.visible = true

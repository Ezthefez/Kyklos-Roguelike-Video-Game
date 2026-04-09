extends Node

@onready var player = $player
@onready var charge_circle = $UI/CanvasLayer/CenterContainer/CrosshairRoot/ChargeCircle

func _ready():
	player.charge_ui = charge_circle

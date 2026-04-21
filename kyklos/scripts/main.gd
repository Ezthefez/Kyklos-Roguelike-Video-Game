extends Node

@onready var orbit_controller = $player
@onready var orbit_center = $player/OrbitCenter
@onready var crosshair_root = $UI/CanvasLayer/CrosshairRoot
@onready var charge_circle = $UI/CanvasLayer/CrosshairRoot/ChargeCircle

func _ready() -> void:
	if orbit_controller == null:
		push_error("orbit_controller not found")
		return

	if orbit_center != null:
		orbit_controller.orbit_center = orbit_center

	if charge_circle != null:
		orbit_controller.charge_ui = charge_circle

	if crosshair_root != null:
		orbit_controller.aim_pointer = crosshair_root

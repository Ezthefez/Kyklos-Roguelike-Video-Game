extends Node3D

@onready var pivot = $Pivot
@export var rotation_speed := .5

func _process(delta):
	pivot.rotate_y(rotation_speed * delta)
	pivot.rotate_x((rotation_speed * 0.4) * delta)

extends Camera3D


@onready var cam = $Camera3D
@export var rotation_speed := 0.03 # adjust rotaion
@export var move_speed := 15   # adjust for how fast it moves forward

func _process(delta):
	# rotate
	cam.rotate_y(rotation_speed * delta)
	rotate_x((rotation_speed * 0.4) * delta)
	
	# move forward
	cam.translate(Vector3(0, 0, -move_speed * delta))

extends "res://scenes/player.gd"

@export var shoot_impulse : float = 25.0
@export var fire_cooldown : float = 0.12
@export var projectile_scene : PackedScene

@export var camera : Camera3D
@export var muzzle : Marker3D

var can_fire := true

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func fire():

	if not can_fire:
		return

	can_fire = false

	var projectile = projectile_scene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(projectile)

	projectile.global_transform = muzzle.global_transform

	var dir = -camera.global_transform.basis.z.normalized()

	projectile.apply_central_impulse(dir * shoot_impulse)

	await get_tree().create_timer(fire_cooldown).timeout
	can_fire = true

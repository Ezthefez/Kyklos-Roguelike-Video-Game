#Projectile.tscn.gd

extends CharacterBody3D

@export var mouse_sensitivity: float = 0.002
@export var shoot_impulse: float = 25.0
@export var fire_cooldown: float = 0.12

var ProjectileScene: PackedScene = preload("res://scenes/Projectile.tscn")

@onready var camera: Camera3D = $Camera
@onready var muzzle: Marker3D = $Camera/Muzzle

var pitch: float = 0.0
var can_fire: bool = true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.5, 1.5)
		camera.rotation.x = pitch

	if event.is_action_pressed("shoot"):
		fire()

func fire() -> void:
	if not can_fire:
		return
	can_fire = false

	var projectile := ProjectileScene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(projectile)

	projectile.global_transform = muzzle.global_transform

	var dir := -camera.global_transform.basis.z.normalized()
	projectile.apply_central_impulse(dir * shoot_impulse)

	await get_tree().create_timer(fire_cooldown).timeout
	can_fire = true

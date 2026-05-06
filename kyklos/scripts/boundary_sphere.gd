extends Node3D

@export var boundary_radius: float = 6.0
@export var target_group_name: StringName = &"targetspheres"
@export var visual_sphere_path: NodePath = NodePath("VisualSphere")
@export var auto_match_visual_scale: bool = true

@export var harvest_target_down_offset: float = 0.65
@export var harvest_target_forward_offset: float = 0.35

var harvested: Dictionary = {}

const ResourceHarvestEffect = preload("res://scripts/resource_harvest_effect.gd")

@onready var visual_sphere: MeshInstance3D = get_node_or_null(visual_sphere_path)

func _ready() -> void:
	if auto_match_visual_scale and visual_sphere != null:
		# Assumes SphereMesh radius = 1.0, so scale = boundary_radius.
		visual_sphere.scale = Vector3.ONE * boundary_radius

func _physics_process(_delta: float) -> void:
	var center: Vector3 = global_position

	for node in get_tree().get_nodes_in_group(target_group_name):
		if not (node is RigidBody3D):
			continue

		var body := node as RigidBody3D
		if not is_instance_valid(body):
			continue
		if harvested.has(body):
			continue

		var radius := _get_body_radius(body)
		var distance_from_center := body.global_position.distance_to(center)

		# ENTIRELY outside the boundary sphere
		if distance_from_center > (boundary_radius + radius):
			_begin_harvest(body)

func _get_body_radius(body: RigidBody3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D:
			var shape := (child as CollisionShape3D).shape
			if shape is SphereShape3D:
				return (shape as SphereShape3D).radius * body.global_basis.get_scale().x
	return 0.5

func _get_harvest_target_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return global_position

	# Slightly under the camera and just a little forward so it feels like
	# the ship is receiving the harvested resource.
	return (
		camera.global_position
		- camera.global_transform.basis.y * harvest_target_down_offset
		- camera.global_transform.basis.z * harvest_target_forward_offset
	)

func _spawn_harvest_effect(start_position: Vector3) -> void:
	var target_position := _get_harvest_target_position()
	var effect := ResourceHarvestEffect.new()
	get_tree().current_scene.add_child(effect)
	effect.global_position = Vector3.ZERO
	effect.setup(start_position, target_position)

func _begin_harvest(body: RigidBody3D) -> void:
	if harvested.has(body):
		return

	harvested[body] = true

	var start_position := body.global_position

	# GAME LOGIC
	GameManager.targets_remaining -= 1
	GameManager.targets_collected += 1
	GameManager.ammo += 1
	GameManager.emit_signal("ammo_changed", GameManager.ammo)

	# WIN CHECK
	if GameManager.targets_remaining <= 0 and not GameManager.game_over:
		GameManager.game_over = true
		GameManager.emit_signal("game_won")

	# Visual resource transfer effect
	_spawn_harvest_effect(start_position)

	# Turn off collisions and remove the harvested sphere
	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze = true
	body.sleeping = true
	body.visible = false
	body.call_deferred("queue_free")

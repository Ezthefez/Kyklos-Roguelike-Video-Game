extends Node3D

@export var boundary_radius: float = 6.0
@export var target_group_name: StringName = &"targetspheres"
@export var visual_sphere_path: NodePath = NodePath("VisualSphere")
@export var auto_match_visual_scale: bool = true

var harvested: Dictionary = {}

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

func _begin_harvest(body: RigidBody3D) -> void:
	if harvested.has(body):
		return

	harvested[body] = true

	#GAME LOGIC
	GameManager.targets_remaining -= 1
	GameManager.ammo += 1
	GameManager.emit_signal("ammo_changed", GameManager.ammo)

	#WIN CHECK (IMPORTANT: check BEFORE lose)
	if GameManager.targets_remaining <= 0 and not GameManager.game_over:
		GameManager.game_over = true
		GameManager.emit_signal("game_won")

	#Turn off collisions
	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze = true
	body.sleeping = true

	if body.has_method("begin_boundary_harvest"):
		body.call_deferred("begin_boundary_harvest")
	else:
		body.call_deferred("queue_free")

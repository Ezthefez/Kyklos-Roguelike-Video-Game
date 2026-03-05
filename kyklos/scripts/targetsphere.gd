extends Area3D

@export var cluster_root_path: NodePath
@onready var cluster_root: Node3D = get_node_or_null(cluster_root_path)

func _ready() -> void:
	add_to_group("targets")
	monitoring = true
	monitorable = true

	# Ensure the signal is connected even if it wasn't connected in the editor.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body != null and body.is_in_group("projectiles"):
		body.queue_free()

		if cluster_root != null and cluster_root.has_method("notify_target_destroyed"):
			cluster_root.call("notify_target_destroyed")

		queue_free()

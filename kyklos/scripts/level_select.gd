extends Node3D

@onready var info_panel3 = $CanvasLayer/InfoPanel3
@onready var info_panel2 = $CanvasLayer/InfoPanel2
@onready var info_panel1 = $CanvasLayer/InfoPanel1
@onready var camera = $Camera3D

@export var barrier_cage_scene: PackedScene
@export var preview_barrier_scale: Vector3 = Vector3(2.0, 2.0, 2.0)

var selected_seed: int = 0
var selected_barrier_enabled: bool = false

var selected_level: int = -1
var is_zooming := false

var _cluster_barrier_flags: Array[bool] = [false, false, false]
var _preview_barriers: Array[Node3D] = []

func _on_zoom_finished() -> void:
	is_zooming = false

	GameManager.reset_run()
	GameManager.set_selected_seed(selected_seed)
	GameManager.set_barrier_enabled(selected_barrier_enabled)

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func hide_all_info_panels() -> void:
	info_panel1.visible = false
	info_panel2.visible = false
	info_panel3.visible = false

func select_cluster(level_id: int, focus_node: Node3D) -> void:
	selected_level = level_id
	is_zooming = true
	hide_all_info_panels()

	var tween := create_tween()
	tween.tween_property(camera, "global_position", focus_node.global_position, 1.2)
	tween.finished.connect(_on_zoom_finished)

func _ready() -> void:
	randomize()

	$cluster1.cluster_seed = randi()
	$cluster2.cluster_seed = randi()
	$cluster3.cluster_seed = randi()

	info_panel3.visible = false
	info_panel2.visible = false
	info_panel1.visible = false

	_pick_one_cluster_for_barrier()
	_spawn_preview_barriers()

func _pick_one_cluster_for_barrier() -> void:
	_cluster_barrier_flags = [true, true, true]

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var chosen_index: int = rng.randi_range(0, 2)
	_cluster_barrier_flags[chosen_index] = true

func _spawn_preview_barriers() -> void:
	for barrier in _preview_barriers:
		if is_instance_valid(barrier):
			barrier.queue_free()
	_preview_barriers.clear()

	if barrier_cage_scene == null:
		push_error("level_select.gd: barrier_cage_scene is not assigned.")
		return

	var clusters: Array[Node3D] = [$cluster1, $cluster2, $cluster3]

	for i in range(3):
		if not _cluster_barrier_flags[i]:
			continue

		var barrier := barrier_cage_scene.instantiate() as Node3D
		add_child(barrier)
		barrier.global_position = clusters[i].global_position
		barrier.scale = preview_barrier_scale

		var rng := RandomNumberGenerator.new()
		rng.seed = int(clusters[i].cluster_seed) + 85433

		barrier.set("spin_speed_x_deg", rng.randf_range(5.0, 12.0))
		barrier.set("spin_speed_y_deg", rng.randf_range(5.0, 12.0))
		barrier.set("spin_dir_x", -1.0 if rng.randf() < 0.5 else 1.0)
		barrier.set("spin_dir_y", -1.0 if rng.randf() < 0.5 else 1.0)

		_preview_barriers.append(barrier)

func _on_hover_area_2_mouse_entered() -> void:
	info_panel2.visible = true

func _on_hover_area_2_mouse_exited() -> void:
	info_panel2.visible = false

func _on_hover_area_1_mouse_entered() -> void:
	info_panel1.visible = true

func _on_hover_area_1_mouse_exited() -> void:
	info_panel1.visible = false

func _on_hover_area_3_mouse_entered() -> void:
	info_panel3.visible = true

func _on_hover_area_3_mouse_exited() -> void:
	info_panel3.visible = false

func _on_hover_area_1_input_event(camera_node: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = $cluster1.cluster_seed
		selected_barrier_enabled = _cluster_barrier_flags[0]
		select_cluster(0, $cluster1/CameraFocus1)

func _on_hover_area_2_input_event(camera_node: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = $cluster2.cluster_seed
		selected_barrier_enabled = _cluster_barrier_flags[1]
		select_cluster(1, $cluster2/CameraFocus2)

func _on_hover_area_3_input_event(camera_node: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = $cluster3.cluster_seed
		selected_barrier_enabled = _cluster_barrier_flags[2]
		select_cluster(2, $cluster3/CameraFocus3)

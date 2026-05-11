extends Node3D

@onready var info_panel3 = $CanvasLayer/InfoPanel3
@onready var info_panel2 = $CanvasLayer/InfoPanel2
@onready var info_panel1 = $CanvasLayer/InfoPanel1
@onready var camera = $Camera3D

@export var barrier_cage_scene: PackedScene
@export var ring_barrier_scene: PackedScene

@export var preview_cluster_scale: Vector3 = Vector3(0.68, 0.68, 0.68)
@export var preview_barrier_scale: Vector3 = Vector3(0.92, 0.92, 0.92)
@export var preview_ring_barrier_scale: Vector3 = Vector3(0.92, 0.92, 0.92)

@export var preview_barrier_local_offset: Vector3 = Vector3.ZERO
@export var preview_ring_local_offset: Vector3 = Vector3.ZERO

@export var cage_seed_chance: float = 0.33
@export var ring_seed_chance: float = 0.33

@export var min_spawn_count_base: int = 5
@export var max_spawn_count_base: int = 10
@export var zero_g_cluster_chance: float = 0.50

var selected_seed: int = 0
var selected_barrier_enabled: bool = false
var selected_ring_barrier_enabled: bool = false
var selected_payment_multiplier_bonus_percent: int = 0

var selected_level: int = -1
var is_zooming := false

var _cluster_meta: Array[Dictionary] = [{}, {}, {}]
var _preview_barriers: Array[Node3D] = []
var _preview_ring_barriers: Array[Node3D] = []

func _on_zoom_finished() -> void:
	is_zooming = false

	GameManager.set_selected_seed(selected_seed)
	GameManager.set_barrier_enabled(selected_barrier_enabled)
	GameManager.set_ring_barrier_enabled(selected_ring_barrier_enabled)
	GameManager.set_payment_multiplier_bonus_percent(selected_payment_multiplier_bonus_percent)

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

	_apply_preview_cluster_scale()

	$cluster1.cluster_seed = randi()
	$cluster2.cluster_seed = randi()
	$cluster3.cluster_seed = randi()

	_build_cluster_meta()
	_spawn_preview_barriers()
	_spawn_preview_ring_barriers()

	hide_all_info_panels()

func _apply_preview_cluster_scale() -> void:
	$cluster1.scale = preview_cluster_scale
	$cluster2.scale = preview_cluster_scale
	$cluster3.scale = preview_cluster_scale

func _build_cluster_meta() -> void:
	var seeds: Array[int] = [
		int($cluster1.cluster_seed),
		int($cluster2.cluster_seed),
		int($cluster3.cluster_seed)
	]

	for i in range(3):
		_cluster_meta[i] = _generate_seed_meta(seeds[i], i + 1)

func _generate_seed_meta(seed_value: int, cluster_number: int) -> Dictionary:
	var zero_g_rng := RandomNumberGenerator.new()
	zero_g_rng.seed = seed_value + 190731
	var is_orbital: bool = zero_g_rng.randf() < zero_g_cluster_chance

	var count_rng := RandomNumberGenerator.new()
	count_rng.seed = seed_value + 918273
	var min_count: int = min_spawn_count_base * GameManager.player_level
	var max_count: int = max_spawn_count_base * GameManager.player_level
	var total_targets: int = count_rng.randi_range(min_count, max_count)

	var barrier_rng := RandomNumberGenerator.new()
	barrier_rng.seed = seed_value + 85433
	var has_cage: bool = barrier_rng.randf() < cage_seed_chance
	var has_ring: bool = barrier_rng.randf() < ring_seed_chance

	var payment_bonus: int = 0
	if has_cage and has_ring:
		payment_bonus = 25
	elif has_cage:
		payment_bonus = 15
	elif has_ring:
		payment_bonus = 10

	var cluster_type_text: String = "Orbital" if is_orbital else "Gravitational"
	var cage_text: String = "Yes" if has_cage else "No"
	var ring_text: String = "Yes" if has_ring else "No"

	var panel_text := "Cluster %d:\nTarget Kyklon type: %s\nTotal target Kyklons: %d\nIcosahedron Cage: %s\nRing Barrier: %s\nPayment multiplier: %d%%" % [
		cluster_number,
		cluster_type_text,
		total_targets,
		cage_text,
		ring_text,
		payment_bonus
	]

	return {
		"seed": seed_value,
		"is_orbital": is_orbital,
		"total_targets": total_targets,
		"has_cage": has_cage,
		"has_ring": has_ring,
		"payment_bonus": payment_bonus,
		"panel_text": panel_text
	}

func _spawn_preview_barriers() -> void:
	for barrier_root in _preview_barriers:
		if is_instance_valid(barrier_root):
			barrier_root.queue_free()
	_preview_barriers.clear()

	if barrier_cage_scene == null:
		return

	var clusters: Array[Node3D] = [$cluster1, $cluster2, $cluster3]

	for i in range(3):
		if not bool(_cluster_meta[i].get("has_cage", false)):
			continue

		var preview_root := Node3D.new()
		add_child(preview_root)
		preview_root.global_position = clusters[i].global_position

		var barrier := barrier_cage_scene.instantiate() as Node3D
		preview_root.add_child(barrier)
		barrier.position = preview_barrier_local_offset
		barrier.scale = preview_barrier_scale

		var seed_value: int = int(_cluster_meta[i]["seed"])
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 85433

		barrier.set("spin_speed_x_deg", rng.randf_range(5.0, 12.0))
		barrier.set("spin_speed_y_deg", rng.randf_range(5.0, 12.0))
		barrier.set("spin_dir_x", -1.0 if rng.randf() < 0.5 else 1.0)
		barrier.set("spin_dir_y", -1.0 if rng.randf() < 0.5 else 1.0)

		_preview_barriers.append(preview_root)

func _spawn_preview_ring_barriers() -> void:
	for ring_root in _preview_ring_barriers:
		if is_instance_valid(ring_root):
			ring_root.queue_free()
	_preview_ring_barriers.clear()

	if ring_barrier_scene == null:
		return

	var clusters: Array[Node3D] = [$cluster1, $cluster2, $cluster3]

	for i in range(3):
		if not bool(_cluster_meta[i].get("has_ring", false)):
			continue

		var preview_root := Node3D.new()
		add_child(preview_root)
		preview_root.global_position = clusters[i].global_position

		var ring := ring_barrier_scene.instantiate() as Node3D
		preview_root.add_child(ring)
		ring.position = preview_ring_local_offset
		ring.scale = preview_ring_barrier_scale

		var seed_value: int = int(_cluster_meta[i]["seed"])
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 85433

		var dir_x: float = -1.0 if rng.randf() < 0.5 else 1.0
		var dir_y: float = -1.0 if rng.randf() < 0.5 else 1.0

		ring.set("spin_speed_x_deg", rng.randf_range(5.0, 12.0))
		ring.set("spin_speed_y_deg", rng.randf_range(5.0, 12.0))
		ring.set("spin_dir_x", -dir_x)
		ring.set("spin_dir_y", -dir_y)

		_preview_ring_barriers.append(preview_root)

func _show_cluster_info(panel: Control, text: String) -> void:
	_set_panel_text(panel, text)
	panel.visible = true

func _set_panel_text(panel: Control, text: String) -> void:
	var widget := _find_text_widget(panel)
	if widget == null:
		return

	if widget is Label:
		(widget as Label).text = text
	elif widget is RichTextLabel:
		(widget as RichTextLabel).text = text

func _find_text_widget(node: Node) -> Node:
	if node is Label or node is RichTextLabel:
		return node

	for child in node.get_children():
		var result := _find_text_widget(child)
		if result != null:
			return result

	return null

func _on_hover_area_2_mouse_entered() -> void:
	_show_cluster_info(info_panel2, str(_cluster_meta[1].get("panel_text", "Cluster 2:")))

func _on_hover_area_2_mouse_exited() -> void:
	info_panel2.visible = false

func _on_hover_area_1_mouse_entered() -> void:
	_show_cluster_info(info_panel1, str(_cluster_meta[0].get("panel_text", "Cluster 1:")))

func _on_hover_area_1_mouse_exited() -> void:
	info_panel1.visible = false

func _on_hover_area_3_mouse_entered() -> void:
	_show_cluster_info(info_panel3, str(_cluster_meta[2].get("panel_text", "Cluster 3:")))

func _on_hover_area_3_mouse_exited() -> void:
	info_panel3.visible = false

func _on_hover_area_1_input_event(camera_node: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = int(_cluster_meta[0]["seed"])
		selected_barrier_enabled = bool(_cluster_meta[0]["has_cage"])
		selected_ring_barrier_enabled = bool(_cluster_meta[0]["has_ring"])
		selected_payment_multiplier_bonus_percent = int(_cluster_meta[0]["payment_bonus"])
		select_cluster(0, $cluster1/CameraFocus1)

func _on_hover_area_2_input_event(camera_node: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = int(_cluster_meta[1]["seed"])
		selected_barrier_enabled = bool(_cluster_meta[1]["has_cage"])
		selected_ring_barrier_enabled = bool(_cluster_meta[1]["has_ring"])
		selected_payment_multiplier_bonus_percent = int(_cluster_meta[1]["payment_bonus"])
		select_cluster(1, $cluster2/CameraFocus2)

func _on_hover_area_3_input_event(camera_node: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = int(_cluster_meta[2]["seed"])
		selected_barrier_enabled = bool(_cluster_meta[2]["has_cage"])
		selected_ring_barrier_enabled = bool(_cluster_meta[2]["has_ring"])
		selected_payment_multiplier_bonus_percent = int(_cluster_meta[2]["payment_bonus"])
		select_cluster(2, $cluster3/CameraFocus3)

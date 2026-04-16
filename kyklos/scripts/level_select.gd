extends Node3D

@onready var info_panel3 = $CanvasLayer/InfoPanel3
@onready var info_panel2 = $CanvasLayer/InfoPanel2
@onready var info_panel1 = $CanvasLayer/InfoPanel1
@onready var camera = $Camera3D

var selected_seed: int = 0

var selected_level: int = -1
var is_zooming := false

func _on_zoom_finished():
	is_zooming = false
	
	GameState.selected_seed = selected_seed
	print("SELECTED SEED:", selected_seed)
	
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func hide_all_info_panels():
	info_panel1.visible = false
	info_panel2.visible = false
	info_panel3.visible = false

func select_cluster(level_id: int, focus_node: Node3D):
	selected_level = level_id
	is_zooming = true
	hide_all_info_panels()

	var tween = create_tween()
	tween.tween_property(camera, "global_position", focus_node.global_position, 1.2)
	tween.finished.connect(_on_zoom_finished)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	randomize()

	$cluster1.cluster_seed = randi()
	$cluster2.cluster_seed = randi()
	$cluster3.cluster_seed = randi()
	
	info_panel3.visible = false
	info_panel2.visible = false
	info_panel1.visible = false


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



func _on_hover_area_1_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = $cluster1.cluster_seed
		select_cluster(0, $cluster1/CameraFocus1)

func _on_hover_area_2_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = $cluster2.cluster_seed
		select_cluster(1, $cluster2/CameraFocus2)

func _on_hover_area_3_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if is_zooming:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_seed = $cluster3.cluster_seed
		select_cluster(2, $cluster3/CameraFocus3)

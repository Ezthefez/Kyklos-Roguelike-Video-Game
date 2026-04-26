extends Node3D

# References to cockpit parts
@onready var joystick = $Sketchfab_model/VA_Scifi_Cockpit_7_FBX/Object_2/RootNode/CockpitBody/Joystick
@onready var canopy_anim = $AnimationPlayer
@onready var laptop_anim = $Sketchfab_model/VA_Scifi_Cockpit_7_FBX/Object_2/RootNode/CockpitBody/CentralConsole/Laptop_Position/Cockpit_Laptop/AnimationPlayer
@onready var secondary_screen = $Sketchfab_model/VA_Scifi_Cockpit_7_FBX/Object_2/RootNode/CockpitBody/CentralConsole/SecondaryScreen

# Limits and smoothing for joystick movement
@export var joystick_limit_x: float = 18.0
@export var joystick_limit_y: float = 18.0
@export var joystick_limit_z: float = 25.0
@export var joystick_move_speed: float = 8.0
@export var joystick_return_speed: float = 8.0

# Secondary screen animation settings
@export var secondary_screen_up_x: float = 11.5
@export var secondary_screen_tween_time: float = 0.9

# Store default rotation so joystick returns to "rest" position
var joystick_rest_rotation: Vector3

# Input values passed from orbit controller
var joystick_ws: float = 0.0
var joystick_ad: float = 0.0
var joystick_mouse_roll: float = 0.0

# State tracking
var canopy_open := false
var secondary_screen_up := false

func _ready() -> void:
	# Store the joystick's original rotation (rest position)
	if joystick:
		joystick_rest_rotation = joystick.rotation_degrees

	# Initialize canopy animation at closed position
	if canopy_anim:
		canopy_anim.play("Take 001")
		canopy_anim.seek(0.0, true)
		canopy_anim.stop()

	# Initialize laptop animation at closed position
	if laptop_anim:
		laptop_anim.play("Take 001")
		laptop_anim.seek(0.0, true)
		laptop_anim.stop()

func _process(delta: float) -> void:
	# Update joystick every frame based on input
	update_joystick(delta)

# Called from orbit controller (W/S and A/D input)
func set_joystick_input(ws: float, ad: float) -> void:
	joystick_ws = ws
	joystick_ad = ad

# Called from mouse movement (adds roll/tilt)
func add_mouse_roll(amount: float) -> void:
	joystick_mouse_roll += amount
	joystick_mouse_roll = clamp(joystick_mouse_roll, -joystick_limit_z, joystick_limit_z)

func update_joystick(delta: float) -> void:
	if joystick == null:
		return

	# Convert input into rotation targets
	var target_x: float = clamp(
		joystick_ws * joystick_limit_x,
		-joystick_limit_x,
		joystick_limit_x
	)

	var target_y: float = clamp(
		joystick_ad * joystick_limit_y,
		-joystick_limit_y,
		joystick_limit_y
	)

	# Smoothly return mouse roll back to center
	joystick_mouse_roll = lerp(
		joystick_mouse_roll,
		0.0,
		joystick_return_speed * delta
	) as float

	var target_z: float = clamp(
		joystick_mouse_roll,
		-joystick_limit_z,
		joystick_limit_z
	)

	# Combine rest position with input-based rotation
	var target_rotation: Vector3 = Vector3(
		joystick_rest_rotation.x + target_x,
		joystick_rest_rotation.y + target_y,
		joystick_rest_rotation.z + target_z
	)

	# Smoothly move joystick toward target (interpolation)
	joystick.rotation_degrees.x = lerp(
		joystick.rotation_degrees.x,
		target_rotation.x,
		joystick_move_speed * delta
	) as float

	joystick.rotation_degrees.y = lerp(
		joystick.rotation_degrees.y,
		target_rotation.y,
		joystick_move_speed * delta
	) as float

	joystick.rotation_degrees.z = lerp(
		joystick.rotation_degrees.z,
		target_rotation.z,
		joystick_move_speed * delta
	) as float


# --- CANOPY ---

func toggle_canopy() -> void:
	if canopy_anim == null:
		return
	if canopy_anim.is_playing():
		return

	# Play forward or backward animation depending on state
	if canopy_open:
		canopy_anim.play_backwards("Take 001")
	else:
		canopy_anim.play("Take 001")

	canopy_open = !canopy_open


# --- LAPTOP ---

func toggle_laptop() -> void:
	if laptop_anim == null:
		return
	if laptop_anim.is_playing():
		return

	var anim_name := "Take 001"
	var length: float = laptop_anim.get_animation(anim_name).length
	var pos: float = laptop_anim.current_animation_position

	# Decide whether to open or close based on current position
	if pos >= length - 0.01:
		laptop_anim.play_backwards(anim_name)
	elif pos <= 0.01:
		laptop_anim.play(anim_name)
	else:
		if pos > length * 0.5:
			laptop_anim.play_backwards(anim_name)
		else:
			laptop_anim.play(anim_name)


# --- SECONDARY SCREEN ---

func toggle_secondary_screen() -> void:
	if secondary_screen == null:
		return

	# Decide target rotation (up or down)
	var target_x: float = secondary_screen_up_x if !secondary_screen_up else 0.0

	# Tween creates smooth animation over time
	var tween := create_tween()
	tween.tween_property(
		secondary_screen,
		"rotation_degrees:x",
		target_x,
		secondary_screen_tween_time
	)

	secondary_screen_up = !secondary_screen_up

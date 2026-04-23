extends Node3D

@export var normal_distance: float = 5.0
@export var normal_height: float = 2.0
@export var shiftlock_distance: float = 2.0
@export var shiftlock_height: float = 1.5
@export var shiftlock_offset: float = 1.5
@export var mouse_sensitivity: float = 0.003
@export var vertical_look_limit: float = 80.0

var camera_3d: Camera3D
var player_body: CharacterBody3D
var mouse_x: float = 0.0
var mouse_y: float = 0.0
var shiftlock_enabled: bool = false

func _ready() -> void:
	camera_3d = get_node("Camera3D")
	player_body = get_parent() as CharacterBody3D
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			shiftlock_enabled = !shiftlock_enabled
	
	if event is InputEventMouseMotion:
		mouse_x -= event.relative.x * mouse_sensitivity
		mouse_y -= event.relative.y * mouse_sensitivity
		mouse_y = clamp(mouse_y, -deg_to_rad(vertical_look_limit), deg_to_rad(vertical_look_limit))
		player_body.rotation.y = mouse_x

func _process(delta: float) -> void:
	# Choose distance and height based on shiftlock mode
	var target_distance: float = shiftlock_distance if shiftlock_enabled else normal_distance
	var target_height: float = shiftlock_height if shiftlock_enabled else normal_height
	var target_offset: float = shiftlock_offset if shiftlock_enabled else 0.0
	
	# Get player direction vectors
	var player_forward: Vector3 = -player_body.global_transform.basis.z
	var player_right: Vector3 = player_body.global_transform.basis.x
	var player_up: Vector3 = player_body.global_transform.basis.y
	
	# ANCHOR camera directly to player with offsets (no smoothing)
	global_position = player_body.global_position + (player_forward * target_distance) + (player_up * target_height) + (player_right * target_offset)
	
	# Look at player head with vertical offset from mouse
	var look_target: Vector3 = player_body.global_position + player_up * 0.6
	var direction_to_target: Vector3 = (look_target - global_position).normalized()
	var final_direction: Vector3 = direction_to_target.rotated(player_right, mouse_y)
	
	camera_3d.look_at(global_position + final_direction, player_up)

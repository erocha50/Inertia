extends CharacterBody3D

# Movement parameters
@export var max_speed: float = 20.0
@export var acceleration: float = 80.0
@export var friction: float = 15.0
@export var turn_radius_base: float = 2.5
@export var gravity: float = 9.8
@export var movement_smoothness: float = 0.2
@export var rotation_smoothness: float = 0.15

# Camera reference
var camera_controller: Node3D
var current_speed: float = 0.0
var target_speed: float = 0.0
var air_velocity: Vector3 = Vector3.ZERO
var target_rotation_y: float = 0.0

func _ready() -> void:
	camera_controller = get_node("CameraController")
	target_rotation_y = rotation.y

func _physics_process(delta: float) -> void:
	# Get input direction
	var input_direction: Vector3 = _get_input_direction()
	
	# Apply gravity
	air_velocity.y -= gravity * delta
	
	# Handle movement based on input
	if input_direction.length() > 0:
		# Get camera directions
		var camera_forward: Vector3 = -camera_controller.global_transform.basis.z
		var camera_right: Vector3 = camera_controller.global_transform.basis.x
		
		# Convert input to camera-relative direction (FIXED: ui_up = forward)
		var world_input: Vector3 = ((camera_right * input_direction.x) + (camera_forward * input_direction.z)).normalized()
		
		# Calculate target rotation angle
		target_rotation_y = atan2(world_input.x, world_input.z)
		
		# Set target speed
		target_speed = max_speed
	else:
		# Decelerate
		target_speed = 0.0
	
	# Smoothly interpolate speed (jelly-like acceleration)
	current_speed = lerp(current_speed, target_speed, delta * movement_smoothness)
	
	# Smoothly rotate character toward target rotation
	var angle_diff: float = _angle_difference(rotation.y, target_rotation_y)
	var turn_radius: float = turn_radius_base + (current_speed * 0.15)
	var max_turn_speed: float = (6.0 / turn_radius) * delta
	rotation.y += clamp(angle_diff, -max_turn_speed, max_turn_speed)
	
	# Calculate velocity from character's facing direction
	var forward: Vector3 = -global_transform.basis.z
	var horizontal_velocity: Vector3 = forward * current_speed
	velocity = horizontal_velocity + air_velocity
	
	# Move and slide
	move_and_slide()
	
	# Update air velocity
	if is_on_floor():
		air_velocity.y = 0.0
	else:
		air_velocity.y = velocity.y

func _get_input_direction() -> Vector3:
	var direction: Vector3 = Vector3.ZERO
	
	if Input.is_action_pressed("ui_right"):
		direction.x += 1.0
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_down"):
		direction.z -= 1.0  # FIXED: Down = backward
	if Input.is_action_pressed("ui_up"):
		direction.z += 1.0  # FIXED: Up = forward
	
	return direction

func _angle_difference(from: float, to: float) -> float:
	var diff: float = fmod(to - from + PI, TAU) - PI
	return diff if diff >= -PI else diff + TAU

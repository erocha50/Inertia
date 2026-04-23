extends Node3D

@export var camera_distance: float = 8.0
@export var camera_height: float = 2.5
@export var look_ahead_distance: float = 3.0
@export var horizontal_offset_strength: float = 4.0
@export var smoothing_speed: float = 8.0
@export var tilt_strength: float = 15.0

var camera: Camera3D
var player: CharacterBody3D
var current_offset: Vector3 = Vector3.ZERO
var target_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	camera = $Camera3D
	player = get_parent()
	
	# Set idle position to top right
	target_offset = Vector3(2.0, camera_height, camera_distance)
	current_offset = target_offset

func _process(delta: float) -> void:
	if not player:
		return
	
	# Get player velocity direction
	var vel: Vector3 = player.velocity
	var direction: Vector3 = Vector3.ZERO
	
	if vel.length() > 0.1:
		direction = vel.normalized()
	
	# Calculate target offset based on movement direction
	var target_horizontal_offset: float = 0.0
	var target_vertical_offset: float = camera_height
	var target_distance: float = camera_distance
	
	# If moving, offset camera based on direction
	if direction.length() > 0.1:
		# Right/Left offset (X axis)
		target_horizontal_offset = direction.x * horizontal_offset_strength
		
		# Look ahead when moving forward
		if direction.z < 0:  # Moving forward
			target_distance = camera_distance - look_ahead_distance
	
	# Idle position defaults to top right
	if direction.length() < 0.1:
		target_horizontal_offset = 2.0  # Default to right
		target_vertical_offset = camera_height + 0.5  # Slightly higher when idle
	
	target_offset = Vector3(target_horizontal_offset, target_vertical_offset, target_distance)
	
	# Smooth interpolation
	current_offset = current_offset.lerp(target_offset, smoothing_speed * delta)
	
	# Calculate camera position
	var camera_pos: Vector3 = player.global_position + current_offset
	camera.global_position = camera_pos
	
	# Calculate look ahead point
	var look_target: Vector3 = player.global_position + (direction * look_ahead_distance) + Vector3(0, camera_height * 0.5, 0)
	camera.look_at(look_target, Vector3.UP)
	
	# Apply tilt based on movement
	var tilt_angle: float = -direction.x * tilt_strength
	camera.rotation.z = deg_to_rad(tilt_angle)

class_name CameraController3D
extends Node3D

@export var camera_distance: float = 8.0
@export var camera_height: float = 2.5
@export var look_ahead_distance: float = 3.0
@export var horizontal_offset_strength: float = 4.0
@export var smoothing_speed: float = 8.0
@export var tilt_strength: float = 15.0

var character: CharacterBody3D
var current_offset: Vector3 = Vector3.ZERO
var target_offset: Vector3 = Vector3.ZERO
var movement_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	character = get_parent()
	# Set idle position: top right of character
	target_offset = Vector3(horizontal_offset_strength * 0.5, camera_height, -camera_distance)

func _process(delta: float) -> void:
	if not character:
		return
	
	# Get character velocity direction
	var velocity: Vector3 = character.velocity
	if velocity.length() > 0.1:
		movement_direction = velocity.normalized()
	
	# Calculate target offset based on movement direction
	calculate_target_offset()
	
	# Smoothly interpolate current offset towards target
	current_offset = current_offset.lerp(target_offset, smoothing_speed * delta)
	
	# Apply the offset to this node
	position = current_offset
	
	# Look at a point ahead of the character with smooth tilt
	var look_target: Vector3 = character.global_position + movement_direction * look_ahead_distance + Vector3(0, camera_height * 0.5, 0)
	var camera_pos: Vector3 = character.global_position + current_offset
	look_at(look_target, Vector3.UP)

func calculate_target_offset() -> void:
	# Default idle position: top right
	var base_offset: Vector3 = Vector3(horizontal_offset_strength * 0.5, camera_height, -camera_distance)
	
	# If character is moving, adjust offset based on direction
	if movement_direction.length() > 0.1:
		# Get horizontal movement direction (X and Z only)
		var horizontal_dir: Vector3 = Vector3(movement_direction.x, 0, movement_direction.z).normalized()
		
		# Apply horizontal offset stacking based on movement direction
		var side_offset: float = horizontal_dir.x * horizontal_offset_strength
		base_offset.x = side_offset
		
		# Slightly adjust distance based on forward/backward movement
		var depth_influence: float = -horizontal_dir.z * 1.5
		base_offset.z = -camera_distance + depth_influence
	
	target_offset = base_offset

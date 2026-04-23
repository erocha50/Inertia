class_name FlashCharacter3D
extends CharacterBody3D

@export var acceleration: float = 800.0
@export var max_speed: float = 300.0
@export var friction: float = 600.0

var momentum: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	var input_vector: Vector3 = get_input_vector()
	
	# Apply acceleration or friction
	if input_vector != Vector3.ZERO:
		# Accelerate in the direction of input
		momentum += input_vector * acceleration * delta
		# Clamp velocity to max speed
		if momentum.length() > max_speed:
			momentum = momentum.normalized() * max_speed
	else:
		# Apply friction when no input
		if momentum.length() > 0:
			momentum -= momentum.normalized() * friction * delta
			if momentum.length() < 10:
				momentum = Vector3.ZERO
	
	# Move the character
	velocity = momentum
	move_and_slide()

func get_input_vector() -> Vector3:
	var input: Vector3 = Vector3.ZERO
	input.x = Input.get_axis("ui_left", "ui_right")
	input.z = Input.get_axis("ui_up", "ui_down")
	return input.normalized()

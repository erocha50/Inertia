class_name AnimationPlayer
extends Node3D

## Bob animation settings
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.1

var start_position: Vector3
var time_elapsed: float = 0.0

func _ready() -> void:
	start_position = position

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Create smooth bobbing motion using sine wave
	var bob_offset: float = sin(time_elapsed * bob_speed * PI) * bob_height
	position = start_position + Vector3(0, bob_offset, 0)

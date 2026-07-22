extends AnimatedSprite3D
## Manages the player billboard sprite — idle vs walk animation based on speed.
## SpriteFrames speed is 1.0 for all animations; speed_scale = actual FPS.

@export var idle_fps:float = 4.0       ## Idle animation FPS
@export var walk_min_fps:float = 4.0   ## Walk FPS at minimum movement speed
@export var walk_max_fps:float = 12.0  ## Walk FPS at max speed
@export var min_move_speed:float = 0.5 ## Below this = idle

var _current_speed:float
var _max_speed:float = 40.0

func _ready() -> void:
	var character := get_parent()
	if character is CharacterBody3D and character.has_signal(&"speed_changed"):
		character.speed_changed.connect(_on_speed_changed)
	play(&"idle")

func _on_speed_changed(flat:float, max_speed:float) -> void:
	_current_speed = flat
	_max_speed = max_speed

	if flat > min_move_speed:
		if animation != &"walk":
			play(&"walk")
		var t := clampf((flat - min_move_speed) / (max_speed - min_move_speed), 0.0, 1.0)
		speed_scale = lerpf(walk_min_fps, walk_max_fps, t)
	else:
		if animation != &"idle":
			play(&"idle")
		speed_scale = idle_fps
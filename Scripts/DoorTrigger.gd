extends Area3D

# Attach this to an Area3D placed at your door, with a
# CollisionShape3D child covering the doorway.

@export_file("*.tscn") var target_scene: String
@export var trigger_once: bool = true

var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if trigger_once and has_triggered:
		return

	if not body.is_in_group("player"):
		return

	if target_scene.is_empty():
		push_warning("DoorTrigger: no target_scene set on " + name)
		return

	has_triggered = true
	SceneTransition.transition_to_scene(target_scene)

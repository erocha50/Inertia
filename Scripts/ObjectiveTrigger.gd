extends Area3D

@export var message_text: String = "Reach the checkpoint ahead!"
@export var message_duration: float = 3.0
@export var trigger_once: bool = true

var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if trigger_once and has_triggered:
		return

	if not body.is_in_group("player"):
		return

	ObjectiveMessage.show_message(message_text, message_duration)
	has_triggered = true

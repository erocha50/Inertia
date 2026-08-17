class_name TutorialTrigger
extends Area3D

@export var message: String = "Tutorial message goes here"
@export var duration: float = 3.0

var has_triggered: bool = false
var message_ui: Node = null


func _ready() -> void:
	# Find the ObjectMessageUI in the scene
	message_ui = get_tree().root.get_node_or_null("Node3D/ObjectMessageUI")
	
	# If not found, try to find it anywhere in the scene
	if not message_ui:
		message_ui = get_tree().get_first_node_in_group("message_ui")
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	

func _on_body_entered(body: Node3D) -> void:
	# Only trigger if the player enters
	if body.is_in_group("player") and not has_triggered:
		has_triggered = true
		
		if message_ui and message_ui.has_method("show_message"):
			message_ui.show_message(message, duration)
		else:
			push_error("ObjectMessageUI not found or doesn't have show_message method")


# Allow resetting the trigger from code if needed
func reset_trigger() -> void:
	has_triggered = false

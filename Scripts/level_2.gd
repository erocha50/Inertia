extends Node

# Attach this to the root node of any level scene that should start with
# a fresh, full-health player (e.g. level2, level3, etc.)

func _ready() -> void:
	HealthManager.reset_hp()

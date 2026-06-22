class_name StageLight
extends OmniLight3D

@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@export var height_offset: float = 25.0
@export var horizontal_distance: float = 0.0

func _process(_delta: float) -> void:
	if player:
		var target_pos: Vector3 = player.global_position + Vector3(horizontal_distance, height_offset, 0)
		global_position = target_pos

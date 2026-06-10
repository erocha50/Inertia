extends Node

# ── PlayerSpeedBridge.gd ──────────────────────────────────────────────────────
# Attach as a child of your player node.
# Reads velocity every physics frame and forwards flat speed to HeatManager.
# ─────────────────────────────────────────────────────────────────────────────

var _player: CharacterBody3D = null

## Speed below this is treated as fully stopped (avoids hovering at threshold)
const STOP_THRESHOLD := 1.0


func _ready() -> void:
	if get_parent() is CharacterBody3D:
		_player = get_parent() as CharacterBody3D
	else:
		push_error("PlayerSpeedBridge: parent is not a CharacterBody3D!")


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var flat_speed := Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
	# Snap to zero below threshold so HeatManager doesn't hover near movement_speed_threshold
	if flat_speed < STOP_THRESHOLD:
		flat_speed = 0.0
	HeatManager.update_speed(flat_speed)

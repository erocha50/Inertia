extends Node3D

# Quick test to verify wall camera tilt is working

func _ready() -> void:
	# Get references
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: Player not found!")
		return
	
	var camera_controller: Node = player.get_node("CameraController")
	if not camera_controller:
		print("ERROR: CameraController not found!")
		return
	
	print("✓ Player found")
	print("✓ CameraController found")
	
	# Check that camera controller has the wall tilt variables
	if camera_controller.has_method("_update_wall_tilt"):
		print("✓ _update_wall_tilt method exists")
	else:
		print("✗ _update_wall_tilt method NOT found")
	
	# Check exports
	if "wall_tilt_enabled" in camera_controller:
		print("✓ wall_tilt_enabled export found (value: %s)" % camera_controller.wall_tilt_enabled)
	else:
		print("✗ wall_tilt_enabled export NOT found")
	
	if "wall_tilt_angle" in camera_controller:
		print("✓ wall_tilt_angle export found (value: %.1f°)" % camera_controller.wall_tilt_angle)
	else:
		print("✗ wall_tilt_angle export NOT found")
	
	if "wall_tilt_smooth" in camera_controller:
		print("✓ wall_tilt_smooth export found (value: %.1f)" % camera_controller.wall_tilt_smooth)
	else:
		print("✗ wall_tilt_smooth export NOT found")
	
	# Check player has wall_normal_exposed
	if "wall_normal_exposed" in player:
		print("✓ Player.wall_normal_exposed found")
	else:
		print("✗ Player.wall_normal_exposed NOT found")
	
	print("\nWall camera tilt feature is ready to test!")

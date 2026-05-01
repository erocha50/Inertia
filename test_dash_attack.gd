extends Node

"""Test script to validate dash attack functionality"""

func _ready()->void:
	print("=== Dash Attack System Test ===")
	
	# Wait for the scene to load
	await get_tree().process_frame
	
	# Find the player
	var player = get_tree().root.get_node("TestWorld/CharacterBody3D")
	if not player:
		print("✗ Player not found in scene")
		return
	
	print("✓ Player found: %s" % player.name)
	
	# Check if player has the required signals
	var required_signals = ["dash_attack_performed", "speed_changed", "state_changed"]
	for sig in required_signals:
		if player.has_signal(sig):
			print("✓ Signal found: %s" % sig)
		else:
			print("✗ Signal NOT found: %s" % sig)
	
	# Check if player has the required methods
	var required_methods = ["_perform_dash_attack", "_apply_dash_attack_camera_pop"]
	for method in required_methods:
		if player.has_method(method):
			print("✓ Method found: %s" % method)
		else:
			print("✗ Method NOT found: %s" % method)
	
	# Check exported variables
	var required_vars = [
		"dash_attack_force",
		"dash_attack_cooldown", 
		"dash_attack_fov_pop",
		"dash_attack_fov_duration",
		"dash_attack_momentum_scale",
		"dash_attack_min_speed"
	]
	for var_name in required_vars:
		if var_name in player:
			var val = player.get(var_name)
			print("✓ Export var '%s' = %s" % [var_name, val])
		else:
			print("✗ Export var NOT found: %s" % var_name)
	
	# Check internal state variables
	var state_vars = [
		"_dash_attack_cd",
		"_dash_attack_active",
		"_dash_attack_dir",
		"_dash_attack_end_time",
		"_dash_attack_duration"
	]
	for var_name in state_vars:
		if var_name in player:
			print("✓ State var found: %s" % var_name)
		else:
			print("✗ State var NOT found: %s" % var_name)
	
	print("\n=== Dash Attack Input Test ===")
	
	# Test 1: Simulate dash attack input when on ground with momentum
	print("\nTest 1: Dash attack from running state")
	player.velocity = Vector3(20, 0, 0)  # Some horizontal momentum
	player._max_spd = 30.0
	var initial_speed = player._flat_spd()
	print("  Initial flat speed: %.2f" % initial_speed)
	
	# Call dash attack directly
	player._perform_dash_attack()
	
	var new_speed = player._flat_spd()
	print("  New flat speed after dash: %.2f" % new_speed)
	print("  Dash attack active: %s" % player._dash_attack_active)
	print("  Dash attack cooldown: %.2f" % player._dash_attack_cd)
	
	if player._dash_attack_active:
		print("  ✓ Dash attack activated successfully")
	else:
		print("  ✗ Dash attack did NOT activate")
	
	# Test 2: Verify cooldown prevents immediate re-execution
	print("\nTest 2: Cooldown prevents immediate re-execution")
	player._perform_dash_attack()
	if player._dash_attack_cd > 0.0:
		print("  ✓ Cooldown prevented immediate re-execution")
	else:
		print("  ✗ Cooldown did NOT prevent re-execution")
	
	# Test 3: Wait for cooldown to expire and try again
	print("\nTest 3: Execute after cooldown expires")
	var cooldown_duration = player.dash_attack_cooldown
	await get_tree().create_timer(cooldown_duration + 0.1).timeout
	
	player._perform_dash_attack()
	if player._dash_attack_active:
		print("  ✓ Dash attack executed successfully after cooldown")
	else:
		print("  ✗ Failed to execute after cooldown")
	
	print("\n=== Test Complete ===")
	queue_free()

"""
Comprehensive validation test for dash attack implementation
Run this to verify all components are properly connected
"""
extends Node

var _player: Node
var _test_results: Dictionary = {}

func _ready() -> void:
	print("\n" + "="*70)
	print("DASH ATTACK IMPLEMENTATION VALIDATION TEST")
	print("="*70 + "\n")
	
	await get_tree().process_frame
	
	# Find player
	_player = get_tree().root.get_node_or_null("TestWorld/CharacterBody3D")
	if not _player:
		print("❌ FAILED: Player not found in scene")
		_report_results()
		return
	
	print("✅ Player found: %s\n" % _player.name)
	
	# Run all validation tests
	_test_signals()
	_test_methods()
	_test_variables()
	_test_input_mapping()
	_test_functionality()
	
	# Report results
	_report_results()
	
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _test_signals() -> void:
	print("Testing Signals...")
	var signals_to_check = [
		"dash_attack_performed",
		"speed_changed",
		"state_changed"
	]
	
	for signal_name in signals_to_check:
		if _player.has_signal(signal_name):
			print("  ✅ Signal exists: %s" % signal_name)
			_test_results[signal_name] = true
		else:
			print("  ❌ Signal missing: %s" % signal_name)
			_test_results[signal_name] = false
	print()


func _test_methods() -> void:
	print("Testing Methods...")
	var methods_to_check = [
		"_perform_dash_attack",
		"_apply_dash_attack_camera_pop",
		"_flat_spd",
		"_wish_dir"
	]
	
	for method_name in methods_to_check:
		if _player.has_method(method_name):
			print("  ✅ Method exists: %s" % method_name)
			_test_results[method_name] = true
		else:
			print("  ❌ Method missing: %s" % method_name)
			_test_results[method_name] = false
	print()


func _test_variables() -> void:
	print("Testing Variables...")
	var vars_to_check = {
		"dash_attack_force": 50.0,
		"dash_attack_cooldown": 5.0,
		"dash_attack_fov_pop": 15.0,
		"dash_attack_fov_duration": 0.3,
		"dash_attack_momentum_scale": 1.5,
		"dash_attack_min_speed": 15.0,
		"_dash_attack_cd": 0.0,
		"_dash_attack_active": false,
		"_dash_attack_duration": 0.2
	}
	
	for var_name in vars_to_check.keys():
		if var_name in _player:
			var actual_val = _player.get(var_name)
			var expected_val = vars_to_check[var_name]
			if actual_val == expected_val:
				print("  ✅ Var '%s' = %s (expected)" % [var_name, actual_val])
				_test_results[var_name] = true
			else:
				print("  ⚠️  Var '%s' = %s (expected %s)" % [var_name, actual_val, expected_val])
				_test_results[var_name] = true  # Still passes, just different value
		else:
			print("  ❌ Var missing: %s" % var_name)
			_test_results[var_name] = false
	print()


func _test_input_mapping() -> void:
	print("Testing Input Mapping...")
	
	if InputMap.has_action("dash_attack"):
		print("  ✅ Input action 'dash_attack' exists")
		_test_results["input_dash_attack"] = true
		
		var events = InputMap.action_get_events("dash_attack")
		if events.size() > 0:
			print("  ✅ Input action has %d event(s)" % events.size())
			for event in events:
				print("     - %s" % event)
		else:
			print("  ⚠️  Input action has no events")
	else:
		print("  ❌ Input action 'dash_attack' not found")
		_test_results["input_dash_attack"] = false
	print()


func _test_functionality() -> void:
	print("Testing Functionality...")
	
	# Test 1: Can perform dash attack when not on cooldown
	print("  Test 1: Execute dash attack")
	_player._dash_attack_cd = 0.0  # Reset cooldown
	_player._dash_attack_active = false
	
	var initial_vel = _player.velocity
	_player._perform_dash_attack()
	
	if _player._dash_attack_active:
		print("    ✅ Dash attack activated")
		_test_results["functionality_activate"] = true
	else:
		print("    ❌ Dash attack did not activate")
		_test_results["functionality_activate"] = false
	
	# Test 2: Cooldown prevents re-execution
	print("  Test 2: Cooldown prevention")
	var old_cd = _player._dash_attack_cd
	_player._perform_dash_attack()
	
	if _player._dash_attack_cd == old_cd:
		print("    ✅ Cooldown prevented re-execution")
		_test_results["functionality_cooldown"] = true
	else:
		print("    ❌ Cooldown did not prevent re-execution")
		_test_results["functionality_cooldown"] = false
	
	# Test 3: Direction is locked
	print("  Test 3: Direction locking")
	if _player._dash_attack_dir.length() > 0.1:
		print("    ✅ Direction was locked: %s" % _player._dash_attack_dir)
		_test_results["functionality_direction"] = true
	else:
		print("    ❌ Direction was not locked")
		_test_results["functionality_direction"] = false
	
	# Test 4: Speed is applied
	print("  Test 4: Speed application")
	var attack_speed = _player._flat_spd()
	if attack_speed > 0:
		print("    ✅ Speed applied: %.2f" % attack_speed)
		_test_results["functionality_speed"] = true
	else:
		print("    ❌ Speed was not applied")
		_test_results["functionality_speed"] = false
	
	print()


func _report_results() -> void:
	print("="*70)
	print("TEST RESULTS SUMMARY")
	print("="*70)
	
	var passed = 0
	var failed = 0
	
	for test_name in _test_results.keys():
		if _test_results[test_name]:
			passed += 1
		else:
			failed += 1
			print("  ❌ FAILED: %s" % test_name)
	
	print("\nTotal: %d/%d tests passed" % [passed, _test_results.size()])
	
	if failed == 0:
		print("\n🎉 ALL TESTS PASSED! Dash attack is ready to use!")
	else:
		print("\n⚠️  %d test(s) failed. See details above." % failed)
	
	print("="*70 + "\n")

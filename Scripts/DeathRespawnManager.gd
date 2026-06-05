extends Node

signal player_died(death_position: Vector3)
signal player_respawned(respawn_position: Vector3)
signal death_timer_changed(seconds_remaining: float)

@export var heat_zero_death_delay: float = 6.5
@export var respawn_heat_gift: float = 30.0
## Heat must drop BELOW this value to start the death timer
@export var death_heat_threshold: float = 5.0

const HEAT_TRAIL_SCENE: String = "res://Scenes/heat_trail.tscn"

var _heat_zero_timer: float        = 0.0
var _is_dead: bool                 = false
var _last_checkpoint: Vector3      = Vector3.ZERO
var _has_checkpoint: bool          = false
var _heat_at_death: float          = 50.0

var _player: CharacterBody3D       = null
var _respawn_screen: Node          = null
var _heat_trail_scene: PackedScene = null


func _ready() -> void:
	if ResourceLoader.exists(HEAT_TRAIL_SCENE):
		_heat_trail_scene = load(HEAT_TRAIL_SCENE)
	else:
		push_error("DeathRespawnManager: HeatTrail scene NOT found at: " + HEAT_TRAIL_SCENE)
	
	# Wait for the scene tree to be fully ready before initializing connections
	# This is critical because DeathRespawnManager is an autoload and initializes
	# before the actual game scene is loaded. We need to wait multiple frames
	# to ensure all nodes are in the tree and added to their groups
	print("DeathRespawnManager: Waiting for scene tree to be ready...")
	for i in range(10):
		await get_tree().process_frame
	print("DeathRespawnManager: Scene tree should be ready now, calling _init_connections()")
	_init_connections()
	
	# Listen for scene changes and re-initialize
	get_tree().scene_changed.connect(_on_scene_changed)


func _init_connections() -> void:
	print("DeathRespawnManager: _init_connections() called")
	print("DeathRespawnManager: Current scene: ", get_tree().current_scene)
	print("DeathRespawnManager: Root: ", get_tree().root)
	
	# Try to find player by group first
	var players := get_tree().get_nodes_in_group("player")
	print("DeathRespawnManager: Players in 'player' group: ", players.size())
	if not players.is_empty():
		_player = players[0]
		print("DeathRespawnManager: Found player by group: ", _player.name)
	else:
		print("DeathRespawnManager: No players in group, searching by name...")
		# Fallback: find by node name
		var current_scene: Node = get_tree().current_scene
		if current_scene:
			print("DeathRespawnManager: Searching for CharacterBody3D in: ", current_scene.name)
			_player = current_scene.find_child("CharacterBody3D", true, false) as CharacterBody3D
			if _player:
				print("DeathRespawnManager: Found player by name 'CharacterBody3D': ", _player.name)
			else:
				print("DeathRespawnManager: CharacterBody3D not found! Checking all children...")
				for child in current_scene.get_children():
					print("  - ", child.name, " (", child.get_class(), ")")
		else:
			print("DeathRespawnManager: No current scene!")

	# Try to find respawn screen by group first
	var screens := get_tree().get_nodes_in_group("respawn_screen")
	print("DeathRespawnManager: Respawn screens in 'respawn_screen' group: ", screens.size())
	if not screens.is_empty():
		_respawn_screen = screens[0]
		print("DeathRespawnManager: Found respawn screen by group: ", _respawn_screen.name)
	else:
		print("DeathRespawnManager: No respawn screens in group, searching by name...")
		# Fallback: find by node name
		var current_scene: Node = get_tree().current_scene
		if current_scene:
			print("DeathRespawnManager: Searching for RespawnScreen in: ", current_scene.name)
			_respawn_screen = current_scene.find_child("RespawnScreen", true, false)
			if _respawn_screen:
				print("DeathRespawnManager: Found respawn screen by name 'RespawnScreen': ", _respawn_screen.name)
			else:
				print("DeathRespawnManager: RespawnScreen not found! Checking all children...")
				for child in current_scene.get_children():
					print("  - ", child.name, " (", child.get_class(), ")")
		else:
			print("DeathRespawnManager: No current scene!")

	if HeatManager.has_signal("heat_changed"):
		HeatManager.heat_changed.connect(_on_heat_changed)
	
	print("DeathRespawnManager: Initialization complete! Player: ", _player, " Screen: ", _respawn_screen)


func _process(delta: float) -> void:
	if _is_dead:
		return

	if HeatManager.heat_value < death_heat_threshold:
		# Save last real heat before it bottomed out
		if HeatManager.heat_value > 0.0:
			_heat_at_death = HeatManager.heat_value

		_heat_zero_timer += delta
		death_timer_changed.emit(maxf(heat_zero_death_delay - _heat_zero_timer, 0.0))

		if _heat_zero_timer >= heat_zero_death_delay:
			_trigger_death()
	else:
		# Player has enough heat — save it and reset timer
		_heat_at_death   = HeatManager.heat_value
		if _heat_zero_timer > 0.0:
			_heat_zero_timer = move_toward(_heat_zero_timer, 0.0, delta * 3.0)
			death_timer_changed.emit(maxf(heat_zero_death_delay - _heat_zero_timer, 0.0))


func _trigger_death() -> void:
	if _is_dead:
		return
	_is_dead         = true
	_heat_zero_timer = 0.0

	var death_pos: Vector3 = _player.global_position if _player else Vector3.ZERO

	if _player:
		_player.set_physics_process(false)
		_player.set_process(false)

	print("DeathRespawnManager: Death triggered at position: ", death_pos)
	_spawn_heat_trail(death_pos)
	player_died.emit(death_pos)

	# Try to find respawn screen if not already found
	if _respawn_screen == null:
		print("DeathRespawnManager: Respawn screen not found, attempting to find it now...")
		_init_connections()
	
	if _respawn_screen:
		print("DeathRespawnManager: Respawn screen found, calling show_screen()")
		if _respawn_screen.has_method("show_screen"):
			_respawn_screen.show_screen()
		else:
			push_error("DeathRespawnManager: Respawn screen does not have show_screen method")
	else:
		push_error("DeathRespawnManager: No respawn screen found when death triggered")


func _spawn_heat_trail(pos: Vector3) -> void:
	if _heat_trail_scene == null:
		push_error("DeathRespawnManager: heat trail scene is null")
		return

	var trail = _heat_trail_scene.instantiate()
	get_tree().root.add_child(trail)
	trail.spawn_at(pos, _heat_at_death)


func do_respawn() -> void:
	if not _is_dead:
		return

	var respawn_pos: Vector3 = _last_checkpoint if _has_checkpoint else _get_level_start()

	if _player:
		_player.global_position = respawn_pos
		_player.velocity        = Vector3.ZERO
		_player.set_physics_process(true)
		_player.set_process(true)

	HeatManager.set_heat(respawn_heat_gift)

	_is_dead         = false
	_heat_zero_timer = 0.0
	_heat_at_death   = respawn_heat_gift

	death_timer_changed.emit(heat_zero_death_delay)
	player_respawned.emit(respawn_pos)

	if _respawn_screen and _respawn_screen.has_method("hide_screen"):
		_respawn_screen.hide_screen()


func register_checkpoint(world_position: Vector3) -> void:
	_last_checkpoint = world_position
	_has_checkpoint  = true


func get_last_checkpoint() -> Vector3:
	return _last_checkpoint if _has_checkpoint else _get_level_start()


func _on_heat_changed(_new_value: float, _tier: String) -> void:
	pass


func _on_scene_changed() -> void:
	var new_scene: Node = get_tree().current_scene
	print("DeathRespawnManager: Scene changed to: ", new_scene.name if new_scene else "Unknown")
	# Reset death state when changing scenes
	_is_dead = false
	_heat_zero_timer = 0.0
	# Re-initialize connections for the new scene
	for i in range(5):
		await get_tree().process_frame
	print("DeathRespawnManager: Re-initializing for new scene...")
	_init_connections()


func _get_level_start() -> Vector3:
	var sp := get_tree().current_scene.find_child("SpawnPoint", true, false)
	if sp and sp is Node3D:
		return (sp as Node3D).global_position
	return Vector3(0, 2, 0)

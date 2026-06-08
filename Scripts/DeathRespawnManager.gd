extends Node

# ── DeathRespawnManager.gd ────────────────────────────────────────────────────
# Autoload. Listens to HeatManager.heat_changed.
# Instant death when heat hits 0.
# ─────────────────────────────────────────────────────────────────────────────

signal player_died(death_position: Vector3)
signal player_respawned(respawn_position: Vector3)
signal death_timer_changed(seconds_remaining: float)

@export var respawn_heat_gift: float   = 50.0
var heat_zero_death_delay: float       = 1.0   # kept for RespawnScreen compat

const HEAT_TRAIL_SCENE := "res://Scenes/heat_trail.tscn"

var _is_dead: bool                 = false
var _last_checkpoint: Vector3      = Vector3.ZERO
var _has_checkpoint: bool          = false
var _heat_at_death: float          = 50.0

var _player: CharacterBody3D       = null
var _respawn_screen: Node          = null
var _heat_trail_scene: PackedScene = null
var _connected: bool               = false


func _ready() -> void:
	if ResourceLoader.exists(HEAT_TRAIL_SCENE):
		_heat_trail_scene = load(HEAT_TRAIL_SCENE)
	else:
		push_error("DeathRespawnManager: HeatTrail not found at " + HEAT_TRAIL_SCENE)


func _process(_delta: float) -> void:
	# Keep trying to connect until everything is in the tree
	if not _connected:
		_try_connect()


func _try_connect() -> void:
	# Find player
	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_player = players[0]

	# Find respawn screen
	if _respawn_screen == null:
		var screens := get_tree().get_nodes_in_group("respawn_screen")
		if not screens.is_empty():
			_respawn_screen = screens[0]

	# Connect to HeatManager once player is found
	if _player != null and not _connected:
		HeatManager.heat_changed.connect(_on_heat_changed)
		_connected = true


func _on_heat_changed(new_value: float, _tier: String) -> void:
	if _is_dead:
		return

	if new_value > 0.0:
		_heat_at_death = new_value
		death_timer_changed.emit(heat_zero_death_delay)
	else:
		death_timer_changed.emit(0.0)
		_trigger_death()


func _trigger_death() -> void:
	if _is_dead:
		return
	_is_dead = true

	var death_pos := _player.global_position if _player else Vector3.ZERO

	if _player:
		_player.set_physics_process(false)
		_player.set_process(false)

	_spawn_heat_trail(death_pos)
	player_died.emit(death_pos)

	if _respawn_screen and _respawn_screen.has_method("show_screen"):
		_respawn_screen.show_screen()


func _spawn_heat_trail(pos: Vector3) -> void:
	if _heat_trail_scene == null:
		push_error("DeathRespawnManager: _heat_trail_scene is null")
		return
	var trail = _heat_trail_scene.instantiate()
	get_tree().root.add_child(trail)
	trail.spawn_at(pos, _heat_at_death)


func do_respawn() -> void:
	if not _is_dead:
		return

	var respawn_pos := _last_checkpoint if _has_checkpoint else _get_level_start()

	if _player:
		_player.global_position = respawn_pos
		_player.velocity        = Vector3.ZERO
		_player.set_physics_process(true)
		_player.set_process(true)

	HeatManager.set_heat(respawn_heat_gift)
	_is_dead       = false
	_heat_at_death = respawn_heat_gift

	death_timer_changed.emit(heat_zero_death_delay)
	player_respawned.emit(respawn_pos)

	if _respawn_screen and _respawn_screen.has_method("hide_screen"):
		_respawn_screen.hide_screen()


func register_checkpoint(world_position: Vector3) -> void:
	_last_checkpoint = world_position
	_has_checkpoint  = true


func get_last_checkpoint() -> Vector3:
	return _last_checkpoint if _has_checkpoint else _get_level_start()


func _get_level_start() -> Vector3:
	var sp := get_tree().current_scene.find_child("SpawnPoint", true, false)
	if sp and sp is Node3D:
		return (sp as Node3D).global_position
	return Vector3(0, 2, 0)

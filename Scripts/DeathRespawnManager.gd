extends Node

# ── DeathRespawnManager.gd ────────────────────────────────────────────────────
# Autoload. Death now triggers when HP hits 0 (via HealthManager).
# Heat hitting 0 starts HP drain — HP reaching 0 = death.
# ─────────────────────────────────────────────────────────────────────────────

signal player_died(death_position: Vector3)
signal player_respawned(respawn_position: Vector3)
signal death_timer_changed(seconds_remaining: float)

@export var respawn_heat_gift: float = 50.0
var heat_zero_death_delay: float     = 4.0   # kept for overlay timing

const HEAT_TRAIL_SCENE := "res://Scenes/heat_trail.tscn"

var _is_dead: bool                 = false
var _heat_timer: float             = 0.0    # how long heat has been at 0
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


func _process(delta: float) -> void:
	# If the player (or respawn screen) we're holding onto has been
	# freed — which happens whenever a scene change swaps in a new
	# player instance — drop the stale references and look again.
	if not is_instance_valid(_player):
		_player = null
		_connected = false

	if not is_instance_valid(_respawn_screen):
		_respawn_screen = null

	if not _connected:
		_try_connect()
		return

	if _is_dead:
		return

	# Track heat timer just for the darkness overlay signal
	if HeatManager.heat_value <= 0.0:
		_heat_timer += delta
		death_timer_changed.emit(maxf(heat_zero_death_delay - _heat_timer, 0.0))
	else:
		_heat_at_death = HeatManager.heat_value
		if _heat_timer > 0.0:
			_heat_timer = 0.0
			death_timer_changed.emit(heat_zero_death_delay)


func _try_connect() -> void:
	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_player = players[0]

	if _respawn_screen == null:
		var screens := get_tree().get_nodes_in_group("respawn_screen")
		if not screens.is_empty():
			_respawn_screen = screens[0]

	if _player != null:
		# Death is now triggered by HP hitting 0.
		# Guard against double-connecting: HealthManager is also an
		# autoload and persists across scene changes, so if it was
		# already connected from before, connecting again would
		# error out (or fire _trigger_death twice per death).
		if not HealthManager.player_hp_zero.is_connected(_trigger_death):
			HealthManager.player_hp_zero.connect(_trigger_death)
		_connected = true
		_is_dead = false  # fresh scene, fresh life


func _trigger_death() -> void:
	if _is_dead:
		return
	_is_dead    = true
	_heat_timer = 0.0

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
	HealthManager.reset_hp()

	_is_dead    = false
	_heat_timer = 0.0

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
		print("SpawnPoint found at ", (sp as Node3D).global_position)
		return (sp as Node3D).global_position
	print("SpawnPoint NOT found, falling back to (0, 2, 0)")
	return Vector3(0, 2, 0)

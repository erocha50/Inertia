extends Node

# ── DeathRespawnManager.gd ────────────────────────────────────────────────────
# Autoload as "DeathRespawnManager" in Project > Project Settings > Autoload
# ─────────────────────────────────────────────────────────────────────────────

signal player_died(death_position: Vector3)
signal player_respawned(respawn_position: Vector3)
signal death_timer_changed(seconds_remaining: float)

## Seconds heat must stay at 0 before death triggers
@export var heat_zero_death_delay: float = 6.5
## Heat given to the player on respawn so they aren't immediately dying again
@export var respawn_heat_gift: float = 20.0

## Path to HeatTrail scene
const HEAT_TRAIL_SCENE: String = "res://Scenes/heat_trail.tscn"

# ── Internal state ────────────────────────────────────────────────────────────
var _heat_zero_timer: float       = 0.0
var _is_dead: bool                = false
var _last_checkpoint: Vector3     = Vector3.ZERO
var _has_checkpoint: bool         = false

var _player: CharacterBody3D      = null
var _respawn_screen: Node         = null
var _heat_trail_scene: PackedScene = null


func _ready() -> void:
	call_deferred("_init_connections")
	if ResourceLoader.exists(HEAT_TRAIL_SCENE):
		_heat_trail_scene = load(HEAT_TRAIL_SCENE)


func _init_connections() -> void:
	# Find player by group
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]

	# Find RespawnScreen by group
	var screens := get_tree().get_nodes_in_group("respawn_screen")
	if not screens.is_empty():
		_respawn_screen = screens[0]

	if HeatManager.has_signal("heat_changed"):
		HeatManager.heat_changed.connect(_on_heat_changed)


func _process(delta: float) -> void:
	if _is_dead:
		return

	if HeatManager.heat_value <= 0.0:
		# Heat is at zero — tick the death timer
		_heat_zero_timer += delta
		death_timer_changed.emit(maxf(heat_zero_death_delay - _heat_zero_timer, 0.0))

		if _heat_zero_timer >= heat_zero_death_delay:
			_trigger_death()
	else:
		# Heat is above zero — fade the overlay back out smoothly
		if _heat_zero_timer > 0.0:
			# Drain the timer faster than it fills so recovery feels snappy
			_heat_zero_timer = move_toward(_heat_zero_timer, 0.0, delta * 3.0)
			death_timer_changed.emit(maxf(heat_zero_death_delay - _heat_zero_timer, 0.0))


# ── Death ─────────────────────────────────────────────────────────────────────

func _trigger_death() -> void:
	if _is_dead:
		return
	_is_dead        = true
	_heat_zero_timer = 0.0

	var death_pos: Vector3 = _player.global_position if _player else Vector3.ZERO

	# Freeze the player
	if _player:
		_player.set_physics_process(false)
		_player.set_process(false)

	_spawn_heat_trail(death_pos)
	player_died.emit(death_pos)

	if _respawn_screen and _respawn_screen.has_method("show_screen"):
		_respawn_screen.show_screen()


func _spawn_heat_trail(pos: Vector3) -> void:
	if _heat_trail_scene == null:
		push_warning("DeathRespawnManager: HeatTrail scene not found at %s" % HEAT_TRAIL_SCENE)
		return

	var trail = _heat_trail_scene.instantiate()
	get_tree().current_scene.add_child(trail)
	trail.spawn_at(pos, HeatManager.heat_value)


# ── Respawn ───────────────────────────────────────────────────────────────────

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

	# Emit a clean zero-elapsed signal so the overlay clears instantly on respawn
	death_timer_changed.emit(heat_zero_death_delay)

	player_respawned.emit(respawn_pos)

	if _respawn_screen and _respawn_screen.has_method("hide_screen"):
		_respawn_screen.hide_screen()


# ── Checkpoint registration ───────────────────────────────────────────────────

func register_checkpoint(world_position: Vector3) -> void:
	_last_checkpoint = world_position
	_has_checkpoint  = true


func get_last_checkpoint() -> Vector3:
	return _last_checkpoint if _has_checkpoint else _get_level_start()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _on_heat_changed(_new_value: float, _tier: String) -> void:
	pass


func _get_level_start() -> Vector3:
	var sp := get_tree().current_scene.find_child("SpawnPoint", true, false)
	if sp and sp is Node3D:
		return (sp as Node3D).global_position
	return Vector3(0, 2, 0)

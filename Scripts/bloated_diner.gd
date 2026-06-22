extends CharacterBody3D

# --- Stats ---
@export var max_health: float = 80.0
@export var move_speed: float = 4.5
@export var sprint_speed: float = 8.0
@export var fork_volley_count: int = 5
@export var fork_interval: float = 0.1
@export var volley_cooldown: float = 2.5
@export var detection_range: float = 35.0
@export var fork_scene: PackedScene

# --- State Machine ---
enum State { IDLE, CHASE, WINDUP, VOLLEY, SPRINT, HURT, DEAD }
var state: State = State.IDLE

var _health_bar: Node3D = null
var current_health: float
var player: Node3D = null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var fork_launcher: Node3D = $ForkLauncher
@onready var fork_spawn: Marker3D = $ForkLauncher/ForkSpawnPoint
@onready var detection_area: Area3D = $DetectionArea

var volley_timer: float = 0.0
var volley_shots_fired: int = 0
var fork_fire_timer: float = 0.0
var sprint_target: Vector3 = Vector3.ZERO

# Fork beam: lateral offsets so forks fan out side-by-side like a swept beam.
# Generated fresh each volley so the beam always cleanly brackets the player.
var _beam_offsets: Array = []
var _beam_curve_sign: float = 1.0  # +1 or -1, randomised per volley

var _spawn_position: Vector3 = Vector3.ZERO
var respawn_delay: float = 5.0

const GRAVITY = -9.8

func _ready() -> void:
	current_health = max_health

	_spawn_position = global_position
	_health_bar = preload("res://Scripts/EnemyHealthBar.gd").new()
	add_child(_health_bar)
	
	if detection_area:
		detection_area.monitoring = true
		detection_area.collision_layer = 0
		detection_area.collision_mask = 0x2  # Layer 2 = Player
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_error("BloatedDiner: Area3D node not found!")
	
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody3D
		print_debug("BloatedDiner: Player found via group: %s" % player.name)
		if state == State.IDLE:
			_change_state(State.CHASE)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_apply_gravity(delta)
	volley_timer -= delta

	match state:
		State.IDLE:
			_state_idle()
		State.CHASE:
			_state_chase(delta)
		State.WINDUP:
			_state_windup(delta)
		State.VOLLEY:
			_state_volley(delta)
		State.SPRINT:
			_state_sprint(delta)
		State.HURT:
			velocity.x = 0
			velocity.z = 0

	move_and_slide()

# ─── Gravity ────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

# ─── States ─────────────────────────────────────────────────
func _state_idle() -> void:
	velocity.x = 0
	velocity.z = 0
	if player:
		_change_state(State.CHASE)

func _state_chase(delta: float) -> void:
	if not player:
		if _health_bar:
			_health_bar.reset()
		_change_state(State.IDLE)
		return

	var dist = global_position.distance_to(player.global_position)

	if dist <= detection_range and volley_timer <= 0.0:
		_change_state(State.WINDUP)
		return

	# Move directly toward player (no navigation mesh in scene)
	var target_pos = player.global_position
	var dir = (target_pos - global_position)
	dir.y = 0
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_face_direction(dir)

func _state_windup(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	if player:
		_face_target(player.global_position)

func _state_volley(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

	fork_fire_timer -= delta
	if fork_fire_timer <= 0.0 and volley_shots_fired < fork_volley_count:
		_fire_fork()
		volley_shots_fired += 1
		fork_fire_timer = fork_interval

	if volley_shots_fired >= fork_volley_count and state == State.VOLLEY:
		volley_timer = volley_cooldown
		volley_shots_fired = 0
		_begin_sprint()

func _state_sprint(_delta: float) -> void:
	var dir = (sprint_target - global_position)
	dir.y = 0
	if dir.length() < 0.5:
		_change_state(State.CHASE)
		return
	dir = dir.normalized()
	velocity.x = dir.x * sprint_speed
	velocity.z = dir.z * sprint_speed
	_face_direction(dir)

# ─── Attack Logic ────────────────────────────────────────────
func _fire_fork() -> void:
	if not fork_scene or not player:
		return

	# --- Build the beam offset list once at the start of each volley ---
	if volley_shots_fired == 0:
		_beam_offsets = _build_beam_offsets(fork_volley_count)
		# Randomise which side the whole beam curves toward each volley
		_beam_curve_sign = 1.0 if randf() > 0.5 else -1.0

	var fork = fork_scene.instantiate()
	get_tree().current_scene.add_child(fork)
	fork.global_position = fork_spawn.global_position

	# Aim toward the predicted player position
	var predicted = _predict_player_position(0.4)
	var aim_dir = (predicted - fork_spawn.global_position).normalized()

	# --- Lateral spawn offset (perpendicular to aim, in XZ) ---
	# Each fork starts from a slightly different side so they travel as a
	# swept parallel beam rather than all erupting from one point.
	var right = aim_dir.cross(Vector3.UP).normalized()
	var lateral_offset: float = _beam_offsets[volley_shots_fired]
	fork.global_position += right * lateral_offset

	# --- All forks curve the same direction this volley so the whole beam
	# sweeps together like the arcing lines in the reference image. ---
	var curve_strength: float = _beam_curve_sign * 0.25

	fork.launch(aim_dir, curve_strength)
	print_debug("Fork fired! %d/%d  lateral=%.2f  curve=%.2f" % [
		volley_shots_fired + 1, fork_volley_count, lateral_offset, curve_strength
	])

# Returns evenly-spaced lateral offsets centred on 0 so the beam brackets
# the player symmetrically.  E.g. count=5, spacing=0.35 → [-0.7,-0.35,0,0.35,0.7]
func _build_beam_offsets(count: int) -> Array:
	var spacing: float = 0.35
	var offsets: Array = []
	var half: float = (count - 1) * spacing * 0.5
	for i in range(count):
		offsets.append(i * spacing - half)
	return offsets

func _predict_player_position(time_ahead: float) -> Vector3:
	if player and player is CharacterBody3D:
		return player.global_position + player.velocity * time_ahead
	return player.global_position

func _begin_sprint() -> void:
	if not player:
		_change_state(State.CHASE)
		return
	sprint_target = _predict_player_position(0.6)
	sprint_target.y = global_position.y
	_change_state(State.SPRINT)

# ─── State Transitions ───────────────────────────────────────
func _change_state(new_state: State) -> void:
	state = new_state
	var state_name: String = State.keys()[new_state]
	print_debug("BloatedDiner state changed to: ", state_name)
	match new_state:
		State.WINDUP:
			var t = get_tree().create_timer(0.6)
			t.timeout.connect(func():
				if state == State.WINDUP:
					volley_shots_fired = 0
					fork_fire_timer = 0.0
					_change_state(State.VOLLEY)
			)
		State.DEAD:
			_die()

# ─── Damage / Health ─────────────────────────────────────────
func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	var scaled := amount * HeatManager.get_damage_multiplier()
	current_health -= scaled
	if _health_bar:
		_health_bar.show_damage(current_health, max_health)
	if current_health <= 0:
		_change_state(State.DEAD)
	else:
		_change_state(State.HURT)
		var t = get_tree().create_timer(0.3)
		t.timeout.connect(func():
			if state == State.HURT:
				_change_state(State.CHASE)
		)

func _die() -> void:
	velocity = Vector3.ZERO
	if _health_bar: _health_bar.show_dead()
	_change_state(State.DEAD)
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)

func _respawn() -> void:
	current_health = max_health
	global_position = _spawn_position
	velocity = Vector3.ZERO
	volley_timer = volley_cooldown
	volley_shots_fired = 0
	if _health_bar: _health_bar.reset()
	_change_state(State.IDLE)

# ─── Helpers ─────────────────────────────────────────────────
func _face_direction(dir: Vector3) -> void:
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)

func _face_target(target_pos: Vector3) -> void:
	var dir = (target_pos - global_position)
	dir.y = 0
	_face_direction(dir.normalized())

# ─── Detection Signals ───────────────────────────────────────
func _on_detection_area_body_entered(body: Node3D) -> void:
	print_debug("BloatedDiner: Body entered detection - %s (in player group: %s)" % [body.name, body.is_in_group("player")])
	if body.is_in_group("player"):
		player = body
		print_debug("BloatedDiner: Player detected! Changing to CHASE")
		if state == State.IDLE:
			_change_state(State.CHASE)

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = null
		if _health_bar: _health_bar.reset()
	_change_state(State.IDLE)

extends CharacterBody3D

## FrozenWaiter — Momentum-punishing enemy.
## Debug: yellow on windup, red on sweep, normal otherwise.

# ── Tuning ───────────────────────────────────────────────────────────────────
@export var patrol_speed          : float = 1.2
@export var sweep_cooldown        : float = 3.5
@export var sweep_degrees         : float = 160.0
@export var sweep_duration        : float = 1.8
@export var min_player_speed_safe : float = 4.0
@export var knockback_force       : float = 18.0
@export var tray_base_size        : Vector3 = Vector3(1.6, 0.05, 0.5)
@export var tray_expand_size      : Vector3 = Vector3(2.4, 0.2, 0.9)

# ── State ────────────────────────────────────────────────────────────────────
enum State { PATROL, TRACKING, WINDUP, SWEEPING, COOLDOWN }
var state : State = State.PATROL

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var tray_pivot  : Node3D         = $TrayPivot
@onready var tray_mesh   : MeshInstance3D = $TrayPivot/TrayMesh
@onready var tray_hitbox : Area3D         = $TrayPivot/TrayMesh/TrayHitbox
@onready var body_mesh   : MeshInstance3D = $MeshInstance3D
@onready var anim        : AnimationPlayer = $AnimationPlayer

# Grabbed after duplicate in _ready so we own the shape resource
var _tray_col   : CollisionShape3D = null
var _tray_shape : BoxShape3D       = null

# Materials
var _mat_normal : StandardMaterial3D
var _mat_windup : StandardMaterial3D
var _mat_sweep  : StandardMaterial3D

# Runtime vars
var player          : CharacterBody3D = null
var sweep_timer     : float = 0.0
var sweep_elapsed   : float = 0.0
var sweep_start_deg : float = 0.0
var sweep_direction : float = 1.0
var gravity         : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _patrol_target  : Vector3 = Vector3.ZERO
var _patrol_timer   : float   = 0.0
var _windup_timer   : float   = 0.0
const WINDUP_DURATION := 0.6

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# ── Grab & duplicate the tray collision shape so we own it ──────────────
	# CollisionShape3D is a direct child of TrayHitbox
	for child in tray_hitbox.get_children():
		if child is CollisionShape3D:
			_tray_col = child
			break
	if _tray_col:
		# Duplicate so we don't mutate the shared editor resource
		_tray_shape = _tray_col.shape.duplicate() as BoxShape3D
		_tray_shape.size = tray_base_size
		_tray_col.shape = _tray_shape

	tray_hitbox.body_entered.connect(_on_tray_hit)
	tray_hitbox.monitoring = false

	_build_materials()
	_set_color(State.PATROL)
	_new_patrol_target()
	call_deferred("_find_player")

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody3D
		sweep_timer = sweep_cooldown
		state = State.TRACKING

# ── Materials ─────────────────────────────────────────────────────────────────
func _build_materials() -> void:
	_mat_normal = StandardMaterial3D.new()
	_mat_normal.albedo_color = Color(0.85, 0.85, 0.85)

	_mat_windup = StandardMaterial3D.new()
	_mat_windup.albedo_color = Color(1.0, 0.85, 0.0)
	_mat_windup.emission_enabled = true
	_mat_windup.emission = Color(0.5, 0.3, 0.0)

	_mat_sweep = StandardMaterial3D.new()
	_mat_sweep.albedo_color = Color(1.0, 0.1, 0.0)
	_mat_sweep.emission_enabled = true
	_mat_sweep.emission = Color(0.7, 0.0, 0.0)

func _set_color(s : State) -> void:
	var mat : StandardMaterial3D = _mat_normal
	if s == State.WINDUP:   mat = _mat_windup
	elif s == State.SWEEPING: mat = _mat_sweep
	if body_mesh: body_mesh.set_surface_override_material(0, mat)
	if tray_mesh: tray_mesh.set_surface_override_material(0, mat)

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	match state:
		State.PATROL:   _patrol(delta)
		State.TRACKING: _tracking(delta)
		State.WINDUP:   _windup(delta)
		State.SWEEPING: _sweeping(delta)
		State.COOLDOWN: _cooldown(delta)
	move_and_slide()

# ── PATROL ────────────────────────────────────────────────────────────────────
func _patrol(delta: float) -> void:
	_patrol_timer -= delta
	var dir := (_patrol_target - global_position)
	dir.y = 0.0
	if dir.length() < 1.0 or _patrol_timer <= 0.0:
		_new_patrol_target()
		return
	dir = dir.normalized()
	velocity.x = dir.x * patrol_speed
	velocity.z = dir.z * patrol_speed
	_face_direction(dir, delta)

func _new_patrol_target() -> void:
	_patrol_target = global_position + Vector3(
		randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
	_patrol_timer = randf_range(3.0, 6.0)

# ── TRACKING ──────────────────────────────────────────────────────────────────
func _tracking(delta: float) -> void:
	if not is_instance_valid(player):
		state = State.PATROL
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.5:
		var dir := to_player.normalized()
		velocity.x = dir.x * patrol_speed
		velocity.z = dir.z * patrol_speed
		_face_direction(dir, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	sweep_timer -= delta
	if sweep_timer <= 0.0:
		_begin_windup()

# ── WINDUP ────────────────────────────────────────────────────────────────────
func _begin_windup() -> void:
	state         = State.WINDUP
	_windup_timer = WINDUP_DURATION
	velocity.x    = 0.0
	velocity.z    = 0.0
	if is_instance_valid(player):
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			rotation.y = atan2(to_player.x, to_player.z)
	sweep_direction = 1.0 if randf() > 0.5 else -1.0
	sweep_start_deg = -sweep_degrees * 0.5 * sweep_direction
	tray_pivot.rotation_degrees.y = sweep_start_deg
	_set_color(State.WINDUP)

func _windup(delta: float) -> void:
	velocity.x    = 0.0
	velocity.z    = 0.0
	_windup_timer -= delta
	if _windup_timer <= 0.0:
		_begin_sweep()

# ── SWEEPING ──────────────────────────────────────────────────────────────────
func _begin_sweep() -> void:
	state         = State.SWEEPING
	sweep_elapsed = 0.0
	_set_color(State.SWEEPING)
	if _tray_shape:
		_tray_shape.size = tray_expand_size
	tray_hitbox.monitoring = true

func _sweeping(delta: float) -> void:
	velocity.x     = 0.0
	velocity.z     = 0.0
	sweep_elapsed += delta
	var t   : float = clamp(sweep_elapsed / sweep_duration, 0.0, 1.0)
	var deg : float = sweep_start_deg + sweep_degrees * sweep_direction * t
	tray_pivot.rotation_degrees.y = deg
	if sweep_elapsed >= sweep_duration:
		tray_hitbox.monitoring = false
		if _tray_shape:
			_tray_shape.size = tray_base_size
		_set_color(State.PATROL)
		state       = State.COOLDOWN
		sweep_timer = sweep_cooldown

# ── COOLDOWN ──────────────────────────────────────────────────────────────────
func _cooldown(delta: float) -> void:
	velocity.x   = 0.0
	velocity.z   = 0.0
	sweep_timer -= delta
	if sweep_timer <= 0.0:
		state = State.TRACKING if is_instance_valid(player) else State.PATROL

# ── TRAY HIT ──────────────────────────────────────────────────────────────────
func _on_tray_hit(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var flat_speed := Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	if flat_speed >= min_player_speed_safe:
		return
	var away := (body.global_position - global_position)
	away.y = 0.0
	away   = away.normalized()
	away.y = 0.4
	away   = away.normalized()
	if body.has_method("add_impulse"):
		body.add_impulse(away * knockback_force)
	else:
		body.velocity = away * knockback_force
	if body.has_method("take_damage"):
		body.take_damage(1)

# ── Utility ───────────────────────────────────────────────────────────────────
func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 6.0)

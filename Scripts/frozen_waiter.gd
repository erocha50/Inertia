extends CharacterBody3D

## FrozenWaiter — Momentum-punishing enemy.
## Scene tree expected:
##   CharacterBody3D  (this script)
##   ├── MeshInstance3D
##   ├── AnimationPlayer
##   ├── DetectionArea  (Area3D)
##   │   └── CollisionShape3D
##   └── TrayPivot (Node3D)
##       └── TrayMesh (MeshInstance3D)
##           └── TrayHitbox (Area3D)
##               └── CollisionShape3D

# ── Tuning ───────────────────────────────────────────────────────────────────
@export var max_health            : float = 50.0
@export var patrol_speed          : float = 1.2
@export var chase_speed           : float = 2.8
@export var sweep_cooldown        : float = 3.5
@export var sweep_degrees         : float = 160.0
@export var sweep_duration        : float = 1.8
@export var sweep_speed_threshold : float = 4.0
@export var knockback_force       : float = 18.0
@export var detection_radius      : float = 8.0
@export var base_damage           : float = 10.0
@export var respawn_delay         : float = 5.0

@export var tray_arm_width  : float = 0.18
@export var tray_arm_height : float = 0.12
@export var tray_arm_length : float = 2.8

# ── State ────────────────────────────────────────────────────────────────────
enum State { PATROL, TRACKING, WINDUP, SWEEPING, COOLDOWN, DEAD }
var state : State = State.PATROL

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var tray_pivot     : Node3D          = $TrayPivot
@onready var tray_mesh      : MeshInstance3D  = $TrayPivot/TrayMesh
@onready var tray_hitbox    : Area3D          = $TrayPivot/TrayMesh/TrayHitbox
@onready var body_mesh      : MeshInstance3D  = $MeshInstance3D
@onready var detection_area : Area3D          = $DetectionArea

var _tray_col   : CollisionShape3D = null
var _tray_shape : BoxShape3D       = null
var _det_col    : CollisionShape3D = null

var _mat_normal : StandardMaterial3D
var _mat_windup : StandardMaterial3D
var _mat_sweep  : StandardMaterial3D
var _mat_dead   : StandardMaterial3D

var current_health  : float           = 0.0
var player          : CharacterBody3D = null
var player_detected : bool            = false
var sweep_timer     : float = 0.0
var sweep_elapsed   : float = 0.0
var sweep_start_deg : float = 0.0
var sweep_direction : float = 1.0
var gravity         : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _patrol_target  : Vector3 = Vector3.ZERO
var _patrol_timer   : float   = 0.0
var _windup_timer   : float   = 0.0
var _spawn_position : Vector3 = Vector3.ZERO
const WINDUP_DURATION := 0.6

var _health_bar: Node3D = null
var _bodies_in_tray : Array[Node3D] = []
const HIT_GRACE_SEC := 0.12
var _grace_timers   : Dictionary    = {}
var _hit_this_sweep : Array[Node3D] = []


func _ready() -> void:
	current_health  = max_health
	add_to_group("enemy")

	_spawn_position = global_position

	tray_mesh.position = Vector3(0.0, 0.0, -(tray_arm_length * 0.5))

	for child in tray_hitbox.get_children():
		if child is CollisionShape3D:
			_tray_col = child; break
	if _tray_col:
		_tray_shape        = _tray_col.shape.duplicate() as BoxShape3D
		_tray_shape.size   = Vector3(tray_arm_width, tray_arm_height, tray_arm_length)
		_tray_col.shape    = _tray_shape
		_tray_col.position = Vector3.ZERO

	tray_hitbox.body_entered.connect(_on_tray_entered)
	tray_hitbox.body_exited.connect(_on_tray_exited)
	tray_hitbox.monitoring = false

	for child in detection_area.get_children():
		if child is CollisionShape3D:
			_det_col = child; break
	if _det_col and _det_col.shape is SphereShape3D:
		(_det_col.shape as SphereShape3D).radius = detection_radius
	else:
		var s := SphereShape3D.new(); s.radius = detection_radius
		var sc := CollisionShape3D.new(); sc.shape = s
		detection_area.add_child(sc); _det_col = sc

	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	detection_area.monitoring = true

	_build_materials()
	_set_color(State.PATROL)
	_new_patrol_target()
	call_deferred("_find_player")
	_health_bar = preload("res://Scripts/EnemyHealthBar.gd").new()
	add_child(_health_bar)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody3D
	sweep_timer = sweep_cooldown
	if _health_bar: _health_bar.reset()
	state = State.PATROL


func _on_detection_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	player = body as CharacterBody3D; player_detected = true
	if state == State.PATROL or state == State.COOLDOWN:
		sweep_timer = sweep_cooldown; state = State.TRACKING


func _on_detection_exited(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	player_detected = false
	if state == State.TRACKING or state == State.COOLDOWN:
		if _health_bar: _health_bar.reset()
	state = State.PATROL


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

	_mat_dead = StandardMaterial3D.new()
	_mat_dead.albedo_color = Color(0.2, 0.2, 0.2)


func _set_color(s: State) -> void:
	var mat : StandardMaterial3D = _mat_normal
	if s == State.WINDUP:     mat = _mat_windup
	elif s == State.SWEEPING: mat = _mat_sweep
	elif s == State.DEAD:     mat = _mat_dead
	if body_mesh and body_mesh.mesh and body_mesh.mesh.get_surface_count() > 0:
		body_mesh.set_surface_override_material(0, mat)
	if tray_mesh and tray_mesh.mesh and tray_mesh.mesh.get_surface_count() > 0:
		tray_mesh.set_surface_override_material(0, mat)


func _physics_process(delta: float) -> void:
	if state == State.DEAD: return
	if not is_on_floor(): velocity.y -= gravity * delta
	match state:
		State.PATROL:   _patrol(delta)
		State.TRACKING: _tracking(delta)
		State.WINDUP:   _do_windup(delta)
		State.SWEEPING: _sweeping(delta)
		State.COOLDOWN: _cooldown(delta)
	move_and_slide()
	_tick_hitbox_sampling(delta)


func _patrol(delta: float) -> void:
	_patrol_timer -= delta
	var dir := (_patrol_target - global_position); dir.y = 0.0
	if dir.length() < 1.0 or _patrol_timer <= 0.0:
		_new_patrol_target(); return
	dir = dir.normalized()
	velocity.x = dir.x * patrol_speed; velocity.z = dir.z * patrol_speed
	_face_direction(dir, delta)


func _new_patrol_target() -> void:
	_patrol_target = global_position + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
	_patrol_timer  = randf_range(3.0, 6.0)


func _tracking(delta: float) -> void:
	if not is_instance_valid(player): state = State.PATROL; return
	if not player_detected:           state = State.PATROL; return
	var to_player := player.global_position - global_position; to_player.y = 0.0
	var dist      := to_player.length()
	if dist > 0.5:
		var dir   := to_player.normalized()
		var t: float = clamp(1.0 - dist / detection_radius, 0.0, 1.0)
		var speed: float = lerp(patrol_speed, chase_speed, t)
		velocity.x = dir.x * speed; velocity.z = dir.z * speed
		_face_direction(dir, delta)
	else:
		velocity.x = 0.0; velocity.z = 0.0
	sweep_timer -= delta
	if sweep_timer <= 0.0 and player_detected:
		var flat_spd := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
		if flat_spd <= sweep_speed_threshold: _begin_windup()
		else:                                  sweep_timer = 0.0


func _begin_windup() -> void:
	state = State.WINDUP; _windup_timer = WINDUP_DURATION
	velocity.x = 0.0; velocity.z = 0.0
	if is_instance_valid(player):
		var to_player := player.global_position - global_position; to_player.y = 0.0
		if to_player.length_squared() > 0.01: rotation.y = atan2(to_player.x, to_player.z)
		var right         := Vector3(cos(rotation.y), 0.0, -sin(rotation.y))
		sweep_direction    = -1.0 if to_player.dot(right) > 0.0 else 1.0
	sweep_start_deg               = sweep_degrees * 0.5 * sweep_direction
	tray_pivot.rotation_degrees.y = sweep_start_deg
	_set_color(State.WINDUP)


func _do_windup(delta: float) -> void:
	velocity.x = 0.0; velocity.z = 0.0
	_windup_timer -= delta
	if _windup_timer <= 0.0: _begin_sweep()


func _begin_sweep() -> void:
	state = State.SWEEPING; sweep_elapsed = 0.0
	_hit_this_sweep.clear(); _bodies_in_tray.clear(); _grace_timers.clear()
	_set_color(State.SWEEPING); tray_hitbox.monitoring = true


func _sweeping(delta: float) -> void:
	velocity.x = 0.0; velocity.z = 0.0
	sweep_elapsed += delta
	var t: float = clamp(sweep_elapsed / sweep_duration, 0.0, 1.0)
	tray_pivot.rotation_degrees.y = sweep_start_deg + sweep_degrees * sweep_direction * t
	if sweep_elapsed >= sweep_duration: _end_sweep()


func _end_sweep() -> void:
	tray_hitbox.monitoring = false
	_bodies_in_tray.clear(); _grace_timers.clear(); _hit_this_sweep.clear()
	_set_color(State.PATROL); sweep_timer = sweep_cooldown; state = State.COOLDOWN


func _cooldown(delta: float) -> void:
	if player_detected and is_instance_valid(player):
		var to_player := player.global_position - global_position; to_player.y = 0.0
		if to_player.length() > 2.0:
			var dir := to_player.normalized()
			velocity.x = dir.x * patrol_speed * 0.5; velocity.z = dir.z * patrol_speed * 0.5
			_face_direction(dir, delta)
		else:
			velocity.x = 0.0; velocity.z = 0.0
	else:
		velocity.x = 0.0; velocity.z = 0.0
	sweep_timer -= delta
	if sweep_timer <= 0.0:
		sweep_timer = sweep_cooldown
		state = State.TRACKING if (player_detected and is_instance_valid(player)) else State.PATROL


func _tick_hitbox_sampling(delta: float) -> void:
	if state != State.SWEEPING: return
	var expired : Array = []
	for body in _grace_timers.keys():
		_grace_timers[body] -= delta
		if _grace_timers[body] <= 0.0: expired.append(body)
	for body in expired: _grace_timers.erase(body)
	var candidates : Array[Node3D] = []
	for b in _bodies_in_tray:
		if is_instance_valid(b): candidates.append(b)
	for b in _grace_timers.keys():
		if is_instance_valid(b) and not candidates.has(b): candidates.append(b)
	for body in candidates:
		if not is_instance_valid(body): continue
		if not body.is_in_group("player"): continue
		if body in _hit_this_sweep: continue
		_apply_tray_hit(body)


func _on_tray_entered(body: Node3D) -> void:
	if not _bodies_in_tray.has(body): _bodies_in_tray.append(body)
	if _grace_timers.has(body):       _grace_timers.erase(body)


func _on_tray_exited(body: Node3D) -> void:
	_bodies_in_tray.erase(body)
	if state == State.SWEEPING and body.is_in_group("player"):
		_grace_timers[body] = HIT_GRACE_SEC


func _apply_tray_hit(body: Node3D) -> void:
	_hit_this_sweep.append(body)
	var away := (body.global_position - tray_pivot.global_position); away.y = 0.0
	if away.length_squared() < 0.001: away = (body.global_position - global_position); away.y = 0.0
	away = away.normalized(); away.y = 0.3; away = away.normalized()
	if body.has_method("take_knockback"): body.take_knockback(away * knockback_force)
	else:                                  body.velocity = away * knockback_force
	# Deal raw base damage (not scaled by player's heat)
	HealthManager.take_damage(base_damage)


# ── HP / Death / Respawn ──────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if state == State.DEAD: return
	# Scale incoming damage by heat multiplier
	var scaled := amount * HeatManager.get_damage_multiplier()
	current_health -= scaled
	if _health_bar:
		_health_bar.show_damage(current_health, max_health)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	state    = State.DEAD
	velocity = Vector3.ZERO
	tray_hitbox.monitoring   = false
	detection_area.monitoring = false
	_set_color(State.DEAD)
	if _health_bar: _health_bar.show_dead()
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	current_health            = max_health
	global_position           = _spawn_position
	velocity                  = Vector3.ZERO
	player_detected           = false
	sweep_timer               = sweep_cooldown
	_hit_this_sweep.clear()
	_bodies_in_tray.clear()
	_grace_timers.clear()
	tray_hitbox.monitoring    = false
	detection_area.monitoring = true
	_set_color(State.PATROL)
	_new_patrol_target()
	if _health_bar: _health_bar.reset()
	state = State.PATROL


func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.01: return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 6.0)

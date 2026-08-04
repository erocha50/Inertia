extends CharacterBody3D

## FrozenWaiterBoss — boss-tier evolution of FrozenWaiter.
## Same tray-sweep concept, but with a real combat brain: a 3-hit combo with
## its own cooldowns, a genuine vulnerable "frozen" window after the combo
## finishes, a reactive sidestep against the player's dash-attack, and full
## respect for the player's roll i-frames (checks player.is_invincible()).
##
## No AnimationPlayer / .play() calls anywhere in this script on purpose —
## there's no art yet. Every state-change comment below marks exactly where
## a real animation trigger should go once the boss's visuals (a billboard
## sprite, per the brief) are ready. Until then, the material-color swap
## from the original FrozenWaiter carries the readability.
##
## Scene tree expected (see frozen_waiter_boss.tscn):
##   CharacterBody3D                 (this script)
##   ├── CollisionShape3D            (capsule — the REAL hitbox, only ever
##   │                                 moved via `velocity` on the flat plane)
##   ├── VisualRoot (Node3D)         (cosmetic-only pivot; swap the child
##   │   └── MeshInstance3D           mesh for a Sprite3D billboard later —
##   │                                 this node is what "rotates" during a
##   │                                 sidestep, decoupled from collision)
##   ├── DetectionArea (Area3D)
##   │   └── CollisionShape3D
##   └── ComboPivot (Node3D)
##       └── TrayMesh (MeshInstance3D)
##           └── TrayHitbox (Area3D)
##               └── CollisionShape3D

# ── Tuning ───────────────────────────────────────────────────────────────────
@export var max_health            : float = 140.0
@export var patrol_speed          : float = 1.4
@export var chase_speed           : float = 3.4
@export var detection_radius      : float = 10.0
@export var melee_range           : float = 3.2   ## distance at which the boss commits to a combo
@export var knockback_force       : float = 20.0
@export var respawn_delay         : float = 6.0

@export var tray_arm_width  : float = 0.20
@export var tray_arm_height : float = 0.14
@export var tray_arm_length : float = 3.0

@export_group("3-Hit Combo")
## Windup (telegraph) time for each of the 3 hits, seconds
@export var combo_windup_times    : Array[float] = [0.45, 0.40, 0.55]
## Active swing duration for each hit, seconds
@export var combo_sweep_durations : Array[float] = [0.32, 0.32, 0.42]
## Swing arc for each hit, degrees — the 3rd hit is a wider finisher
@export var combo_sweep_degrees   : Array[float] = [130.0, 130.0, 190.0]
## Damage dealt by each hit
@export var combo_damage          : Array[float] = [8.0, 8.0, 14.0]
## Brief cooldown/reposition pause between combo hits
@export var combo_gap_duration    : float = 0.28

@export_group("Frozen Window")
## How long the boss is stunned & vulnerable after finishing the combo
@export var frozen_duration           : float = 2.2
## Damage multiplier while frozen — this is the punish window
@export var frozen_damage_multiplier  : float = 1.75
## Cooldown after unfreezing before he'll commit to another combo
@export var post_combo_cooldown_time  : float = 1.4

@export_group("Reactive Sidestep")
## Player flat speed that can trigger a sidestep reaction (tuned around the
## player's dash_attack_speed)
@export var sidestep_trigger_speed : float = 30.0
@export var sidestep_trigger_range : float = 6.0
@export var sidestep_cooldown      : float = 4.0
@export var sidestep_distance      : float = 2.5
@export var sidestep_duration      : float = 0.4
## Dramatic visual bank/bob on VisualRoot during the sidestep — the "billboard
## rotates" half of the brief. The body itself only ever translates along the
## flat plane below, so the collision hitbox can't glitch from this.
@export var visual_bank_deg   : float = 35.0
@export var visual_bob_height : float = 0.30
@export var visual_return_speed : float = 10.0

# ── State ────────────────────────────────────────────────────────────────────
enum State { PATROL, TRACKING, WINDUP, SWEEPING, COMBO_GAP, FROZEN, SIDESTEP, DEAD }
var state : State = State.PATROL

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var visual_root    : Node3D          = $VisualRoot
@onready var body_mesh      : MeshInstance3D  = $VisualRoot/MeshInstance3D
@onready var combo_pivot    : Node3D          = $ComboPivot
@onready var tray_mesh      : MeshInstance3D  = $ComboPivot/TrayMesh
@onready var tray_hitbox    : Area3D          = $ComboPivot/TrayMesh/TrayHitbox
@onready var detection_area : Area3D          = $DetectionArea

var _tray_col   : CollisionShape3D = null
var _tray_shape : BoxShape3D       = null
var _det_col    : CollisionShape3D = null

var _mat_normal : StandardMaterial3D
var _mat_windup : StandardMaterial3D
var _mat_sweep  : StandardMaterial3D
var _mat_frozen : StandardMaterial3D
var _mat_dead   : StandardMaterial3D

var current_health  : float           = 0.0
var player          : CharacterBody3D = null
var player_detected : bool            = false
var gravity         : float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _combo_index    : int   = 0
var _windup_timer   : float = 0.0
var _sweep_elapsed  : float = 0.0
var _sweep_start_deg: float = 0.0
var _sweep_direction: float = 1.0
var _gap_timer      : float = 0.0
var _frozen_timer   : float = 0.0
var _post_combo_cd  : float = 0.0

var _patrol_target  : Vector3 = Vector3.ZERO
var _patrol_timer   : float   = 0.0
var _spawn_position : Vector3 = Vector3.ZERO

var _health_bar: Node3D = null
var _bodies_in_tray : Array[Node3D] = []
const HIT_GRACE_SEC := 0.12
var _grace_timers   : Dictionary    = {}
var _hit_this_swing : Array[Node3D] = []

# Sidestep / visual juke
var _sidestep_t     : float   = 0.0
var _sidestep_dir   : Vector3 = Vector3.ZERO
var _sidestep_cd    : float   = 0.0
var _visual_base_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	current_health  = max_health
	add_to_group("enemy")
	_spawn_position = global_position

	if tray_mesh: tray_mesh.position = Vector3(0.0, 0.0, -(tray_arm_length * 0.5))
	if visual_root: _visual_base_pos = visual_root.position

	if tray_hitbox:
		for child in tray_hitbox.get_children():
			if child is CollisionShape3D:
				_tray_col = child; break
	if _tray_col:
		_tray_shape        = _tray_col.shape.duplicate() as BoxShape3D
		_tray_shape.size   = Vector3(tray_arm_width, tray_arm_height, tray_arm_length)
		_tray_col.shape    = _tray_shape
		_tray_col.position = Vector3.ZERO

	if tray_hitbox:
		tray_hitbox.body_entered.connect(_on_tray_entered)
		tray_hitbox.body_exited.connect(_on_tray_exited)
		tray_hitbox.monitoring = false

	if detection_area:
		for child in detection_area.get_children():
			if child is CollisionShape3D:
				_det_col = child; break
	if _det_col and _det_col.shape is SphereShape3D:
		(_det_col.shape as SphereShape3D).radius = detection_radius
	else:
		var s := SphereShape3D.new(); s.radius = detection_radius
		var sc := CollisionShape3D.new(); sc.shape = s
		if detection_area: detection_area.add_child(sc); _det_col = sc

	if detection_area:
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
	if _health_bar: _health_bar.reset()
	state = State.PATROL


func _on_detection_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	player = body as CharacterBody3D; player_detected = true
	if state == State.PATROL:
		state = State.TRACKING


func _on_detection_exited(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	player_detected = false
	# Mid-combo / frozen / sidestepping states are committed and finish on
	# their own — only bail out of pure tracking.
	if state == State.TRACKING:
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

	_mat_frozen = StandardMaterial3D.new()
	_mat_frozen.albedo_color = Color(0.6, 0.85, 1.0)
	_mat_frozen.emission_enabled = true
	_mat_frozen.emission = Color(0.3, 0.6, 0.9)

	_mat_dead = StandardMaterial3D.new()
	_mat_dead.albedo_color = Color(0.2, 0.2, 0.2)


func _set_color(s: State) -> void:
	var mat : StandardMaterial3D = _mat_normal
	if s == State.WINDUP:     mat = _mat_windup
	elif s == State.SWEEPING: mat = _mat_sweep
	elif s == State.FROZEN:   mat = _mat_frozen
	elif s == State.DEAD:     mat = _mat_dead
	if body_mesh and body_mesh.mesh and body_mesh.mesh.get_surface_count() > 0:
		body_mesh.set_surface_override_material(0, mat)
	if tray_mesh and tray_mesh.mesh and tray_mesh.mesh.get_surface_count() > 0:
		tray_mesh.set_surface_override_material(0, mat)
	# TODO: once the billboard sprite is in, trigger the matching state
	# animation here instead of (or alongside) the material swap.


func _physics_process(delta: float) -> void:
	if state == State.DEAD: return
	if not is_on_floor(): velocity.y -= gravity * delta
	_post_combo_cd = maxf(_post_combo_cd - delta, 0.0)
	_sidestep_cd   = maxf(_sidestep_cd - delta, 0.0)

	match state:
		State.PATROL:    _patrol(delta)
		State.TRACKING:  _tracking(delta)
		State.WINDUP:    _do_windup(delta)
		State.SWEEPING:  _sweeping(delta)
		State.COMBO_GAP: _combo_gap(delta)
		State.FROZEN:    _do_frozen(delta)
		State.SIDESTEP:  _do_sidestep(delta)

	move_and_slide()
	_tick_hitbox_sampling(delta)
	_update_visual_juke(delta)


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

	# Reactive sidestep: if the player is closing in fast (e.g. mid dash-attack)
	# and we're not already on cooldown, hop out of the charge line instead of
	# just eating it. This is the "smarter" half of the combat system.
	if _sidestep_cd <= 0.0 and dist <= sidestep_trigger_range and dist > melee_range * 0.5:
		var player_spd := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
		var closing := player.velocity.dot(-to_player.normalized()) if to_player.length_squared() > 0.01 else 0.0
		if player_spd >= sidestep_trigger_speed and closing > 0.0:
			_begin_sidestep(to_player.normalized())
			return

	if dist > 0.5:
		var dir   := to_player.normalized()
		var t: float = clamp(1.0 - dist / detection_radius, 0.0, 1.0)
		var speed: float = lerp(patrol_speed, chase_speed, t)
		velocity.x = dir.x * speed; velocity.z = dir.z * speed
		_face_direction(dir, delta)
	else:
		velocity.x = 0.0; velocity.z = 0.0

	if dist <= melee_range and _post_combo_cd <= 0.0:
		# Don't waste a combo start on a player who's already mid-dodge —
		# wait a beat rather than whiffing into a roll.
		if player.has_method("is_invincible") and player.is_invincible():
			return
		_begin_combo()


func _begin_combo() -> void:
	_combo_index = 0
	_begin_windup()


func _begin_windup() -> void:
	state = State.WINDUP
	_windup_timer = combo_windup_times[_combo_index]
	velocity.x = 0.0; velocity.z = 0.0
	if is_instance_valid(player):
		var to_player := player.global_position - global_position; to_player.y = 0.0
		if to_player.length_squared() > 0.01: rotation.y = atan2(to_player.x, to_player.z)
		var right         := Vector3(cos(rotation.y), 0.0, -sin(rotation.y))
		_sweep_direction    = -1.0 if to_player.dot(right) > 0.0 else 1.0
	_sweep_start_deg               = combo_sweep_degrees[_combo_index] * 0.5 * _sweep_direction
	combo_pivot.rotation_degrees.y = _sweep_start_deg
	_set_color(State.WINDUP)
	# TODO: trigger this hit's windup/telegraph animation here.


func _do_windup(delta: float) -> void:
	velocity.x = 0.0; velocity.z = 0.0
	_windup_timer -= delta
	if _windup_timer <= 0.0: _begin_sweep()


func _begin_sweep() -> void:
	state = State.SWEEPING; _sweep_elapsed = 0.0
	_hit_this_swing.clear(); _bodies_in_tray.clear(); _grace_timers.clear()
	_set_color(State.SWEEPING); tray_hitbox.monitoring = true
	# TODO: trigger this hit's swing animation here.


func _sweeping(delta: float) -> void:
	velocity.x = 0.0; velocity.z = 0.0
	_sweep_elapsed += delta
	var dur: float = combo_sweep_durations[_combo_index]
	var t: float = clamp(_sweep_elapsed / dur, 0.0, 1.0)
	var degrees: float = combo_sweep_degrees[_combo_index]
	combo_pivot.rotation_degrees.y = _sweep_start_deg + degrees * _sweep_direction * t
	if _sweep_elapsed >= dur: _end_swing()


func _end_swing() -> void:
	tray_hitbox.monitoring = false
	_bodies_in_tray.clear(); _grace_timers.clear(); _hit_this_swing.clear()
	_set_color(State.PATROL)

	_combo_index += 1
	if _combo_index >= combo_damage.size():
		_enter_frozen()
	else:
		state     = State.COMBO_GAP
		_gap_timer = combo_gap_duration


func _combo_gap(delta: float) -> void:
	velocity.x = 0.0; velocity.z = 0.0
	_gap_timer -= delta
	if _gap_timer <= 0.0: _begin_windup()


func _enter_frozen() -> void:
	state = State.FROZEN
	_frozen_timer = frozen_duration
	velocity.x = 0.0; velocity.z = 0.0
	_set_color(State.FROZEN)
	# TODO: trigger the "stunned/frozen" animation here — this is the boss's
	# big punish window, worth selling visually once art is in.


func _do_frozen(delta: float) -> void:
	velocity.x = 0.0; velocity.z = 0.0
	_frozen_timer -= delta
	if _frozen_timer <= 0.0:
		_set_color(State.PATROL)
		_post_combo_cd = post_combo_cooldown_time
		state = State.TRACKING if (player_detected and is_instance_valid(player)) else State.PATROL


func _begin_sidestep(to_player_dir: Vector3) -> void:
	state = State.SIDESTEP
	_sidestep_t  = 0.0
	_sidestep_cd = sidestep_cooldown
	# Step perpendicular to the incoming charge, not straight back.
	var perp := to_player_dir.cross(Vector3.UP).normalized()
	if perp.length_squared() < 0.01: perp = Vector3(1, 0, 0)
	_sidestep_dir = perp * (1.0 if randf() < 0.5 else -1.0)
	_face_direction(to_player_dir, 1.0)
	# TODO: trigger a quick sidestep/flinch animation here.


func _do_sidestep(delta: float) -> void:
	_sidestep_t += delta
	var t: float = clamp(_sidestep_t / sidestep_duration, 0.0, 1.0)
	var eased: float = t * t * (3.0 - 2.0 * t)
	var target_spd: float = sidestep_distance / sidestep_duration
	# Real movement stays flat-plane only (x/z via velocity) — this is the
	# "collision hitbox only follows the flat axis" half of the brief.
	velocity.x = _sidestep_dir.x * target_spd * (1.0 - eased)
	velocity.z = _sidestep_dir.z * target_spd * (1.0 - eased)
	if t >= 1.0:
		velocity.x = 0.0; velocity.z = 0.0
		state = State.TRACKING if (player_detected and is_instance_valid(player)) else State.PATROL


## Dramatic visual-only sidestep juke, applied to VisualRoot only — the
## future billboard's rotation + arc. The CharacterBody3D/CollisionShape3D
## above is never touched here, so the real hitbox can't glitch from it.
func _update_visual_juke(delta: float) -> void:
	if not visual_root: return
	if state == State.SIDESTEP:
		var t: float = clamp(_sidestep_t / sidestep_duration, 0.0, 1.0)
		var arch: float = sin(PI * t)
		var side_dot := _sidestep_dir.dot(visual_root.global_transform.basis.x)
		var side: float = signf(side_dot) if absf(side_dot) > 0.05 else 1.0
		visual_root.rotation.z = deg_to_rad(visual_bank_deg) * side * arch
		visual_root.position.y = _visual_base_pos.y + visual_bob_height * arch
	else:
		visual_root.rotation.z = lerpf(visual_root.rotation.z, 0.0, visual_return_speed * delta)
		visual_root.position.y = lerpf(visual_root.position.y, _visual_base_pos.y, visual_return_speed * delta)


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
		if body in _hit_this_swing: continue
		_apply_tray_hit(body)


func _on_tray_entered(body: Node3D) -> void:
	if not _bodies_in_tray.has(body): _bodies_in_tray.append(body)
	if _grace_timers.has(body):       _grace_timers.erase(body)


func _on_tray_exited(body: Node3D) -> void:
	_bodies_in_tray.erase(body)
	if state == State.SWEEPING and body.is_in_group("player"):
		_grace_timers[body] = HIT_GRACE_SEC


func _apply_tray_hit(body: Node3D) -> void:
	_hit_this_swing.append(body)

	# Respect the player's roll i-frames — this is the "combat compatible
	# with the new dodging mechanism" requirement. A player mid-roll takes
	# no damage and no knockback from this swing.
	if body.has_method("is_invincible") and body.is_invincible():
		return

	var away := (body.global_position - combo_pivot.global_position); away.y = 0.0
	if away.length_squared() < 0.001: away = (body.global_position - global_position); away.y = 0.0
	away = away.normalized(); away.y = 0.3; away = away.normalized()
	if body.has_method("take_knockback"): body.take_knockback(away * knockback_force)
	else:                                  body.velocity = away * knockback_force
	HealthManager.take_damage(combo_damage[_combo_index])


# ── HP / Death / Respawn ──────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if state == State.DEAD: return
	var mult := HeatManager.get_damage_multiplier()
	if state == State.FROZEN:
		mult *= frozen_damage_multiplier  # the punish window
	var scaled := amount * mult
	current_health -= scaled
	if _health_bar:
		_health_bar.show_damage(current_health, max_health)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	state    = State.DEAD
	velocity = Vector3.ZERO
	tray_hitbox.monitoring    = false
	detection_area.monitoring = false
	_set_color(State.DEAD)
	if _health_bar: _health_bar.show_dead()
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	current_health  = max_health
	global_position = _spawn_position
	velocity         = Vector3.ZERO
	player_detected  = false
	_combo_index     = 0
	_post_combo_cd   = 0.0
	_sidestep_cd     = 0.0
	_hit_this_swing.clear()
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

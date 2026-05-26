class_name SculleryHorror
extends CharacterBody3D

# ════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ════════════════════════════════════════════════════════════════════════════

@export_group("Speed")
@export var speed_mirror          : float = 1.05  # multiplier on the player's current speed cap
@export var speed_min             : float = 8.0   # never slower than this
@export var rage_speed_boost      : float = 1.30
@export var fear_speed_scale      : float = 0.70

@export_group("Detection")
@export var vision_range          : float = 28.0
@export var vision_angle_deg      : float = 110.0
@export var hearing_range         : float = 18.0

@export_group("Chase")
@export var preferred_distance    : float = 3.5
@export var give_up_time          : float = 6.0

@export_group("Momentum")
@export var turn_speed            : float = 2.2   # radians/sec — how fast it can steer (lower = more car-like)
@export var acceleration          : float = 14.0  # how fast it reaches top speed
@export var friction              : float = 5.0   # how fast it slows when not thrusting (coasting drag)

@export_group("Search & Memory")
@export var search_duration       : float = 8.0
@export var search_wander_radius  : float = 5.0

@export_group("Fake Intelligence")
@export var fake_pause_chance     : float = 0.04
@export var fake_pause_duration   : float = 0.35

@export_group("Health")
@export var max_health            : float = 60.0
@export var rage_health_threshold : float = 0.35
@export var fear_health_threshold : float = 0.15

@export_group("Pack / Spread")
@export var pack_spread_radius    : float = 4.0

# ════════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ════════════════════════════════════════════════════════════════════════════

enum State { IDLE, HUNT, SEARCH, HURT, DEAD }
var state : State = State.IDLE

# ════════════════════════════════════════════════════════════════════════════
# NODE REFS
# ════════════════════════════════════════════════════════════════════════════

var _body_mesh      : MeshInstance3D = null
var _detection_area : Area3D         = null

# ════════════════════════════════════════════════════════════════════════════
# RUNTIME
# ════════════════════════════════════════════════════════════════════════════

var _gravity          : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player            : CharacterBody3D = null
var current_health    : float = 0.0

var last_seen_pos     : Vector3 = Vector3.ZERO
var has_last_seen     : bool    = false
var _no_sight_timer   : float   = 0.0   # counts up while player not visible

var _hurt_timer       : float = 0.0
var _search_timer     : float = 0.0
var _search_target    : Vector3 = Vector3.ZERO
var _search_picks     : int     = 0

var _fake_pause_timer : float = 0.0
var _fake_pausing     : bool  = false

var _heading          : Vector3 = Vector3.FORWARD  # current committed travel direction
var _siblings         : Array = []

# ════════════════════════════════════════════════════════════════════════════
# INIT
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	current_health = max_health
	rotation.x     = 0.0
	rotation.z     = 0.0
	_body_mesh      = get_node_or_null(^"MeshInstance3D") as MeshInstance3D
	_detection_area = get_node_or_null(^"DetectionArea") as Area3D

	if _detection_area == null:
		push_error("SculleryHorror: DetectionArea child node not found.")

	_build_material()
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody3D

	_siblings = []
	for n in get_tree().get_nodes_in_group("scullery_horror"):
		if n != self:
			_siblings.append(n)
	add_to_group("scullery_horror")

	# Initialise heading from whichever way we're facing at spawn
	_heading = -global_transform.basis.z
	_heading.y = 0.0
	_heading = _heading.normalized() if _heading.length_squared() > 0.01 else Vector3.FORWARD

	state = State.HUNT

# ════════════════════════════════════════════════════════════════════════════
# PHYSICS
# ════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	# Stay upright always
	rotation.x = 0.0
	rotation.z = 0.0

	# Re-acquire player if lost
	if not is_instance_valid(player):
		var p := get_tree().get_nodes_in_group("player")
		if p.size() > 0:
			player = p[0] as CharacterBody3D

	# Gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Fake pause (only while searching, for atmosphere)
	if state == State.SEARCH and not _fake_pausing and randf() < fake_pause_chance * delta:
		_fake_pausing     = true
		_fake_pause_timer = fake_pause_duration

	if _fake_pausing:
		_fake_pause_timer -= delta
		if _fake_pause_timer <= 0.0:
			_fake_pausing = false
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	match state:
		State.IDLE:   _state_idle()
		State.HUNT:   _state_hunt(delta)
		State.SEARCH: _state_search(delta)
		State.HURT:   _state_hurt(delta)

	move_and_slide()

# ════════════════════════════════════════════════════════════════════════════
# SPEED
# ════════════════════════════════════════════════════════════════════════════

func _get_speed() -> float:
	var spd : float = speed_min

	if is_instance_valid(player):
		# Read the player's live ramped speed cap (_max_spd), fall back to speed_max
		var raw_cur : Variant = player.get("_max_spd")
		var raw_max : Variant = player.get("speed_max")
		var p_cur   : float   = float(raw_cur) if raw_cur != null else (float(raw_max) if raw_max != null else 40.0)
		spd = maxf(p_cur * speed_mirror, speed_min)

	var hp : float = current_health / max_health
	if hp <= rage_health_threshold:
		spd *= rage_speed_boost
	elif hp <= fear_health_threshold:
		spd *= fear_speed_scale

	return spd

# ════════════════════════════════════════════════════════════════════════════
# STATES
# ════════════════════════════════════════════════════════════════════════════

func _state_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	# If we have a player, just go hunt
	if is_instance_valid(player):
		state = State.HUNT


func _state_hunt(delta: float) -> void:
	if not is_instance_valid(player):
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Vision check — can we see the player right now?
	var to_player : Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist : float = to_player.length()

	var can_see : bool = false
	if dist > 0.01:
		var forward   : Vector3 = -global_transform.basis.z
		forward.y = 0.0
		var angle_deg : float = rad_to_deg(forward.angle_to(to_player.normalized()))
		can_see = angle_deg <= vision_angle_deg * 0.5

	if can_see or dist < vision_range:
		# Keep updating last known position whenever we have any awareness
		last_seen_pos   = player.global_position
		has_last_seen   = true
		_no_sight_timer = 0.0
	else:
		_no_sight_timer += delta
		if _no_sight_timer >= give_up_time:
			_start_search()
			return

	# Always move toward player (or last known pos) unless already on top of them
	var target : Vector3 = player.global_position
	if dist <= preferred_distance:
		_coast(delta)
		return

	_move_toward(target, _get_speed(), delta)


func _start_search() -> void:
	state         = State.SEARCH
	_search_timer = search_duration
	_search_picks = 0
	_no_sight_timer = 0.0
	_pick_search_point()


func _state_search(delta: float) -> void:
	# If we spot the player again, resume hunt immediately
	if is_instance_valid(player):
		var to_p : Vector3 = player.global_position - global_position
		to_p.y = 0.0
		if to_p.length() < vision_range:
			var forward : Vector3 = -global_transform.basis.z
			forward.y = 0.0
			var angle_deg : float = rad_to_deg(forward.angle_to(to_p.normalized()))
			if angle_deg <= vision_angle_deg * 0.5 or to_p.length() < preferred_distance * 2.0:
				state = State.HUNT
				return

	_search_timer -= delta
	if _search_timer <= 0.0:
		state = State.IDLE
		return

	if global_position.distance_to(_search_target) < 1.2:
		_pick_search_point()
	else:
		_move_toward(_search_target, _get_speed() * 0.55, delta)


func _pick_search_point() -> void:
	_search_picks += 1
	var origin : Vector3 = last_seen_pos if (has_last_seen and _search_picks <= 3) else global_position
	_search_target = origin + Vector3(
		randf_range(-search_wander_radius, search_wander_radius),
		0.0,
		randf_range(-search_wander_radius, search_wander_radius))


func _state_hurt(delta: float) -> void:
	_coast(delta)
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		state = State.HUNT

# ════════════════════════════════════════════════════════════════════════════
# MOVEMENT HELPERS
# ════════════════════════════════════════════════════════════════════════════

func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var to_target : Vector3 = target - global_position
	to_target.y = 0.0

	var desired_dir : Vector3
	if to_target.length() > 0.1:
		desired_dir = to_target.normalized()
	else:
		# Already on target — coast to a stop
		_coast(delta)
		return

	# Pack spread — nudge heading away from siblings
	var push : Vector3 = Vector3.ZERO
	for s in _siblings:
		var sib := s as SculleryHorror
		if not is_instance_valid(sib):
			continue
		var to_sib : Vector3 = global_position - sib.global_position
		to_sib.y = 0.0
		var d : float = to_sib.length()
		if d < pack_spread_radius and d > 0.01:
			push += to_sib.normalized() * (1.0 - d / pack_spread_radius)
	if push.length_squared() > 0.01:
		desired_dir = (desired_dir + push.normalized() * 0.3).normalized()

	# Rotate heading toward desired direction at turn_speed — this is the car feel
	_heading = _heading.rotated(Vector3.UP,
		clampf(_heading.signed_angle_to(desired_dir, Vector3.UP),
			-turn_speed * delta,
			 turn_speed * delta))
	_heading = _heading.normalized()

	# Accelerate flat speed toward target speed along committed heading
	var flat     : Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var cur_spd  : float   = flat.length()
	var new_spd  : float   = minf(cur_spd + acceleration * delta, speed)
	velocity.x = _heading.x * new_spd
	velocity.z = _heading.z * new_spd

	# Face the way we're actually travelling
	rotation.y = lerp_angle(rotation.y, atan2(_heading.x, _heading.z), delta * 8.0)


func _coast(delta: float) -> void:
	# Bleed speed off without snapping to zero
	var flat    : Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var new_spd : float   = maxf(flat.length() - friction * delta, 0.0)
	if new_spd > 0.01:
		velocity.x = _heading.x * new_spd
		velocity.z = _heading.z * new_spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0

# ════════════════════════════════════════════════════════════════════════════
# DAMAGE / DEATH
# ════════════════════════════════════════════════════════════════════════════

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	current_health -= amount
	if current_health <= 0.0:
		_die()
		return
	state       = State.HURT
	_hurt_timer = 0.35
	if is_instance_valid(player):
		for s in _siblings:
			var sib := s as SculleryHorror
			if is_instance_valid(sib):
				sib._alert(player.global_position)


func _alert(pos: Vector3) -> void:
	if state == State.IDLE or state == State.SEARCH:
		last_seen_pos = pos
		has_last_seen = true
		state         = State.HUNT


func _die() -> void:
	state    = State.DEAD
	velocity = Vector3.ZERO
	for s in _siblings:
		var sib := s as SculleryHorror
		if is_instance_valid(sib):
			sib._siblings.erase(self)
	get_tree().create_timer(1.2).timeout.connect(queue_free)


func notify_sound(world_pos: Vector3, loudness: float = 1.0) -> void:
	if state == State.DEAD:
		return
	var dist : float = global_position.distance_to(world_pos)
	if dist <= hearing_range * loudness:
		last_seen_pos = world_pos
		has_last_seen = true
		state         = State.HUNT

# ════════════════════════════════════════════════════════════════════════════
# VISUALS
# ════════════════════════════════════════════════════════════════════════════

func _build_material() -> void:
	if _body_mesh == null:
		return
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color     = Color(1.0, 0.4, 0.2)
	mat.emission_enabled = true
	mat.emission         = Color(0.7, 0.2, 0.0)
	_body_mesh.set_surface_override_material(0, mat)

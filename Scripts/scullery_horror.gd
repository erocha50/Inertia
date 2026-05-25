class_name SculleryHorror
extends CharacterBody3D

# ════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ════════════════════════════════════════════════════════════════════════════

@export_group("Speed")
@export var speed_min_mirror      : float = 1.05
@export var speed_max_mirror      : float = 0.95
@export var rage_speed_boost      : float = 1.30
@export var fear_speed_scale      : float = 0.70

@export_group("Detection")
@export var vision_range          : float = 28.0
@export var vision_angle_deg      : float = 110.0
@export var hearing_range         : float = 18.0
@export var suspicion_rate        : float = 1.8
@export var suspicion_decay_rate  : float = 0.6
@export var suspicion_threshold   : float = 1.0

@export_group("Chase & Predict")
@export var preferred_distance    : float = 3.5
@export var predicted_lead_base   : float = 0.30
@export var predicted_lead_max    : float = 0.75
@export var intercept_speed_thresh: float = 16.0

@export_group("Flank & Cutoff")
@export var flank_distance        : float = 6.0
@export var flank_angle_speed     : float = 2.0
@export var cutoff_trigger_speed  : float = 20.0

@export_group("Search & Memory")
@export var search_duration       : float = 8.0
@export var search_wander_radius  : float = 5.0

@export_group("Ambush & Stalker")
@export var ambush_distance       : float = 0.0
@export var stalk_distance        : float = 0.0
@export var stalk_to_attack_range : float = 7.0

@export_group("Pack / Spread")
@export var pack_spread_radius    : float = 4.0

@export_group("Adaptive AI")
@export var adapt_sample_interval : float = 2.0
@export var adapt_lead_adjust     : float = 0.06

@export_group("Herding")
@export var herd_targets          : Array[NodePath] = []

@export_group("Fake Intelligence")
@export var fake_pause_chance     : float = 0.04
@export var fake_pause_duration   : float = 0.35

@export_group("Health")
@export var max_health            : float = 60.0
@export var rage_health_threshold : float = 0.35
@export var fear_health_threshold : float = 0.15

# ════════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ════════════════════════════════════════════════════════════════════════════

enum State {
	IDLE, SUSPICIOUS, STALK, AMBUSH,
	HUNT, FLANK, INTERCEPT, SEARCH,
	HURT, DEAD
}

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
var suspicion         : float = 0.0
var player_in_cone    : bool  = false
var last_seen_pos     : Vector3 = Vector3.ZERO
var has_last_seen     : bool    = false

var _hurt_timer       : float = 0.0
var _search_timer     : float = 0.0
var _intercept_cd     : float = 0.0
var _fake_pause_timer : float = 0.0
var _fake_pausing     : bool  = false
var _flank_angle      : float = 0.0
var _search_target    : Vector3 = Vector3.ZERO
var _adapt_timer      : float = 0.0
var _last_dodge_dir   : Vector3 = Vector3.ZERO
var _adaptive_lead    : float = 0.0
var _siblings         : Array = []
var _herd_nodes       : Array = []

# ════════════════════════════════════════════════════════════════════════════
# INIT
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	current_health  = max_health
	_body_mesh      = get_node_or_null(^"MeshInstance3D") as MeshInstance3D
	_detection_area = get_node_or_null(^"DetectionArea") as Area3D

	if _detection_area == null:
		push_error("SculleryHorror: DetectionArea child node not found.")
	else:
		for c in _detection_area.get_children():
			var col := c as CollisionShape3D
			if col == null:
				continue
			var sph := col.shape as SphereShape3D
			if sph != null:
				sph.radius = vision_range

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

	_herd_nodes = []
	for np in herd_targets:
		var n : Node = get_node_or_null(np)
		if n != null:
			_herd_nodes.append(n)

	if is_instance_valid(player):
		var d := global_position.distance_to(player.global_position)
		if ambush_distance > 0.0 and d > ambush_distance:
			state = State.AMBUSH
		elif stalk_distance > 0.0 and d > stalk_distance:
			state = State.STALK
		else:
			state     = State.HUNT
			suspicion = suspicion_threshold
	else:
		state = State.HUNT

# ════════════════════════════════════════════════════════════════════════════
# PHYSICS
# ════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	# Re-find player every frame until valid
	if not is_instance_valid(player):
		var p := get_tree().get_nodes_in_group("player")
		if p.size() > 0:
			player = p[0] as CharacterBody3D
			if is_instance_valid(player) and state == State.IDLE:
				state     = State.HUNT
				suspicion = suspicion_threshold

	if not is_on_floor():
		velocity.y -= _gravity * delta

	_intercept_cd = maxf(_intercept_cd - delta, 0.0)
	_update_vision(delta)

	_adapt_timer += delta
	if _adapt_timer >= adapt_sample_interval:
		_adapt_timer = 0.0
		_sample_player_pattern()

	if not _fake_pausing and randf() < fake_pause_chance * delta:
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
		State.IDLE:        _state_idle()
		State.SUSPICIOUS:  _state_suspicious(delta)
		State.STALK:       _state_stalk(delta)
		State.AMBUSH:      _state_ambush(delta)
		State.HUNT:        _state_hunt(delta)
		State.FLANK:       _state_flank(delta)
		State.INTERCEPT:   _state_intercept(delta)
		State.SEARCH:      _state_search(delta)
		State.HURT:        _state_hurt(delta)

	move_and_slide()

# ════════════════════════════════════════════════════════════════════════════
# SPEED
# ════════════════════════════════════════════════════════════════════════════

func _get_chase_speed() -> float:
	if not is_instance_valid(player):
		return 5.0

	var p_min : float = 10.0
	var p_max : float = 40.0

	var raw_min : Variant = player.get("speed_min")
	var raw_max : Variant = player.get("speed_max")
	if raw_min != null:
		p_min = float(raw_min)
	if raw_max != null:
		p_max = float(raw_max)

	var my_min : float = p_min * speed_min_mirror
	var my_max : float = p_max * speed_max_mirror
	var p_flat : float = _player_flat_speed()
	var t      : float = clampf((p_flat - p_min) / maxf(p_max - p_min, 1.0), 0.0, 1.0)
	var speed  : float = lerpf(my_min, my_max, t)

	var hp : float = current_health / max_health
	if hp < rage_health_threshold:
		speed *= rage_speed_boost
	elif hp < fear_health_threshold:
		speed *= fear_speed_scale

	return speed


func _player_flat_speed() -> float:
	if not is_instance_valid(player):
		return 0.0
	if player.has_method("get_flat_speed"):
		return player.get_flat_speed()
	return Vector3(player.velocity.x, 0.0, player.velocity.z).length()

# ════════════════════════════════════════════════════════════════════════════
# VISION + HEARING
# ════════════════════════════════════════════════════════════════════════════

func _update_vision(delta: float) -> void:
	if not is_instance_valid(player):
		player_in_cone = false
		return

	var to_player : Vector3 = player.global_position - global_position
	var dist      : float   = to_player.length()
	var forward   : Vector3 = -global_transform.basis.z

	player_in_cone = false

	if dist <= vision_range and dist > 0.01:
		var angle_deg : float = rad_to_deg(forward.angle_to(to_player.normalized()))
		if angle_deg <= vision_angle_deg * 0.5:
			player_in_cone = true

	if player_in_cone:
		suspicion     = minf(suspicion + suspicion_rate * delta, 1.0)
		last_seen_pos = player.global_position
		has_last_seen = true
	else:
		suspicion = maxf(suspicion - suspicion_decay_rate * delta, 0.0)

	match state:
		State.IDLE:
			if suspicion > 0.0:
				state = State.SUSPICIOUS
		State.SUSPICIOUS:
			if suspicion >= suspicion_threshold:
				_on_fully_detected()
			elif suspicion <= 0.0:
				state = State.IDLE
		State.STALK, State.AMBUSH:
			if suspicion >= suspicion_threshold:
				_on_fully_detected()
		State.HUNT, State.FLANK, State.INTERCEPT:
			if suspicion <= 0.0 and has_last_seen:
				_start_search()


func _on_fully_detected() -> void:
	for s in _siblings:
		var sib := s as SculleryHorror
		if is_instance_valid(sib):
			sib._receive_alert(player.global_position)
	state = State.HUNT


func _receive_alert(pos: Vector3) -> void:
	if state == State.IDLE or state == State.SUSPICIOUS:
		last_seen_pos = pos
		has_last_seen = true
		suspicion     = suspicion_threshold
		state         = State.HUNT


func notify_sound(world_pos: Vector3, loudness: float = 1.0) -> void:
	if state == State.DEAD:
		return
	var dist : float = global_position.distance_to(world_pos)
	if dist <= hearing_range * loudness:
		last_seen_pos = world_pos
		has_last_seen = true
		if state == State.IDLE or state == State.SUSPICIOUS:
			suspicion = minf(suspicion + 0.5 * loudness, 1.0)
			if suspicion >= suspicion_threshold:
				_on_fully_detected()
			else:
				state = State.SUSPICIOUS

# ════════════════════════════════════════════════════════════════════════════
# PREDICTION
# ════════════════════════════════════════════════════════════════════════════

func _predicted_player_pos() -> Vector3:
	if not is_instance_valid(player):
		return global_position

	var p_flat  : Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var p_speed : float   = p_flat.length()
	var p_max   : float   = 40.0
	var raw     : Variant = player.get("speed_max")
	if raw != null:
		p_max = float(raw)

	var t_norm  : float   = clampf(p_speed / maxf(p_max, 1.0), 0.0, 1.0)
	var lead    : float   = lerpf(predicted_lead_base, predicted_lead_max, t_norm) + _adaptive_lead
	var result  : Vector3 = player.global_position + p_flat * lead
	result.y = global_position.y
	return result


func _sample_player_pattern() -> void:
	if not is_instance_valid(player):
		return
	var flat    : Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var cur_dir : Vector3 = flat.normalized()
	if _last_dodge_dir.length_squared() > 0.01:
		var dot : float = cur_dir.dot(_last_dodge_dir)
		if dot < -0.6:
			_adaptive_lead = clampf(_adaptive_lead + adapt_lead_adjust, 0.0, 0.4)
		else:
			_adaptive_lead = maxf(_adaptive_lead - adapt_lead_adjust * 0.5, 0.0)
	_last_dodge_dir = cur_dir

# ════════════════════════════════════════════════════════════════════════════
# STEERING
# ════════════════════════════════════════════════════════════════════════════

func _herd_steering() -> Vector3:
	if _herd_nodes.is_empty() or not is_instance_valid(player):
		return Vector3.ZERO
	var best_dist : float   = -1.0
	var best_pos  : Vector3 = Vector3.ZERO
	for n in _herd_nodes:
		var node := n as Node3D
		if not is_instance_valid(node):
			continue
		var d : float = player.global_position.distance_to(node.global_position)
		if best_dist < 0.0 or d < best_dist:
			best_dist = d
			best_pos  = node.global_position
	if best_dist < 0.0:
		return Vector3.ZERO
	var to_herd : Vector3 = best_pos - player.global_position
	to_herd.y = 0.0
	if to_herd.length_squared() < 0.01:
		return Vector3.ZERO
	var flank_pos : Vector3 = player.global_position - to_herd.normalized() * preferred_distance * 1.5
	flank_pos.y = global_position.y
	var to_flank : Vector3 = flank_pos - global_position
	to_flank.y = 0.0
	return to_flank.normalized()


func _pack_spread_steering() -> Vector3:
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
		return push.normalized()
	return Vector3.ZERO


func _move_toward(target: Vector3, speed: float, delta: float,
		pack_w: float = 0.35, herd_w: float = 0.25) -> void:
	var to_target : Vector3 = target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.15:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir : Vector3 = to_target.normalized()
	var spread : Vector3 = _pack_spread_steering()
	if spread.length_squared() > 0.01:
		dir = (dir + spread * pack_w).normalized()
	var herd : Vector3 = _herd_steering()
	if herd.length_squared() > 0.01:
		dir = (dir + herd * herd_w).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_dir(dir, delta)


func _face_dir(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 8.0)

# ════════════════════════════════════════════════════════════════════════════
# SEARCH
# ════════════════════════════════════════════════════════════════════════════

func _start_search() -> void:
	state         = State.SEARCH
	_search_timer = search_duration
	_pick_search_point()


func _pick_search_point() -> void:
	if has_last_seen:
		_search_target = last_seen_pos + Vector3(
			randf_range(-search_wander_radius, search_wander_radius),
			0.0,
			randf_range(-search_wander_radius, search_wander_radius))
	else:
		_search_target = global_position

# ════════════════════════════════════════════════════════════════════════════
# STATES
# ════════════════════════════════════════════════════════════════════════════

func _state_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _state_suspicious(delta: float) -> void:
	if has_last_seen:
		var slow : float = _get_chase_speed() * 0.35
		var to_t : Vector3 = last_seen_pos - global_position
		to_t.y = 0.0
		if to_t.length() > 1.0:
			_move_toward(last_seen_pos, slow, delta)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _state_stalk(delta: float) -> void:
	if not is_instance_valid(player):
		state = State.IDLE
		return
	var dist : float = global_position.distance_to(player.global_position)
	if dist <= stalk_to_attack_range:
		state = State.HUNT
		return
	var spd : float = _get_chase_speed() * 0.50
	if dist < stalk_distance * 0.85:
		var away : Vector3 = global_position - player.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			var dir : Vector3 = away.normalized()
			velocity.x = dir.x * spd * 0.5
			velocity.z = dir.z * spd * 0.5
			_face_dir(-dir, delta)
	else:
		_move_toward(_predicted_player_pos(), spd, delta)


func _state_ambush(delta: float) -> void:
	if not is_instance_valid(player):
		return
	velocity.x = 0.0
	velocity.z = 0.0
	var to_p : Vector3 = player.global_position - global_position
	to_p.y = 0.0
	_face_dir(to_p.normalized(), delta)
	if global_position.distance_to(player.global_position) <= stalk_distance:
		state = State.STALK


func _state_hunt(delta: float) -> void:
	if not is_instance_valid(player):
		state = State.IDLE
		return

	var speed  : float = _get_chase_speed()
	var pspeed : float = _player_flat_speed()
	var dist   : float = global_position.distance_to(player.global_position)

	if dist < preferred_distance:
		_start_flanking()
		return

	if pspeed > cutoff_trigger_speed and _intercept_cd <= 0.0:
		var predicted : Vector3 = _predicted_player_pos()
		var to_pred   : Vector3 = predicted - global_position
		to_pred.y = 0.0
		if to_pred.length() < vision_range * 0.7:
			state         = State.INTERCEPT
			_intercept_cd = 3.0
			return

	if dist < flank_distance * 1.4 and pspeed > 3.0:
		_start_flanking()
		return

	_move_toward(_predicted_player_pos(), speed, delta)


func _start_flanking() -> void:
	state = State.FLANK
	if is_instance_valid(player):
		var to_p : Vector3 = player.global_position - global_position
		var sign : float = 1.0 if randf() > 0.5 else -1.0
		_flank_angle = atan2(to_p.x, to_p.z) + randf_range(PI * 0.4, PI * 0.9) * sign
	else:
		_flank_angle = randf_range(0.0, TAU)


func _state_flank(delta: float) -> void:
	if not is_instance_valid(player) or suspicion < suspicion_threshold * 0.5:
		state = State.HUNT
		return

	var speed  : float = _get_chase_speed()
	var pspeed : float = _player_flat_speed()
	_flank_angle += flank_angle_speed * delta

	var circle_pos : Vector3 = player.global_position + Vector3(
		cos(_flank_angle) * flank_distance,
		0.0,
		sin(_flank_angle) * flank_distance)
	circle_pos.y = global_position.y

	_move_toward(circle_pos, speed, delta, 0.2, 0.2)

	var dist : float = global_position.distance_to(player.global_position)
	if dist > flank_distance * 2.5 or pspeed < 1.5:
		state = State.HUNT


func _state_intercept(delta: float) -> void:
	if not is_instance_valid(player) or suspicion < suspicion_threshold * 0.5:
		state = State.HUNT
		return
	var burst : float = _get_chase_speed() * 1.15
	_move_toward(_predicted_player_pos(), burst, delta, 0.1, 0.1)
	var dist : float = global_position.distance_to(player.global_position)
	if dist < preferred_distance or _player_flat_speed() < intercept_speed_thresh * 0.5:
		state = State.HUNT


func _state_search(delta: float) -> void:
	_search_timer -= delta
	if _search_timer <= 0.0:
		has_last_seen = false
		state         = State.IDLE
		return
	var spd : float = _get_chase_speed() * 0.55
	if global_position.distance_to(_search_target) < 1.2:
		_pick_search_point()
	else:
		_move_toward(_search_target, spd, delta, 0.1, 0.0)


func _state_hurt(delta: float) -> void:
	velocity.x   = 0.0
	velocity.z   = 0.0
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		state = State.HUNT if suspicion >= suspicion_threshold else State.SEARCH

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
				sib._receive_alert(player.global_position)


func _die() -> void:
	state    = State.DEAD
	velocity = Vector3.ZERO
	for s in _siblings:
		var sib := s as SculleryHorror
		if is_instance_valid(sib):
			sib._siblings.erase(self)
	get_tree().create_timer(1.2).timeout.connect(queue_free)

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

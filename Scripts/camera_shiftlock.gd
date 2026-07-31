extends Node3D

@export_group("Mouse")
@export var sensitivity_x:float=0.20; @export var sensitivity_y:float=0.18
@export var max_yaw_delta_deg:float=6.0

@export_group("Vertical")
@export var pitch_min:float=-70.0; @export var pitch_max:float=60.0

@export_group("Orbital Arm")
@export var arm_length:float=6.0;    @export var pivot_height_offset:float=1.6
@export var arm_min:float=1.5;       @export var arm_max:float=14.0
@export var arm_zoom_smooth:float=10.0; @export var arm_speed_pullback:float=2.5
@export var arm_lookahead:float=1.8
@export var pitch_ground_factor:float=0.55

@export_group("Shoulder")
@export var shoulder_base:float=2.2
@export var shoulder_lean_sweep:float=2.80
@export var shoulder_turn_shift:float=1.2
@export var shoulder_smooth:float=6.0
@export var shoulder_y_drop_max:float=0.80

@export_group("Spring Damper")
@export var spring_h:float=14.0; @export var spring_v:float=8.0
@export var lag_yaw_factor:float=0.08

@export_group("Speed Resistance")
@export var resistance_start:float=8.0; @export var resistance_max:float=40.0
@export var min_turn_ratio:float=0.15

@export_group("Auto Recentre")
@export var recentre_delay:float=2.0; @export var recentre_speed:float=2.5

@export_group("FOV")
@export var fov_base:float=75.0; @export var fov_max:float=100.0; @export var fov_smooth:float=6.0

@export_group("Lean")
@export var roll_max_deg:float=22.0;   @export var roll_smooth:float=5.5
@export var roll_buildup_rate:float=3.0; @export var roll_drain_rate:float=4.5
@export var moto_pitch_max:float=35.0; @export var moto_pitch_rate:float=5.0
@export var lean_arm_pull:float=1.8

@export_group("Vertical Feel")
@export var fall_pitch_bias:float=6.0; @export var fall_pitch_speed:float=10.0
@export var land_pitch_kick:float=4.0

@export_group("Running Shake")
@export var run_shake_max:float=0.55;  @export var run_shake_speed:float=40.0
@export var run_shake_freq:float=9.0;  @export var topspeed_shake_bonus:float=0.40

@export_group("Impact Shake")
@export var shake_max_deg:float=3.5;   @export var shake_idle_floor:float=0.08
@export var shake_frequency:float=26.0; @export var shake_attack:float=18.0
@export var shake_decay:float=10.0;    @export var shake_full_yaw_rate:float=3.5
@export var impact_shake_deg:float=3.8; @export var impact_decay:float=16.0

@export_group("Wall Hit")
@export var wall_hit_trauma:float=5.0; @export var wall_pitch_kick:float=3.5

@export_group("Collision")
@export var collision_enabled:bool=true; @export var collision_radius:float=0.2

@export_group("Speed Lines")
@export var lines_start_speed:float=8.0; @export var lines_max_speed:float=28.0
@export var line_count:int=52; @export var line_color:Color=Color(1,1,1,0.85)

@export_group("Follow")
@export var character_path:NodePath=^".."

@export_group("Wall Ride Camera")
@export var wall_tilt_enabled:bool=true
@export var wall_tilt_angle:float=20.0
@export var wall_tilt_smooth:float=8.0

@export_group("Wallhop Assist Camera")
@export var wallhop_fov_assist:float=5.0
@export var wallhop_arm_closer:float=1.5; @export var wallhop_arm_smooth:float=6.0

@export_group("Lock-On")
@export var lock_on_range:float = 18.0
@export var lock_on_break_range_multiplier:float = 2.0
@export var lock_on_acquire_fov_deg:float = 60.0
@export var lock_on_orbit_speed:float = 7.0
@export var lock_on_aim_height:float = 1.0
@export var lock_on_min_flat_dist:float = 4.0
@export var lock_on_arm_back:float = 3.0



# ── Speed Lines ───────────────────────────────────────────────────────────────
class _SpeedLineControl extends Control:
## Over-the-shoulder camera — right-shoulder, locked shiftlock.
## Player sits on the LEFT side of screen, camera on the right looking in.
## Very slight vertical freelook "float" for cinematic feel.

@export_group("Shoulder Positioning")
## Horizontal distance from character center to camera
@export var shoulder_offset:float = 2.8
## How far the camera is behind the character
@export var arm_length:float = 1.5
## Height of the camera pivot above the character's feet
@export var camera_height:float = 2.0
## Extra vertical offset on top of camera_height
@export var height_above_shoulder:float = 0.6

@export_group("Framing")
## How many degrees to rotate the camera RIGHT after centering on player.
## Larger = player sits further LEFT on screen (cinematic framing).
@export var aim_horizontal_deg:float = 30.0
## How high above the player's center the camera aims
@export var aim_vertical_offset:float = 1.5

@export_group("Mouse")
@export var sensitivity_x:float = 0.18
@export var sensitivity_y:float = 0.16
@export var pitch_min:float = -30.0
@export var pitch_max:float = 25.0

@export_group("Vertical Freelook Float")
## How much the camera floats up/down with pitch (0 = none, 1 = full arm-length)
@export var vertical_float_scale:float = 0.15
## How snappy the float follows pitch
@export var vertical_float_speed:float = 5.0

@export_group("Smoothing")
## How quickly the camera follows the character yaw
@export var yaw_smooth_speed:float = 8.0
## Spring bounce when turning — higher = more overshoot
@export var yaw_spring_stiffness:float = 20.0
## Damping for the yaw spring — lower = more bounce
@export var yaw_spring_damping:float = 4.0
## How quickly pitch catches up
@export var pitch_smooth_speed:float = 10.0

@export_group("FOV")
@export var fov_base:float = 75.0
@export var fov_max:float = 90.0
@export var fov_smooth:float = 6.0

@export_group("Running Shake")
@export var run_shake_max:float = 0.35
@export var run_shake_speed:float = 40.0
@export var run_shake_freq:float = 9.0

@export_group("Impact Shake")
@export var shake_max_deg:float = 3.0
@export var shake_frequency:float = 26.0
@export var shake_decay:float = 10.0
@export var impact_shake_deg:float = 3.5
@export var impact_decay:float = 16.0

@export_group("Collision")
@export var collision_enabled:bool = true
@export var collision_radius:float = 0.2

@export_group("Speed Lines")
@export var lines_start_speed:float = 8.0
@export var lines_max_speed:float = 28.0
@export var line_count:int = 52
@export var line_color:Color = Color(1, 1, 1, 0.85)

@export_group("Follow")
@export var character_path:NodePath = ^".."

@export_group("Lock-On")
## Max distance to acquire a target with middle-mouse
@export var lock_on_range:float = 18.0
## Target is dropped once it's this many times farther than lock_on_range
@export var lock_on_break_range_multiplier:float = 2.0
## How wide a cone in front of the camera counts when acquiring a target
@export var lock_on_acquire_fov_deg:float = 60.0
## How quickly the camera orbit turns to keep facing the locked target as
## the player moves around it (sun/earth — the target is the anchor, the
## camera swings to track it, not the player's own facing).
@export var lock_on_orbit_speed:float = 7.0
## Vertical offset added to the target's origin so we aim at its body/center, not its feet
@export var lock_on_aim_height:float = 1.0
## Floor for the horizontal distance used when computing lock-on pitch.
## Without this, pitch angle blows up as you close in on the target
## (same height difference / shrinking horizontal distance = steep angle).
@export var lock_on_min_flat_dist:float = 4.0
## How far behind the player the camera sits when locked on (overrides
## arm_length). The camera flips to behind the player so looking at the
## enemy keeps both in frame.
@export var lock_on_arm_back:float = 3.0

# ── State ─────────────────────────────────────────────────────────────────────
var _target_yaw:float
var _smooth_yaw:float
var _yaw_velocity:float
var _pitch:float
var _smooth_pitch:float
var _character:CharacterBody3D
var _camera:Camera3D
var _current_speed:float
var _max_spd:float = 40.0

# For vertical float freelook
var _current_float_offset:float = 0.0
var _target_float_offset:float = 0.0

# Shake state
var _shake_target:float
var _shake_smooth:float
var _shake_time:float
var _impact_trauma:float
var _run_shake_time:float
var _prev_strain:float
var _yaw_delta:float
var _recentre_timer:float = 0.0

# Speed lines
var _line_ctrl:_SpeedLineControl
var _space:PhysicsDirectSpaceState3D

# Lock-on
var _lock_target:Node3D = null
var _lock_orbit_yaw:float = 0.0


func _ready() -> void:
	_character = get_node(character_path)
	_camera = $Camera3D

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Initialise yaw from the character's facing direction
	_target_yaw = rad_to_deg(_character.rotation.y)
	_smooth_yaw = _target_yaw
	_smooth_pitch = _pitch
	_lock_orbit_yaw = _smooth_yaw

	_apply_orbital_transform()
	_build_speed_lines()

	# Connect signals
	for sig in [
		["speed_changed", _on_speed_changed],
		["turn_strain", _on_turn_strain],
		["landed", _on_landed],
		["dash_performed", _on_dash],
		["dash_attack_performed", _on_dash_attack],
		["wall_hit", _on_wall_hit],
	]:
		if _character.has_signal(sig[0]):
			_character.connect(sig[0], sig[1])


func _on_speed_changed(flat:float, mx:float) -> void:
	_current_speed = flat
	_max_spd = mx


func _on_turn_strain(strain:float) -> void:
	if strain > 0.55 and _prev_strain < 0.35:
		_impact_trauma = maxf(_impact_trauma, impact_shake_deg * strain)
	_prev_strain = strain


func _on_landed(impact:float) -> void:
	_impact_trauma = maxf(_impact_trauma, impact_shake_deg * clampf(impact / 30.0, 0.0, 1.0))


func _on_dash() -> void:
	_impact_trauma = maxf(_impact_trauma, impact_shake_deg * 0.4)


func _on_dash_attack() -> void:
	_impact_trauma = maxf(_impact_trauma, impact_shake_deg * 1.2)


func _on_wall_hit(_wall_normal:Vector3, impact_speed:float) -> void:
	var t := clampf(impact_speed / maxf(_max_spd, 1.0), 0.0, 1.0)
	_impact_trauma = maxf(_impact_trauma, 4.0 * t)


func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		if _lock_target != null:
			_lock_target = null
		else:
			_acquire_lock_target()
		return

	if event is InputEventMouseMotion:
		# Mouse moves the character's yaw directly (shiftlock always on)
		var speed_t: float = clampf((_current_speed - 8.0) / (40.0 - 8.0), 0.0, 1.0)
		var h: float = sensitivity_x * lerpf(1.0, 0.15, speed_t * speed_t)

		var raw: float = -event.relative.x * h
		_target_yaw += raw
		_yaw_delta += absf(raw)

		# Pitch updates the FLOAT target — camera drifts up/down subtly
		var pitch_raw: float = event.relative.y * sensitivity_y
		_target_float_offset += pitch_raw * vertical_float_scale
		_target_float_offset = clampf(_target_float_offset, -0.5, 0.5)

		# Pitch also directly changes the look angle
		_pitch = clampf(_pitch + pitch_raw, pitch_min, pitch_max)
		_recentre_timer = 0.0


func _process(delta:float) -> void:
	_space = get_world_3d().direct_space_state

	if _lock_target != null and not _is_lock_target_valid():
		_lock_target = null

	# The lock-on orbit yaw is the ENEMY tracking the player like a sun —
	# it's recomputed from the character-to-target direction every frame
	# and smoothly turned toward, independent of mouse/_target_yaw. This is
	# what the camera actually orbits and aims around while locked, so it
	# keeps facing the target no matter how the player moves around it.
	if _lock_target != null and is_instance_valid(_lock_target):
		var to_target: Vector3 = _lock_target.global_position - _character.global_position
		to_target.y = 0.0
		if to_target.length() > 0.01:
			var desired_orbit_yaw := rad_to_deg(atan2(-to_target.x, -to_target.z))
			var orbit_diff := wrapf(desired_orbit_yaw - _lock_orbit_yaw, -180.0, 180.0)
			_lock_orbit_yaw += orbit_diff * clampf(lock_on_orbit_speed * delta, 0.0, 1.0)
	else:
		_lock_orbit_yaw = _smooth_yaw

	var spd_t := clampf(_current_speed / _max_spd, 0.0, 1.0)

	# Spring-damper for yaw — overshoots slightly on sharp turns for a
	# natural cinematic bounce without affecting XY position tracking.
	var yaw_diff: float = _target_yaw - _smooth_yaw
	# Normalise angle difference to [-180, 180]
	if yaw_diff > 180.0:
		yaw_diff -= 360.0
	elif yaw_diff < -180.0:
		yaw_diff += 360.0
	_yaw_velocity += yaw_diff * yaw_spring_stiffness * delta
	_yaw_velocity *= maxf(1.0 - yaw_spring_damping * delta, 0.0)
	_smooth_yaw += _yaw_velocity * delta

	_smooth_pitch = lerpf(_smooth_pitch, _pitch, pitch_smooth_speed * delta)

	# Smooth the vertical float offset
	_current_float_offset = lerpf(_current_float_offset, _target_float_offset,
		vertical_float_speed * delta)

	# Rotate character to match camera yaw
	# When locked on, the player faces the target (lock_on orbit yaw),
	# not the mouse-driven yaw — so the player and camera both face the enemy.
	var is_locked := _lock_target != null and is_instance_valid(_lock_target)
	var char_yaw_deg := _lock_orbit_yaw if is_locked else _target_yaw
	_character.global_transform.basis = _character.global_transform.basis.slerp(
		Basis(Vector3.UP, deg_to_rad(char_yaw_deg)),
		minf(delta * 20.0, 1.0)
	)

	# Apply transforms
	_apply_orbital_transform(
		_compute_impact_shake(delta) + _compute_run_shake(delta, spd_t),
		spd_t
	)

	_yaw_delta = 0.0

	# FOV
	_camera.fov = lerpf(_camera.fov, lerpf(fov_base, fov_max, spd_t * spd_t), fov_smooth * delta)

	# Speed lines
	_line_ctrl.set_intensity(clampf((_current_speed - lines_start_speed) / (lines_max_speed - lines_start_speed), 0.0, 1.0) ** 3)

	# If there's no input for a while, gently drift float offset back to center
	_recentre_timer += delta
	if _recentre_timer > 2.0:
		_target_float_offset = lerpf(_target_float_offset, 0.0, 2.0 * delta)


func _acquire_lock_target() -> void:
	var cam_fwd:Vector3 = -_camera.global_transform.basis.z
	var best:Node3D = null
	var best_score:float = -1.0
	var fov_cos := cos(deg_to_rad(lock_on_acquire_fov_deg * 0.5))

	for n in get_tree().get_nodes_in_group("enemy"):
		if not (n is Node3D):
			continue
		if "current_health" in n and n.current_health <= 0.0:
			continue
		var to_target: Vector3 = n.global_position - global_position
		var dist := to_target.length()
		if dist < 0.01 or dist > lock_on_range:
			continue
		var dir := to_target / dist
		var facing := dir.dot(cam_fwd)
		if facing < fov_cos:
			continue
		# Prefer targets closer to the center of view; distance is a tiebreaker
		var score := facing - dist * 0.01
		if score > best_score:
			best_score = score
			best = n

	_lock_target = best


func _is_lock_target_valid() -> bool:
	if _lock_target == null or not is_instance_valid(_lock_target):
		return false
	if "current_health" in _lock_target and _lock_target.current_health <= 0.0:
		return false
	if global_position.distance_to(_lock_target.global_position) > lock_on_range * lock_on_break_range_multiplier:
		return false
	return true


func is_locked_on() -> bool:
	return _lock_target != null


func get_lock_target() -> Node3D:
	return _lock_target


func _apply_orbital_transform(shake:Vector2 = Vector2.ZERO, _spd_t:float = 0.0) -> void:
	var is_locked := _lock_target != null and is_instance_valid(_lock_target)

	# While locked, the rig orbits around the TARGET-facing yaw (sun/earth —
	# the enemy is the anchor, the camera swings to keep tracking it) instead
	# of the mouse-driven character yaw. This is what makes the shoulder
	# framing keep the enemy in view as the player circles around it.
	var orbit_yaw_deg := _lock_orbit_yaw if is_locked else _smooth_yaw
	var yaw_rad := deg_to_rad(orbit_yaw_deg + shake.x)

	# ── Position ────────────────────────────────────────────────────────────
	# Camera pivot at character center height
	var char_pos := _character.global_position + Vector3(0.0, camera_height, 0.0)

	# Right direction (perpendicular to facing) — pushes camera to right shoulder
	var right_vec := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad)) * shoulder_offset

	# Back direction: normally pushes the camera slightly in front of the player
	# (so the over-the-shoulder framing looks back at the player). When locked,
	# flip it behind the player so looking at the enemy keeps the player in frame.
	var back_vec: Vector3
	if is_locked:
		# Behind the player (reverse of the normal direction)
		back_vec = Vector3(sin(yaw_rad), 0.0, cos(yaw_rad)) * lock_on_arm_back
	else:
		back_vec = Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad)) * arm_length

	# Target camera position: to the right of + behind the character
	var target_pos := char_pos + right_vec + back_vec
	# Add height above shoulder + the subtle freelook float offset
	target_pos.y += height_above_shoulder + _current_float_offset

	# Collision check
	if collision_enabled and _space != null:
		var p := PhysicsRayQueryParameters3D.new()
		p.from = char_pos
		p.to = target_pos
		p.exclude = [_character.get_rid()]
		p.collision_mask = 1
		var hit := _space.intersect_ray(p)
		if hit:
			target_pos = char_pos + (target_pos - char_pos).normalized() * \
				maxf(char_pos.distance_to(hit.position) - collision_radius, collision_radius)

	global_position = target_pos

	# ── Look / Aim ──────────────────────────────────────────────────────────
	# When locked on, look directly at the target so the enemy stays centered.
	# Otherwise, use the over-the-shoulder framing (rotate camera→player
	# direction right by the framing angle) so the player appears on the left.
	
	var up_vec := Vector3.UP
	
	if is_locked:
		# Look at a point between the player and the enemy so both stay in frame.
		# The player is to the left/right of camera (shoulder offset), and the
		# enemy is in front — this blend keeps the player visible while centered
		# on the fight.
		var player_center := _character.global_position + Vector3(0.0, aim_vertical_offset, 0.0)
		var enemy_center := _lock_target.global_position + Vector3(0.0, lock_on_aim_height, 0.0)
		var look_at_pos := player_center.lerp(enemy_center, 0.65)
		_camera.look_at(look_at_pos, up_vec)
	else:
		# Normal framing: look at player offset by framing angle so the
		# player appears on the LEFT side of the screen.
		var to_player: Vector3 = _character.global_position - global_position
		var to_player_horiz := Vector3(to_player.x, 0.0, to_player.z).normalized()
		
		var framing_rad := deg_to_rad(aim_horizontal_deg)
		var cos_a := cos(framing_rad)
		var sin_a := sin(framing_rad)
		var look_dir_horiz := Vector3(
			to_player_horiz.x * cos_a - to_player_horiz.z * sin_a,
			0.0,
			to_player_horiz.x * sin_a + to_player_horiz.z * cos_a
		)
		
		# Mouse-driven pitch
		var pitch_rad := deg_to_rad(_smooth_pitch + shake.y * 0.3)
		var look_dir := Vector3(
			look_dir_horiz.x * cos(pitch_rad),
			sin(pitch_rad),
			look_dir_horiz.z * cos(pitch_rad)
		).normalized()
		
		var look_target := global_position + look_dir * 100.0
		_camera.look_at(look_target, up_vec)


func _compute_impact_shake(delta:float) -> Vector2:
	_shake_smooth = lerpf(_shake_smooth, _shake_target,
		(18.0 if _shake_target > _shake_smooth else shake_decay) * delta)
	_impact_trauma = maxf(_impact_trauma - impact_decay * delta, 0.0)
	var total := clampf(_shake_smooth + _impact_trauma / maxf(shake_max_deg, 0.001), 0.0, 1.0)
	if total < 0.004:
		return Vector2.ZERO
	_shake_time += delta * shake_frequency
	var t := _shake_time
	var nx := sin(t) * 0.5 + sin(t * 2.3 + 1.1) * 0.3 + sin(t * 5.1 + 2.7) * 0.2
	var ny := sin(t + 0.8) * 0.5 + sin(t * 2.7 + 3.2) * 0.3 + sin(t * 4.9 + 0.5) * 0.2
	var mag := shake_max_deg * (total * total)
	return Vector2(nx * mag, ny * mag * 0.55)


func _compute_run_shake(delta:float, spd_t:float) -> Vector2:
	if _current_speed < 1.0:
		return Vector2.ZERO
	_run_shake_time += delta * run_shake_freq * lerpf(0.6, 1.0, spd_t)
	var amp := clampf(_current_speed / run_shake_speed, 0.0, 1.0) * run_shake_max
	return Vector2(
		sin(_run_shake_time * 0.5 + 0.8) * amp * 0.3,
		sin(_run_shake_time) * amp * 0.6
	)


func _build_speed_lines() -> void:
	var c := CanvasLayer.new()
	c.layer = 10
	add_child(c)
	_line_ctrl = _SpeedLineControl.new()
	_line_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(_line_ctrl)
	_line_ctrl.setup(line_count, line_color)


func get_movement_basis() -> Array:
	var yr := deg_to_rad(_target_yaw)
	return [
		Vector3(-sin(yr), 0, -cos(yr)),
		Vector3(cos(yr), 0, -sin(yr))
	]


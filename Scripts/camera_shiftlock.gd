extends Node3D

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


func _ready() -> void:
	_character = get_node(character_path)
	_camera = $Camera3D

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Initialise yaw from the character's facing direction
	_target_yaw = rad_to_deg(_character.rotation.y)
	_smooth_yaw = _target_yaw
	_smooth_pitch = _pitch

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
	_character.global_transform.basis = _character.global_transform.basis.slerp(
		Basis(Vector3.UP, deg_to_rad(_target_yaw)),
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


func _apply_orbital_transform(shake:Vector2 = Vector2.ZERO, _spd_t:float = 0.0) -> void:
	var yaw_rad := deg_to_rad(_smooth_yaw + shake.x)

	# ── Position ────────────────────────────────────────────────────────────
	# Camera pivot at character center height
	var char_pos := _character.global_position + Vector3(0.0, camera_height, 0.0)

	# Right direction (perpendicular to facing) — pushes camera to right shoulder
	var right_vec := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad)) * shoulder_offset

	# Back direction (behind the character)
	var back_vec := Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad)) * arm_length

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
	# Compute the camera's look direction: rotate the vector from camera
	# to player RIGHT by the framing angle, then pitch up/down.
	#
	# This guarantees the player appears LEFT of center on screen.
	
	var up_vec := Vector3.UP
	
	# Direction from camera to player (horizontal only)
	var to_player: Vector3 = _character.global_position - global_position
	var to_player_horiz := Vector3(to_player.x, 0.0, to_player.z).normalized()
	
	# Rotate RIGHT around UP by framing angle
	var framing_rad := deg_to_rad(aim_horizontal_deg)
	var cos_a := cos(framing_rad)
	var sin_a := sin(framing_rad)
	var look_dir_horiz := Vector3(
		to_player_horiz.x * cos_a - to_player_horiz.z * sin_a,
		0.0,
		to_player_horiz.x * sin_a + to_player_horiz.z * cos_a
	)
	
	# Add pitch (vertical component)
	var pitch_rad := deg_to_rad(_smooth_pitch + shake.y * 0.3)
	var look_dir := Vector3(
		look_dir_horiz.x * cos(pitch_rad),
		sin(pitch_rad),
		look_dir_horiz.z * cos(pitch_rad)
	).normalized()
	
	# Compute look target far away in the look direction
	# Look at a point 100m in the look direction from camera position
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


# ── Speed Lines ───────────────────────────────────────────────────────────────
class _SpeedLineControl extends Control:
	var _intensity:float
	var _time:float
	var _angles:PackedFloat32Array
	var _lengths:PackedFloat32Array
	var _offsets:PackedFloat32Array
	var _speeds:PackedFloat32Array
	var _widths:PackedFloat32Array
	var _col:Color
	var _n:int

	func setup(count:int, col:Color) -> void:
		_n = count
		_col = col
		_angles.resize(count)
		_lengths.resize(count)
		_offsets.resize(count)
		_speeds.resize(count)
		_widths.resize(count)
		var r := RandomNumberGenerator.new()
		r.randomize()
		for i in count:
			_angles[i] = r.randf_range(0, TAU)
			_lengths[i] = r.randf_range(0.18, 0.52)
			_offsets[i] = r.randf_range(0.10, 0.90)
			_speeds[i] = r.randf_range(1.4, 3.8)
			_widths[i] = r.randf_range(2.0, 5.5)

	func set_intensity(t:float) -> void:
		_intensity = t
		queue_redraw()

	func _process(delta:float) -> void:
		if _intensity > 0.001:
			_time += delta * (1.2 + _intensity * 3.2)
			queue_redraw()

	func _draw() -> void:
		if _intensity < 0.001:
			return
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var diag := Vector2(cx, cy).length()
		for i in _n:
			var off := fmod(_offsets[i] + _time * _speeds[i] * 0.28 * _intensity, 1.0)
			var ds := diag * off
			var de := diag * minf(off + _lengths[i] * _intensity, 1.10)
			var dir := Vector2(cos(_angles[i]), sin(_angles[i]))
			var alpha := _col.a * _intensity * smoothstep(0.10, 0.45, off)
			draw_line(
				Vector2(cx, cy) + dir * ds,
				Vector2(cx, cy) + dir * de,
				Color(_col.r, _col.g, _col.b, alpha),
				_widths[i] * (0.5 + _intensity * 0.8)
			)

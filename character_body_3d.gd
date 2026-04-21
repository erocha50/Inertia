extends CharacterBody3D

# ─── Nodes ─────────────────────────────────────────────────────────────────────
@export var hud_path: NodePath = ^"../HUD"    # CanvasLayer or Control node
@export var mesh_path: NodePath = ^"Visual"   # Node3D used for visual tilt

# ─── Speed ─────────────────────────────────────────────────────────────────────
@export var top_speed: float     = 18.0
@export var acceleration: float  = 14.0
@export var deceleration: float  = 22.0
@export var friction: float      = 18.0       # Applied when no input

# ─── Turning ───────────────────────────────────────────────────────────────────
@export var turn_speed: float    = 8.0

# ─── Air ───────────────────────────────────────────────────────────────────────
@export var gravity: float           = 30.0
@export var jump_force: float        = 12.0
@export var air_acceleration: float  = 6.0
@export var air_deceleration: float  = 4.0

# ─── Feel ──────────────────────────────────────────────────────────────────────
@export var slope_influence: float   = 0.4
@export var min_slide_speed: float   = 1.0    # Below this speed, full stop

# ─── Tilt (velocity-driven lean) ───────────────────────────────────────────────
@export_group("Tilt")
@export var tilt_max: float          = 18.0   # Max lean angle in degrees
@export var tilt_ref_speed: float    = 18.0   # Speed at which full tilt is reached
@export var tilt_smooth: float       = 10.0   # How quickly tilt catches up

# ─── Input Tilt (WASD lean) ────────────────────────────────────────────────────
@export_group("Input Tilt")
@export var input_tilt_max: float    = 8.0    # Extra lean from raw left/right input
@export var input_tilt_smooth: float = 6.0

# ─── Momentum / Turn Limiting ──────────────────────────────────────────────────
@export_group("Momentum")
@export var momentum_resistance: float  = 0.92  # How much momentum fights steering at top speed
@export var momentum_full_speed: float  = 14.0  # Speed at which full resistance kicks in

# ─── Direction Brake (snap prevention) ─────────────────────────────────────────
@export_group("Direction Brake")
@export var dir_brake_time: float       = 0.18  # Seconds of braking when reversing hard
@export var dir_brake_min_speed: float  = 5.0   # Only triggers above this speed
@export var dir_flip_threshold: float   = 100.0 # Angle (degrees) that triggers the brake
@export var dir_brake_bleed: float      = 0.92  # Speed decay per frame during brake

# ─── Signals ───────────────────────────────────────────────────────────────────
signal speed_changed(flat_speed: float, max_speed: float)
signal state_changed(new_state: String)
signal landed(impact_speed: float)

# ─── Internal ──────────────────────────────────────────────────────────────────
var speed: float            = 0.0
var move_direction: Vector3 = Vector3.ZERO

var _hud: Node
var _mesh: Node3D
var _air_vel_y: float = 0.0
var _input_tilt: float = 0.0

# Direction brake state
var _brake_timer: float     = 0.0
var _brake_target_dir: Vector3 = Vector3.ZERO


func _ready() -> void:
	if has_node(hud_path):
		_hud = get_node(hud_path)
		if _hud.has_method("on_speed_changed"):
			speed_changed.connect(_hud.on_speed_changed)
		if _hud.has_method("on_state_changed"):
			state_changed.connect(_hud.on_state_changed)
		if _hud.has_method("on_landed"):
			landed.connect(_hud.on_landed)

	if has_node(mesh_path):
		_mesh = get_node(mesh_path) as Node3D


func get_input_direction() -> Vector3:
	var raw := Vector3.ZERO
	raw.x = Input.get_axis("move_left", "move_right")
	raw.z = Input.get_axis("move_forward", "move_back")

	if raw.length_squared() < 0.01:
		return Vector3.ZERO

	var cam := get_viewport().get_camera_3d()
	if cam:
		var forward := -cam.global_transform.basis.z
		var right   :=  cam.global_transform.basis.x
		forward.y = 0.0
		right.y   = 0.0
		forward   = forward.normalized()
		right     = right.normalized()
		return (forward * -raw.z + right * raw.x).normalized()

	return Vector3(raw.x, 0.0, raw.z).normalized()


func get_slope_factor() -> float:
	if not is_on_floor():
		return 0.0
	var floor_normal: Vector3 = get_floor_normal()
	var slope_dir := Vector3(move_direction.x, 0.0, move_direction.z).normalized()
	var alignment := floor_normal.dot(slope_dir)
	return -alignment * slope_influence


func update_rotation(delta: float) -> void:
	if move_direction.length_squared() < 0.01:
		return
	var target_angle := atan2(move_direction.x, move_direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)


# Returns a [0..1] momentum resistance factor based on current speed.
func _momentum_resist() -> float:
	var t := clampf((speed - 0.0) / maxf(momentum_full_speed, 0.01), 0.0, 1.0)
	return lerpf(0.0, momentum_resistance, t * t)


func apply_floor_movement(delta: float, input_dir: Vector3) -> void:
	var has_input := input_dir.length_squared() > 0.01
	var flat := Vector3(velocity.x, 0.0, velocity.z)

	if not has_input:
		speed = move_toward(speed, 0.0, friction * delta)
		_brake_timer = 0.0
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
		return

	# ── Direction snap prevention ──────────────────────────────────────────────
	# Measure the angle between where we're going and where the player wants to go.
	var ang := 0.0
	if flat.length() > 0.1:
		ang = rad_to_deg(flat.normalized().angle_to(input_dir))

	# If the player hard-reverses above the threshold speed, engage the brake.
	if ang >= dir_flip_threshold and speed >= dir_brake_min_speed and _brake_timer <= 0.0:
		_brake_timer = dir_brake_time
		_brake_target_dir = input_dir

	# While braking: bleed speed and block normal acceleration until either
	# the timer expires or we slow down enough to switch cleanly.
	if _brake_timer > 0.0:
		_brake_timer = maxf(_brake_timer - delta, 0.0)
		speed *= pow(1.0 - dir_brake_bleed, delta * 60.0)
		if speed < 1.5 or _brake_timer <= 0.0:
			_brake_timer = 0.0
			move_direction = _brake_target_dir
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
		return

	# ── Normal movement with momentum-weighted steering ────────────────────────
	# Resistance makes the character less responsive to sudden input at high speed.
	var resist := _momentum_resist()
	var eff_accel := acceleration * lerpf(1.0, 1.0 - resist * 0.55, resist)

	var dot := velocity.normalized().dot(input_dir)
	if dot < -0.2:
		# Moving against input: harder decel at high speed
		speed = move_toward(speed, 0.0, deceleration * lerpf(2.0, 1.2, resist) * delta)
	else:
		speed = move_toward(speed, top_speed, eff_accel * delta)
		# Gradually steer move_direction toward input — faster at low speed, sluggish at high
		var steer_rate := lerpf(turn_speed, turn_speed * 0.25, resist)
		move_direction = move_direction.slerp(input_dir, steer_rate * delta).normalized()

	speed += get_slope_factor() * delta * speed
	speed  = clampf(speed, 0.0, top_speed)
	if speed < min_slide_speed and not has_input:
		speed = 0.0

	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed


func apply_air_movement(delta: float, input_dir: Vector3) -> void:
	if input_dir.length_squared() > 0.01:
		# Air steering is always limited — no brake logic in the air
		move_direction = move_direction.slerp(input_dir, (turn_speed * 0.15) * delta).normalized()
		speed = move_toward(speed, top_speed, air_acceleration * delta)
	else:
		speed = move_toward(speed, 0.0, air_deceleration * delta)

	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed


func _update_mesh_tilt(delta: float) -> void:
	if _mesh == null:
		return

	var fv := Vector3(velocity.x, 0.0, velocity.z)

	# Velocity-driven lateral lean: positive = leaning right into a left turn
	var lat   := fv.dot(_mesh.global_transform.basis.x)
	var spd_t := clampf(fv.length() / tilt_ref_speed, 0.0, 1.0)
	var vel_tilt := clampf(
		-sign(lat) * absf(lat) / maxf(fv.length(), 0.01) * deg_to_rad(tilt_max) * spd_t,
		-deg_to_rad(tilt_max), deg_to_rad(tilt_max)
	)

	# Input-driven lean: raw horizontal input adds a small extra lean
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var target_input_tilt := deg_to_rad(input_tilt_max) * raw.x
	_input_tilt = lerpf(_input_tilt, target_input_tilt, input_tilt_smooth * delta)

	_mesh.rotation.z = lerpf(_mesh.rotation.z, vel_tilt + _input_tilt, tilt_smooth * delta)


func _physics_process(delta: float) -> void:
	var input_dir := get_input_direction()

	if is_on_floor():
		if _air_vel_y < -0.1:
			landed.emit(absf(_air_vel_y))
			state_changed.emit("LANDED")
		_air_vel_y = 0.0

		apply_floor_movement(delta, input_dir)

		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force
			state_changed.emit("AIR")
	else:
		_air_vel_y = velocity.y
		velocity.y -= gravity * delta
		apply_air_movement(delta, input_dir)

	update_rotation(delta)
	move_and_slide()
	_update_mesh_tilt(delta)

	var flat_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	speed_changed.emit(flat_speed, top_speed)

	if is_on_floor():
		state_changed.emit("RUN" if flat_speed > 0.5 else "IDLE")
	else:
		state_changed.emit("AIR")

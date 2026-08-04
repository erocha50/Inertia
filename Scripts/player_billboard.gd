extends AnimatedSprite3D
## Manages the player billboard sprite — idle, walk, and jump animations.
## Uses a tiny state machine keyed off the parent's state_changed signal.
## SpriteFrames speed is 1.0 for all animations; speed_scale = actual FPS.
##
## Jump sequence (from idle): prepare_jump_from_idle → jump_fall_start → jump_fall_mid (loop) → jump_fall_to_idle
## Jump sequence (from run):  jump_fall_start → jump_fall_mid (loop) → jump_fall_to_run

enum BillboardState {
	IDLE,        ## idle animation, looping
	WALK,        ## walk animation, looping, speed varies with flat speed
	PREPARE_JUMP,## single-frame transition when jumping from idle
	JUMP_START,  ## single-frame "jump to fall start", then falls into JUMP_FALL loop
	JUMP_FALL,   ## mid-air loop: cycles mid1/mid2
	LAND_TO_RUN, ## single-frame landing from a run
	LAND_TO_IDLE,## single-frame landing from idle
	WALL_RUN,    ## wall run loop: cycles wr1/wr2/wr3/wr4
	DASH,        ## dash burst, single frame
	DASH_LAND,   ## landing from dash
	DODGE,       ## dodge animation with three frames
}

@export var idle_fps: float = 4.0
@export var walk_min_fps: float = 4.0
@export var walk_max_fps: float = 12.0
@export var min_move_speed: float = 0.5
@export var jump_fps: float = 8.0
@export var dash_duration: float = 2.0       ## seconds the "dash" anim plays for
@export var dash_land_duration: float = 0.2  ## seconds the "dash_land" anim plays for

var _bb_state := BillboardState.IDLE
var _current_speed: float
var _max_speed: float = 40.0
var _player: CharacterBody3D
var _last_ground_state: int = 0    ## 0 = IDLE, 1 = RUN (captured only when on floor)
var _anim_finished_cb: Callable   ## cleared on every state switch
func _ready() -> void:
	_player = get_parent()
	if _player is CharacterBody3D:
		if _player.has_signal(&"speed_changed"):
			_player.speed_changed.connect(_on_speed_changed)
		if _player.has_signal(&"state_changed"):
			_player.state_changed.connect(_on_player_state_changed)
		if _player.has_signal(&"dash_attack_performed"):
			_player.dash_attack_performed.connect(_on_dash_performed)
		# Cooldown = full dash sequence length, so the player can't dash again
		# until dash + dash_land has finished playing.
		if "dash_attack_cooldown" in _player:
t	if _player.has_signal(&"perfect_dodge_performed"):
			_player.perfect_dodge_performed.connect(_on_dodge_performed)
			_player.dash_attack_cooldown = dash_duration + dash_land_duration
	# Start with idle
	play(&"idle")
	animation_finished.connect(_on_any_animation_finished)

func _on_speed_changed(flat: float, max_speed: float) -> void:
	_current_speed = flat
	_max_speed = max_speed
	# While walking or wall-running, dynamically adjust speed_scale
	if _bb_state == BillboardState.WALK or _bb_state == BillboardState.WALL_RUN:
		var t := clampf((flat - min_move_speed) / (max_speed - min_move_speed), 0.0, 1.0)
		speed_scale = lerpf(walk_min_fps, walk_max_fps, t)
		# Re-evaluate wall direction every physics frame during wall run.
		# This handles the player running around a corner or the camera moving,
		# which can change which side of the character the wall is on.
		if _bb_state == BillboardState.WALL_RUN:
			_update_wall_run_side()

func _on_player_state_changed(new_state: int) -> void:
	# Don't interrupt a dash sequence
	if _bb_state in [BillboardState.DASH, BillboardState.DASH_LAND]:
		return
	match new_state:
		## State.AIR
		2:
			if _bb_state == BillboardState.PREPARE_JUMP or _bb_state == BillboardState.JUMP_START or _bb_state == BillboardState.JUMP_FALL:
				return  # already in a jump sequence
			# determine which sequence to use based on what we were doing before
			_change_state(BillboardState.PREPARE_JUMP if _last_ground_state == 0 else BillboardState.JUMP_START)
		## State.RUN
		1:
			if _bb_state == BillboardState.LAND_TO_RUN:
				return
			if _was_in_jump():
				_change_state(BillboardState.LAND_TO_RUN)
			else:
				_last_ground_state = 1
				if _bb_state != BillboardState.WALK:
					_change_state(BillboardState.WALK)
		## State.IDLE
		0:
			if _bb_state == BillboardState.LAND_TO_IDLE:
				return
			if _was_in_jump():
				_change_state(BillboardState.LAND_TO_IDLE)
			else:
				_last_ground_state = 0
				if _bb_state != BillboardState.IDLE:
					_change_state(BillboardState.IDLE)
		## State.SLIDE — still on ground, treat as running for jump decision
		3:
			if not _was_in_jump():
				_last_ground_state = 1
		## State.ARC — still on ground, treat as running for jump decision
		4:
			if not _was_in_jump():
				_last_ground_state = 1
		## State.WALL_RIDE — latch onto wall, play wall_run loop (left/right variant)
		5:
			if _bb_state != BillboardState.WALL_RUN:
				_change_state(BillboardState.WALL_RUN)
		## State.SLIDE, ARC, or anything else
		_: pass

## Returns true if the wall is on the player's left side (use mirrored animation).
## Uses camera right vector dot wall normal: if the wall normal has a component
## pointing in the same direction as the camera's right, the wall surface is on
## the player's left from the camera's perspective.
## The billboard always faces the camera, so camera-relative left/right is correct.
func _wall_is_left() -> bool:
	if _player and "wall_normal_exposed" in _player:
		var wn: Variant = _player.get("wall_normal_exposed")
		if typeof(wn) != TYPE_VECTOR3 or wn.length_squared() < 0.001:
			return false
		var cam := get_viewport().get_camera_3d()
		if cam:
			var cam_right := cam.global_transform.basis.x * Vector3(1, 0, 1)
			if cam_right.length_squared() > 0.01:
				return wn.dot(cam_right.normalized()) > 0.0
	return false

## When the wall run animation is already playing, re-evaluate which side the
## wall is on and swap directions if needed. Called every physics frame during
## wall run via the speed_changed signal.
func _update_wall_run_side() -> void:
	var should_be_left := _wall_is_left()
	var current_is_left := animation == &"wall_run_left"
	if should_be_left != current_is_left:
		play(&"wall_run_left" if should_be_left else &"wall_run")
		# Re-apply speed scale after play() resets it
		var t := clampf((_current_speed - min_move_speed) / (_max_speed - min_move_speed), 0.0, 1.0)
		speed_scale = lerpf(walk_min_fps, walk_max_fps, t)

func _on_dash_performed() -> void:
	if _bb_state in [BillboardState.DASH, BillboardState.DASH_LAND]:
		return
	_change_state(BillboardState.DASH)

func _was_in_jump() -> bool:
	return _bb_state in [BillboardState.PREPARE_JUMP, BillboardState.JUMP_START, BillboardState.JUMP_FALL]

func _on_any_animation_finished() -> void:
	if _anim_finished_cb.is_valid():
		var cb := _anim_finished_cb
		_anim_finished_cb = Callable()
		cb.call()

func _change_state(new_state: BillboardState) -> void:
	_bb_state = new_state
	_anim_finished_cb = Callable()  # clear any pending callback from previous state

	match new_state:
		BillboardState.IDLE:
			play(&"idle")
			speed_scale = idle_fps
			_last_ground_state = 0

		BillboardState.WALK:
			play(&"walk")
			var t := clampf((_current_speed - min_move_speed) / (_max_speed - min_move_speed), 0.0, 1.0)
			speed_scale = lerpf(walk_min_fps, walk_max_fps, t)
			_last_ground_state = 1

		BillboardState.PREPARE_JUMP:
			play(&"prepare_jump_from_idle")
			speed_scale = jump_fps
			_anim_finished_cb = _on_prepare_jump_done

		BillboardState.JUMP_START:
			play(&"jump_fall_start")
			speed_scale = jump_fps
			_anim_finished_cb = _on_jump_start_done

		BillboardState.JUMP_FALL:
			play(&"jump_fall_mid")
			speed_scale = jump_fps
			# looping — no callback needed

		BillboardState.LAND_TO_RUN:
			play(&"jump_fall_to_run")
			speed_scale = jump_fps
			_anim_finished_cb = _on_land_to_run_done

		BillboardState.LAND_TO_IDLE:
			play(&"jump_fall_to_idle")
			speed_scale = jump_fps
			_anim_finished_cb = _on_land_to_idle_done

		BillboardState.WALL_RUN:
			if _wall_is_left():
				play(&"wall_run_left")
			else:
				play(&"wall_run")
			# match walk's speed feel: wall run is also a motion animation
			var t := clampf((_current_speed - min_move_speed) / (_max_speed - min_move_speed), 0.0, 1.0)
			speed_scale = lerpf(walk_min_fps, walk_max_fps, t)

		BillboardState.DASH:
			play(&"dash")
			speed_scale = _speed_scale_for_duration(&"dash", dash_duration)
			_anim_finished_cb = _on_dash_done

		BillboardState.DASH_LAND:
			play(&"dash_land")
			speed_scale = _speed_scale_for_duration(&"dash_land", dash_land_duration)
			_anim_finished_cb = _on_dash_land_done

t	BillboardState.DODGE:
			play(&"dodge")
			speed_scale = 8.0
			_anim_finished_cb = _on_dodge_done

## Base SpriteFrames FPS is 1.0 for every animation (see header note), so
## playback speed in frames/sec == speed_scale. To make an animation with any
## frame count last exactly `duration` seconds: speed_scale = frame_count / duration.
func _speed_scale_for_duration(anim_name: StringName, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	var frame_count := 1
	if sprite_frames and sprite_frames.has_animation(anim_name):
		frame_count = maxi(sprite_frames.get_frame_count(anim_name), 1)
	return frame_count / duration

func _on_prepare_jump_done() -> void:
	# prepare_jump_from_idle finished → jump_fall_start
	_change_state(BillboardState.JUMP_START)

func _on_jump_start_done() -> void:
	# jump_fall_start finished → enter mid-air loop
	_change_state(BillboardState.JUMP_FALL)

func _on_land_to_run_done() -> void:
	_change_state(BillboardState.WALK)

func _on_land_to_idle_done() -> void:
	_change_state(BillboardState.IDLE)

func _on_dash_done() -> void:
	_change_state(BillboardState.DASH_LAND)

func _on_dash_land_done() -> void:
	if _current_speed > min_move_speed:
		_change_state(BillboardState.WALK)
	else:
		_change_state(BillboardState.IDLE)

func _on_dodge_performed(_streak: int) -> void:
	_change_state(BillboardState.DODGE)

func _on_dodge_done() -> void:
	if _current_speed > min_move_speed:
		_change_state(BillboardState.WALK)
	else:
		_change_state(BillboardState.IDLE)

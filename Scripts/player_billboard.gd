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
}

@export var idle_fps: float = 4.0
@export var walk_min_fps: float = 4.0
@export var walk_max_fps: float = 12.0
@export var min_move_speed: float = 0.5
@export var jump_fps: float = 8.0

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
	# Start with idle
	play(&"idle")
	animation_finished.connect(_on_any_animation_finished)

func _on_speed_changed(flat: float, max_speed: float) -> void:
	_current_speed = flat
	_max_speed = max_speed
	# While walking, dynamically adjust speed_scale
	if _bb_state == BillboardState.WALK or _bb_state == BillboardState.WALL_RUN:
		var t := clampf((flat - min_move_speed) / (max_speed - min_move_speed), 0.0, 1.0)
		speed_scale = lerpf(walk_min_fps, walk_max_fps, t)

func _on_player_state_changed(new_state: int) -> void:
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
## Uses camera right vector dot wall normal: if normal points same direction as
## camera right, the wall surface is on the player's left.
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

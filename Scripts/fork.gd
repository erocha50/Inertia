extends Area3D
## Fork projectile with a quadratic Bézier curved trajectory.
## The curve is defined by three points:
##   P0 = spawn position
##   P1 = control point (offset perpendicular to the aim line → the bend)
##   P2 = target position (predicted player position)
## All motion is relative to those three world-space points, so it
## never drifts toward the world centre regardless of where the enemy is.

@export var speed: float = 50.0
@export var damage: float = 12.0
@export var lifetime: float = 5.0
@export var flight_duration: float = 0.55   # Seconds to reach the target
@export var curve_bias: float = 0.45        # How far along the aim line the control point sits
@export var subtle_dip_amount: float = 0.18 # Gentle gravity dip (metres, peaks at midpoint)

# Set by bloated_diner.gd via launch()
var _p0: Vector3          # Bezier start
var _p1: Vector3          # Bezier control (the bend)
var _p2: Vector3          # Bezier end (target)

var time_elapsed: float = 0.0
var has_hit: bool = false
var _ready_to_move: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

## dir        - normalised aim direction (toward predicted player pos)
## curve_side - signed lateral metres for the control point;
##              positive = curve right, negative = curve left.
##              All forks in a volley share the same sign so the beam
##              sweeps together as one unit.
func launch(dir: Vector3, curve_side: float = 0.0) -> void:
	_p0 = global_position

	# Use the real player position as the target so it tracks correctly
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_p2 = players[0].global_position
	else:
		_p2 = global_position + dir * speed * flight_duration

	# Control point: midway along the straight line, pushed sideways
	# relative to dir (not world axes) - this is what prevents centre-drift
	var right := dir.cross(Vector3.UP).normalized()
	var mid   := _p0.lerp(_p2, curve_bias)
	_p1 = mid + right * curve_side

	_ready_to_move = true

func _physics_process(delta: float) -> void:
	if has_hit or not _ready_to_move:
		return

	time_elapsed += delta
	var t: float = clamp(time_elapsed / flight_duration, 0.0, 1.0)
	var et: float = _ease_in_out(t)

	# Quadratic Bezier position
	var pos: Vector3 = _bezier(_p0, _p1, _p2, et)

	# Parabolic dip: peaks at t=0.5, zero at start and end
	pos.y -= subtle_dip_amount * 4.0 * et * (1.0 - et)

	# Rotate to face travel direction
	var next_et: float = _ease_in_out(clamp((time_elapsed + delta) / flight_duration, 0.0, 1.0))
	var next_pos: Vector3 = _bezier(_p0, _p1, _p2, next_et)
	var travel_dir: Vector3 = next_pos - pos
	if travel_dir.length() > 0.001:
		rotation.y = atan2(travel_dir.x, travel_dir.z)

	global_position = pos

	if t >= 1.0:
		queue_free()

func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _on_body_entered(body: Node3D) -> void:
	if has_hit:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		has_hit = true
		body.take_damage(damage)
		queue_free()

func _on_area_entered(_area: Area3D) -> void:
	pass

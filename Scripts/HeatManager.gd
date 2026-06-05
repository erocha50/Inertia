extends Node

signal heat_changed(new_value: float, tier: String)

var heat_value: float = 50.0
var max_heat: float = 100.0
var heat_floor: float = 0.0   # back to 0 — death system handles the floor

# ── Base rates ────────────────────────────────────────────────────────────────
@export var heat_gain_per_second: float = 5.0
@export var heat_loss_per_second: float = 15.0
@export var movement_speed_threshold: float = 2.0

# ── Gain scaling ──────────────────────────────────────────────────────────────
@export_range(0.01, 0.3, 0.01) var gain_speed_scale_min: float = 0.02
@export_range(1.0, 5.0, 0.1)   var gain_curve_power: float = 4.0

# ── Idle drain scaling ────────────────────────────────────────────────────────
@export_range(1.0, 12.0, 0.1)  var loss_speed_scale_max: float = 7.0
@export_range(1.0, 4.0, 0.1)   var loss_curve_power: float = 2.0

# ── Speed-drop sensitivity ────────────────────────────────────────────────────
@export_range(0.0, 2.0, 0.05)  var decel_drain_per_unit: float = 0.6
@export_range(0.0, 2.0, 0.05)  var decel_noise_threshold: float = 0.3

# ── Event-based chunk drops ───────────────────────────────────────────────────
@export_range(0.0, 30.0, 0.5)  var wall_hit_drain_per_speed: float = 0.4
@export_range(0.0, 40.0, 1.0)  var landing_drain: float = 12.0
@export_range(0.0, 20.0, 0.5)  var idle_transition_drain: float = 5.0
@export_range(0.0, 20.0, 0.5)  var arc_end_drain: float = 4.0

# ── Decay curve ───────────────────────────────────────────────────────────────
@export_range(0.2, 5.0, 0.1)   var decay_curve_duration: float = 2.0
@export_range(1.0, 4.0, 0.1)   var decay_curve_peak: float = 2.5

@export var player_speed_min: float = 10.0
@export var player_speed_max: float = 40.0

var current_flat_speed: float = 0.0
var _prev_flat_speed: float   = 0.0
var _decay_curve_t: float     = 0.0
var _prev_state: int          = -1

const TIER_THRESHOLDS: Dictionary = {
	"cold":    0.0,
	"warm":    25.0,
	"hot":     50.0,
	"burning": 75.0,
}
const TIER_DAMAGE_MULT: Dictionary = {
	"cold":    1.0,
	"warm":    1.2,
	"hot":     1.5,
	"burning": 2.0,
}

func _ready() -> void:
	heat_value = 50.0
	set_process(true)
	heat_changed.emit(heat_value, get_tier())
	call_deferred("_connect_player_signals")

func _connect_player_signals() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0]
	if p.has_signal("wall_hit"):   p.wall_hit.connect(_on_wall_hit)
	if p.has_signal("landed"):     p.landed.connect(_on_landed)
	if p.has_signal("state_changed"): p.state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	var speed_range: float = maxf(player_speed_max - player_speed_min, 1.0)
	var raw_t: float = clampf((current_flat_speed - player_speed_min) / speed_range, 0.0, 1.0)

	var speed_drop: float = _prev_flat_speed - current_flat_speed
	if speed_drop > decel_noise_threshold:
		var impact_scale: float = lerpf(0.5, 1.5, raw_t)
		remove_heat(speed_drop * decel_drain_per_unit * impact_scale)

	if current_flat_speed >= movement_speed_threshold:
		var gain_t: float    = pow(raw_t, gain_curve_power)
		var gain_mult: float = lerpf(1.0, gain_speed_scale_min, gain_t)
		_decay_curve_t = 0.0
		add_heat(heat_gain_per_second * gain_mult * delta)
	else:
		_decay_curve_t = minf(_decay_curve_t + delta / maxf(decay_curve_duration, 0.001), 1.0)
		var curve: float       = _decay_curve_t * _decay_curve_t * _decay_curve_t
		var speed_loss_t: float = pow(raw_t, loss_curve_power)
		var base_mult: float   = lerpf(1.0, loss_speed_scale_max, speed_loss_t)
		var loss_mult: float   = base_mult * lerpf(1.0, decay_curve_peak, curve)
		remove_heat(heat_loss_per_second * loss_mult * delta)

	_prev_flat_speed = current_flat_speed

func _on_wall_hit(_wall_normal: Vector3, impact_speed: float) -> void:
	remove_heat(impact_speed * wall_hit_drain_per_speed)

func _on_landed(_impact_speed: float) -> void:
	remove_heat(landing_drain)

func _on_state_changed(new_state: int) -> void:
	if new_state == 0: remove_heat(idle_transition_drain)
	if _prev_state == 4 and new_state != 4: remove_heat(arc_end_drain)
	_prev_state = new_state

func update_speed(flat_speed: float) -> void:
	current_flat_speed = flat_speed

func get_tier() -> String:
	var ratio: float = (heat_value / max_heat) * 100.0
	if ratio >= TIER_THRESHOLDS["burning"]: return "burning"
	elif ratio >= TIER_THRESHOLDS["hot"]:   return "hot"
	elif ratio >= TIER_THRESHOLDS["warm"]:  return "warm"
	else:                                   return "cold"

func get_damage_multiplier() -> float:
	return TIER_DAMAGE_MULT.get(get_tier(), 1.0)

func set_heat(new_value: float) -> void:
	new_value = clampf(new_value, heat_floor, max_heat)
	if new_value != heat_value:
		heat_value = new_value
		heat_changed.emit(heat_value, get_tier())

func restore_heat(amount: float) -> void:
	set_heat(heat_value + amount)

func add_heat_floor_bonus(amount: float) -> void:
	heat_floor = minf(heat_floor + amount, 12.0)
	set_heat(heat_value)

func add_heat(amount: float) -> void:
	set_heat(heat_value + amount)

func remove_heat(amount: float) -> void:
	set_heat(heat_value - amount)

func get_heat_rate_info() -> Dictionary:
	var raw_t: float = clampf(
		(current_flat_speed - player_speed_min) / maxf(player_speed_max - player_speed_min, 1.0),
		0.0, 1.0)
	return {
		"speed_t":   raw_t,
		"gain_mult": lerpf(1.0, gain_speed_scale_min, pow(raw_t, gain_curve_power)),
		"loss_mult": lerpf(1.0, loss_speed_scale_max, pow(raw_t, loss_curve_power)),
	}

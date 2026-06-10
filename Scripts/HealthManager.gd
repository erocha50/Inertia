extends Node

# ── HealthManager.gd ──────────────────────────────────────────────────────────
# Autoload as "HealthManager"
# HP drains when heat is at 0, recovers slowly while heat is above 0.
# ─────────────────────────────────────────────────────────────────────────────

signal health_changed(new_value: float, max_value: float)
signal player_hp_zero()

@export var max_hp: float                = 100.0
## HP drained per second at the start of a heat=0 period
@export var base_drain_per_second: float = 8.0
## After this many seconds at heat=0, drain rate peaks
@export var drain_ramp_duration: float   = 4.0
## Peak drain multiplier (reached after drain_ramp_duration seconds at heat=0)
@export var drain_ramp_peak: float       = 3.5
## HP recovered per second while heat is above 0
@export var hp_regen_per_second: float   = 4.0
## Heat must be above this ratio (0-1) to trigger regen (e.g. 0.1 = above 10%)
@export var regen_heat_threshold: float  = 0.05

var hp: float            = 100.0
var _drain_ramp_t: float = 0.0
var _is_dead: bool       = false


func _ready() -> void:
	hp = max_hp
	health_changed.emit(hp, max_hp)


func _process(delta: float) -> void:
	if _is_dead:
		return

	var heat_ratio := HeatManager.heat_value / HeatManager.max_heat

	if HeatManager.heat_value <= 0.0:
		# Heat at zero — drain HP, ramp up over time
		_drain_ramp_t += delta
		var t    := clampf(_drain_ramp_t / drain_ramp_duration, 0.0, 1.0)
		var ramp := lerpf(1.0, drain_ramp_peak, t * t)
		_take_drain(base_drain_per_second * ramp * delta)
	else:
		# Heat above zero — reset drain ramp
		_drain_ramp_t = 0.0

		# Regen HP — scales with how much heat you have
		# More heat = faster regen, up to full hp_regen_per_second at max heat
		if heat_ratio > regen_heat_threshold and hp < max_hp:
			var regen_rate := hp_regen_per_second * heat_ratio
			_heal(regen_rate * delta)


# ── Public API ────────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if _is_dead:
		return
	_take_drain(amount)


func reset_hp() -> void:
	_is_dead      = false
	_drain_ramp_t = 0.0
	hp            = max_hp
	health_changed.emit(hp, max_hp)


# ── Internal ──────────────────────────────────────────────────────────────────

func _take_drain(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0 and not _is_dead:
		_is_dead = true
		player_hp_zero.emit()


func _heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)

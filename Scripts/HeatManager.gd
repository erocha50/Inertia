# autoloads/HeatManager.gd
extends Node

signal heat_changed(new_value: float, tier: String)

var heat_value: float = 50.0
var heat_floor: float = 0.0        # increased by Hearths (+2 each, max 12)
var max_heat: float = 100.0        # increased by Paring Knife shard
var decay_rate: float = 5.0        # pts/sec standing still (Filleting shard reduces this)
var cold_storage_multiplier: float = 1.0  # set to 2.0 by ColdStorage area script

var heat_per_hit_bonus: float = 0.0   # set by Hot Pepper Sauce
var heat_per_hit_timer: float = 0.0

func _process(delta: float) -> void:
	if heat_per_hit_timer > 0.0:
		heat_per_hit_timer -= delta
		if heat_per_hit_timer <= 0.0:
			heat_per_hit_bonus = 0.0

func apply_decay(delta: float) -> void:
	# Called by Player.gd when stationary
	var rate = decay_rate * cold_storage_multiplier
	heat_value = max(heat_floor, heat_value - rate * delta)
	emit_signal('heat_changed', heat_value, get_tier())

func apply_build(delta: float, speed_ratio: float) -> void:
	# Called by Player.gd when moving; speed_ratio is current_speed / max_speed (0-1)
	heat_value = min(max_heat, heat_value + speed_ratio * 20.0 * delta)
	emit_signal('heat_changed', heat_value, get_tier())

func apply_damage_to_heat(amount: float) -> void:
	# Taking damage instantly drops Heat proportional to damage
	heat_value = max(heat_floor, heat_value - amount * 0.5)
	emit_signal('heat_changed', heat_value, get_tier())

func on_hit_enemy() -> void:
	# Called when player lands a hit; used by Hot Pepper Sauce
	if heat_per_hit_bonus > 0.0:
		heat_value = min(max_heat, heat_value + heat_per_hit_bonus)
		emit_signal('heat_changed', heat_value, get_tier())

func get_damage_multiplier() -> float:
	match get_tier():
		'cold':    return 0.5
		'warm':    return 1.0
		'hot':     return 1.25
		'burning': return 1.5
	return 1.0

func get_tier() -> String:
	if heat_value <= 25.0:   return 'cold'
	elif heat_value <= 50.0: return 'warm'
	elif heat_value <= 75.0: return 'hot'
	else:                    return 'burning'

func fill_heat() -> void:
	# Used by Black Truffle
	heat_value = max_heat
	emit_signal('heat_changed', heat_value, get_tier())

func activate_hot_pepper(duration: float, bonus: float) -> void:
	heat_per_hit_bonus = bonus
	heat_per_hit_timer = duration

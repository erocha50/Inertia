extends Node

signal heat_changed(new_value: float, tier: String)

var heat_value: float = 0.0
var max_heat: float = 100.0
var heat_floor: float = 0.0

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
	heat_value = heat_floor

func get_tier() -> String:
	var ratio: float = (heat_value / max_heat) * 100.0
	if ratio >= TIER_THRESHOLDS["burning"]:
		return "burning"
	elif ratio >= TIER_THRESHOLDS["hot"]:
		return "hot"
	elif ratio >= TIER_THRESHOLDS["warm"]:
		return "warm"
	else:
		return "cold"

func get_damage_multiplier() -> float:
	var tier: String = get_tier()
	return TIER_DAMAGE_MULT.get(tier, 1.0)

func set_heat(new_value: float) -> void:
	new_value = maxf(new_value, heat_floor)
	new_value = minf(new_value, max_heat)
	if new_value != heat_value:
		heat_value = new_value
		var tier: String = get_tier()
		heat_changed.emit(heat_value, tier)

func add_heat(amount: float) -> void:
	set_heat(heat_value + amount)

func remove_heat(amount: float) -> void:
	set_heat(heat_value - amount)

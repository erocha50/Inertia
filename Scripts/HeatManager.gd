extends Node

signal heat_changed(new_value: float, tier: String)

var heat_value: float = 0.0
var max_heat: float = 100.0
var heat_floor: float = 0.0

# Heat buildup/decay when moving
@export var heat_gain_per_second: float = 30.0      # Heat gained per second while moving
@export var heat_loss_per_second: float = 15.0      # Heat lost per second while idle
@export var movement_speed_threshold: float = 2.0   # Min speed to count as "moving"

var current_flat_speed: float = 0.0

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
	set_process(true)
	# Emit initial signal so UI updates immediately
	var tier: String = get_tier()
	heat_changed.emit(heat_value, tier)

func _process(delta: float) -> void:
	# Heat builds up while moving, decays while idle
	if current_flat_speed >= movement_speed_threshold:
		# Player is moving — gain heat
		add_heat(heat_gain_per_second * delta)
	else:
		# Player is idle — lose heat
		remove_heat(heat_loss_per_second * delta)

func update_speed(flat_speed: float) -> void:
	"""Called by the player to update their current movement speed"""
	current_flat_speed = flat_speed

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
		
func restore_heat(amount: float) -> void:
	"""Called by Hearth — restores heat up to max."""
	set_heat(heat_value + amount)

func add_heat_floor_bonus(amount: float) -> void:
	"""Called by Hearth on first activation — permanently raises the heat floor."""
	heat_floor = minf(heat_floor + amount, 12.0)  # Max +12 across 6 hearths
	# Re-clamp current heat in case floor is now higher
	set_heat(heat_value)
func add_heat(amount: float) -> void:
	set_heat(heat_value + amount)

func remove_heat(amount: float) -> void:
	set_heat(heat_value - amount)

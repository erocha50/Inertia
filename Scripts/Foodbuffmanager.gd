extends Node

# ── FoodBuffManager.gd ────────────────────────────────────────────────────────
# Autoload as "FoodBuffManager"
# Tracks timed buffs/debuffs from consumed food items.
# Other systems read these values when calculating speed, damage, heat gain etc.
# ─────────────────────────────────────────────────────────────────────────────

signal buff_applied(item_name: String, duration: float)
signal buff_expired(item_name: String)

## Active timed bonuses — read these from player/heat/combat code
var momentum_ceiling_bonus: float = 0.0
var heat_per_hit_bonus: float     = 0.0
var sprint_damage_bonus: float    = 0.0
var turning_impaired: bool        = false

var _active_buffs: Dictionary = {}   # item_name -> remaining time


func _process(delta: float) -> void:
	if _active_buffs.is_empty():
		return

	var expired: Array = []
	for item_name in _active_buffs.keys():
		_active_buffs[item_name] -= delta
		if _active_buffs[item_name] <= 0.0:
			expired.append(item_name)

	for item_name in expired:
		_active_buffs.erase(item_name)
		buff_expired.emit(item_name)
		_recalculate_totals()


## Call this when a FoodItemData with duration > 0 is consumed
func apply_buff(data: FoodItemData) -> void:
	if data.duration <= 0.0:
		return

	_active_buffs[data.item_name] = data.duration
	buff_applied.emit(data.item_name, data.duration)
	_recalculate_totals()


## Returns true if a buff with this item_name is currently active
func has_buff(item_name: String) -> bool:
	return _active_buffs.has(item_name)


func get_remaining(item_name: String) -> float:
	return _active_buffs.get(item_name, 0.0)


# ── Internal ──────────────────────────────────────────────────────────────────

func _recalculate_totals() -> void:
	# Reset, then re-sum from whatever food data is still active.
	# Since we don't store the full FoodItemData per buff (only timers),
	# we keep a parallel dictionary of applied values.
	momentum_ceiling_bonus = 0.0
	heat_per_hit_bonus     = 0.0
	sprint_damage_bonus    = 0.0
	turning_impaired       = false

	for item_name in _active_buffs.keys():
		var vals: Dictionary = _buff_values.get(item_name, {})
		momentum_ceiling_bonus += vals.get("momentum_ceiling_bonus", 0.0)
		heat_per_hit_bonus     += vals.get("heat_per_hit_bonus", 0.0)
		sprint_damage_bonus    += vals.get("sprint_damage_bonus", 0.0)
		if vals.get("impairs_turning", false):
			turning_impaired = true


# Stores the actual bonus values per item_name so _recalculate_totals can sum them
var _buff_values: Dictionary = {}

## Call this instead of apply_buff when you want bonus values tracked too
func apply_food_buff(data: FoodItemData) -> void:
	if data.duration <= 0.0:
		return

	_buff_values[data.item_name] = {
		"momentum_ceiling_bonus": data.momentum_ceiling_bonus,
		"heat_per_hit_bonus":     data.heat_per_hit_bonus,
		"sprint_damage_bonus":    data.sprint_damage_bonus,
		"impairs_turning":        data.impairs_turning,
	}
	_active_buffs[data.item_name] = data.duration
	buff_applied.emit(data.item_name, data.duration)
	_recalculate_totals()

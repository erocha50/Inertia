extends CanvasLayer

@onready var heat_bar_bg: ColorRect      = $HeatBarBG
@onready var heat_bar: ColorRect         = $HeatBar
@onready var heat_label: Label           = $HeatLabel
@onready var tier_label: Label           = $TierLabel
@onready var health_bar                  = $HealthBar
@onready var food_slots: HBoxContainer   = $FoodSlots

# Match this to the pixel width of your HeatBarBG ColorRect in the editor
const HEAT_BAR_MAX_WIDTH := 300.0

const TIER_COLOURS := {
	"cold":    Color(0.2, 0.5, 1.0),
	"warm":    Color(1.0, 0.75, 0.2),
	"hot":     Color(1.0, 0.4, 0.1),
	"burning": Color(0.9, 0.1, 0.05),
}


func _ready() -> void:
	HeatManager.heat_changed.connect(_on_heat_changed)
	# Sync immediately in case HUD loads mid-session
	_refresh_heat_ui(HeatManager.heat_value, HeatManager.get_tier())

	heat_label.visible = true  # flip false before final build


func _on_heat_changed(new_value: float, tier: String) -> void:
	_refresh_heat_ui(new_value, tier)


func _refresh_heat_ui(value: float, tier: String) -> void:
	# Scale against max_heat not hardcoded 100 — Paring Knife shard raises the cap
	var fill_ratio: float = value / HeatManager.max_heat
	var bar_size := heat_bar.size
	bar_size.x = fill_ratio * HEAT_BAR_MAX_WIDTH
	heat_bar.size = bar_size

	if TIER_COLOURS.has(tier):
		heat_bar.color = TIER_COLOURS[tier]

	heat_label.text = "Heat: %.1f / %.0f  |  x%.2f dmg" % [
		value,
		HeatManager.max_heat,
		HeatManager.get_damage_multiplier()
	]
	tier_label.text = tier.to_upper()


# ── Food Slots ────────────────────────────────────────────────────────────────
# Call from your inventory system. Each item dict should have a "colour" key.
func update_food_slots(items: Array) -> void:
	for child in food_slots.get_children():
		child.queue_free()
	for item in items:
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(32, 32)
		slot.color = item.get("colour", Color(0.4, 0.4, 0.4))
		food_slots.add_child(slot)


# ── Health (placeholder until Sprint 3) ──────────────────────────────────────
func update_health(current: float, maximum: float) -> void:
	if health_bar is TextureProgressBar:
		health_bar.max_value = maximum
		health_bar.value     = current
	elif health_bar is ColorRect:
		var s: Vector2 = health_bar.size
		s.x = (current / maximum) * 200.0
		health_bar.size = s

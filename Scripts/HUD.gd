extends CanvasLayer

@onready var heat_bar_bg: ColorRect      = $HeatBarBG
@onready var heat_bar: ColorRect         = $HeatBar
@onready var heat_label: Label           = $HeatLabel
@onready var tier_label: Label           = $TierLabel
@onready var health_bar                  = $HealthBar
@onready var food_slots: HBoxContainer   = $FoodSlots

# Match this to the pixel width of your HeatBarBG ColorRect in the editor
const HEAT_BAR_MAX_WIDTH := 300.0

# Cooldown tracking
var _dash_cooldown: float = 0.0
var _dash_max_cooldown: float = 5.0

var _roll_cooldown: float = 0.0
var _roll_max_cooldown: float = 3.0

# UI elements for cooldown bars
var _dash_bar: ColorRect
var _dash_label: Label
var _roll_bar: ColorRect
var _roll_label: Label

# Player reference for reading cooldown values
var _player: Node = null

const TIER_COLOURS := {
	"cold":    Color(0.2, 0.5, 1.0),
	"warm":    Color(1.0, 0.75, 0.2),
	"hot":     Color(1.0, 0.4, 0.1),
	"burning": Color(0.9, 0.1, 0.05),
}

const COOLDOWN_BAR_WIDTH := 150.0
const COOLDOWN_BAR_HEIGHT := 20.0


func _ready() -> void:
	HeatManager.heat_changed.connect(_on_heat_changed)
	# Sync immediately in case HUD loads mid-session
	_refresh_heat_ui(HeatManager.heat_value, HeatManager.get_tier())

	heat_label.visible = true  # flip false before final build
	
	# Create cooldown UI
	_create_cooldown_ui()
	
	# Get the main scene and find the player
	await get_tree().process_frame
	var root: Node = get_tree().root.get_child(0)
	var player: Node = root.find_child("Player", true, false)
	if player:
		_player = player
		# Get max cooldowns from player
		if player.has_meta("dash_attack_cooldown") or "dash_attack_cooldown" in player:
			_dash_max_cooldown = player.dash_attack_cooldown
		if player.has_meta("roll_cooldown") or "roll_cooldown" in player:
			_roll_max_cooldown = player.roll_cooldown
		
		if player.has_signal("dash_attack_performed"):
			player.dash_attack_performed.connect(_on_dash_performed)
		if player.has_signal("roll_performed"):
			player.roll_performed.connect(_on_roll_performed)


func _create_cooldown_ui() -> void:
	"""Create simple bars and labels for cooldowns"""
	
	# Dash cooldown bar
	_dash_bar = ColorRect.new()
	_dash_bar.color = Color(0.8, 0.2, 0.2, 0.7)  # Red
	_dash_bar.custom_minimum_size = Vector2(COOLDOWN_BAR_WIDTH, COOLDOWN_BAR_HEIGHT)
	_dash_bar.position = Vector2(20, 20)
	add_child(_dash_bar)
	
	_dash_label = Label.new()
	_dash_label.text = "Dash"
	_dash_label.position = Vector2(20, 42)
	_dash_label.add_theme_font_size_override("font_size", 14)
	add_child(_dash_label)
	
	# Roll cooldown bar
	_roll_bar = ColorRect.new()
	_roll_bar.color = Color(0.2, 0.8, 0.2, 0.7)  # Green
	_roll_bar.custom_minimum_size = Vector2(COOLDOWN_BAR_WIDTH, COOLDOWN_BAR_HEIGHT)
	_roll_bar.position = Vector2(20, 75)
	add_child(_roll_bar)
	
	_roll_label = Label.new()
	_roll_label.text = "Roll"
	_roll_label.position = Vector2(20, 97)
	_roll_label.add_theme_font_size_override("font_size", 14)
	add_child(_roll_label)


func _physics_process(d: float) -> void:
	# Update dash cooldown
	if _dash_cooldown > 0.0:
		_dash_cooldown -= d
		_update_dash_bar()
	
	# Update roll cooldown
	if _roll_cooldown > 0.0:
		_roll_cooldown -= d
		_update_roll_bar()


func _update_dash_bar() -> void:
	"""Update dash cooldown bar display"""
	if not _dash_bar or not _dash_label:
		return
	
	var fill_ratio: float = 1.0 - (_dash_cooldown / _dash_max_cooldown)
	var bar_size: Vector2 = Vector2(COOLDOWN_BAR_WIDTH * fill_ratio, COOLDOWN_BAR_HEIGHT)
	_dash_bar.size = bar_size
	
	# Update label with remaining time
	_dash_label.text = "Dash: %.1f" % max(0.0, _dash_cooldown)


func _update_roll_bar() -> void:
	"""Update roll cooldown bar display"""
	if not _roll_bar or not _roll_label:
		return
	
	var fill_ratio: float = 1.0 - (_roll_cooldown / _roll_max_cooldown)
	var bar_size: Vector2 = Vector2(COOLDOWN_BAR_WIDTH * fill_ratio, COOLDOWN_BAR_HEIGHT)
	_roll_bar.size = bar_size
	
	# Update label with remaining time
	_roll_label.text = "Roll: %.1f" % max(0.0, _roll_cooldown)


func _on_dash_performed() -> void:
	_dash_cooldown = _dash_max_cooldown
	_update_dash_bar()


func _on_roll_performed() -> void:
	_roll_cooldown = _roll_max_cooldown
	_update_roll_bar()


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

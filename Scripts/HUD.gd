extends CanvasLayer

@onready var heat_bar_bg: ColorRect    = $HeatBarBG
@onready var heat_bar: ColorRect       = $HeatBar
@onready var heat_label: Label         = $HeatLabel
@onready var tier_label: Label         = $TierLabel
@onready var health_bar                = $HealthBar
@onready var food_slots: HBoxContainer = $FoodSlots

@onready var dash_label : Label = $DashLabel
@onready var roll_label : Label = $RollLabel

const HEAT_BAR_MAX_WIDTH := 300.0

var _dash_cooldown     : float = 0.0
var _dash_max_cooldown : float = 5.0
var _roll_cooldown     : float = 0.0
var _roll_max_cooldown : float = 3.0

var _player: Node = null

const TIER_COLOURS := {
	"cold":    Color(0.2, 0.5, 1.0),
	"warm":    Color(1.0, 0.75, 0.2),
	"hot":     Color(1.0, 0.4, 0.1),
	"burning": Color(0.9, 0.1, 0.05),
}


func _ready() -> void:
	HeatManager.heat_changed.connect(_on_heat_changed)
	_refresh_heat_ui(HeatManager.heat_value, HeatManager.get_tier())
	heat_label.visible = true

	dash_label.text = "DASH  100%"
	roll_label.text = "ROLL  100%"

	# Find player
	var root   : Node = get_tree().root.get_child(0)
	var player : Node = root.find_child("Player", true, false)
	if player:
		_player = player
		if "dash_attack_cooldown" in player:
			_dash_max_cooldown = player.dash_attack_cooldown
		if "roll_cooldown" in player:
			_roll_max_cooldown = player.roll_cooldown
		if player.has_signal("dash_attack_performed"):
			player.dash_attack_performed.connect(_on_dash_performed)
		if player.has_signal("roll_performed"):
			player.roll_performed.connect(_on_roll_performed)


func _physics_process(delta: float) -> void:
	# Drive directly from player properties every frame — no signal needed
	if _player:
		if "dash_attack_cooldown_remaining" in _player:
			_dash_cooldown = _player.dash_attack_cooldown_remaining
		if "roll_cooldown_remaining" in _player:
			_roll_cooldown = _player.roll_cooldown_remaining

	# Dash text
	var dash_pct := int((1.0 - (_dash_cooldown / _dash_max_cooldown)) * 100.0)
	dash_pct = clampi(dash_pct, 0, 100)
	dash_label.text = "DASH  %d%%" % dash_pct

	# Roll text
	var roll_pct := int((1.0 - (_roll_cooldown / _roll_max_cooldown)) * 100.0)
	roll_pct = clampi(roll_pct, 0, 100)
	roll_label.text = "ROLL  %d%%" % roll_pct

	# Tick down ourselves as fallback if player properties don't exist
	if _dash_cooldown > 0.0 and not ("dash_attack_cooldown_remaining" in _player if _player else false):
		_dash_cooldown = max(0.0, _dash_cooldown - delta)
	if _roll_cooldown > 0.0 and not ("roll_cooldown_remaining" in _player if _player else false):
		_roll_cooldown = max(0.0, _roll_cooldown - delta)


# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_dash_performed() -> void:
	_dash_cooldown  = _dash_max_cooldown
	dash_label.text = "DASH  0%"

func _on_roll_performed() -> void:
	_roll_cooldown  = _roll_max_cooldown
	roll_label.text = "ROLL  0%"

func _on_heat_changed(new_value: float, tier: String) -> void:
	_refresh_heat_ui(new_value, tier)

func _refresh_heat_ui(value: float, tier: String) -> void:
	var fill_ratio : float = value / HeatManager.max_heat
	var bar_size           := heat_bar.size
	bar_size.x             = fill_ratio * HEAT_BAR_MAX_WIDTH
	heat_bar.size          = bar_size
	if TIER_COLOURS.has(tier):
		heat_bar.color = TIER_COLOURS[tier]
	heat_label.text = "Heat: %.1f / %.0f  |  x%.2f dmg" % [
		value, HeatManager.max_heat, HeatManager.get_damage_multiplier()
	]
	tier_label.text = tier.to_upper()


# ── Food Slots ────────────────────────────────────────────────────────────────
func update_food_slots(items: Array) -> void:
	for child in food_slots.get_children():
		child.queue_free()
	for item in items:
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(32, 32)
		slot.color = item.get("colour", Color(0.4, 0.4, 0.4))
		food_slots.add_child(slot)


# ── Health ────────────────────────────────────────────────────────────────────
func update_health(current: float, maximum: float) -> void:
	if health_bar is TextureProgressBar:
		health_bar.max_value = maximum
		health_bar.value     = current
	elif health_bar is ColorRect:
		var s : Vector2 = health_bar.size
		s.x = (current / maximum) * 200.0
		health_bar.size = s

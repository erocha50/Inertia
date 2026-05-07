extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════════
#  HUD.gd
#  Owns the heat bar, cooldown circles, and now:
#    • CombatSystem  – attack hitbox gating + heat-scaled damage
#    • SpeedSystem   – heat-scaled movement speed broadcast
#
#  Player.gd hooks in by connecting to the signals emitted here.
#  Nothing in Player.gd needs to change until the other dev is ready.
# ═══════════════════════════════════════════════════════════════════════════════

@onready var heat_bar_bg: ColorRect      = $HeatBarBG
@onready var heat_bar: ColorRect         = $HeatBar
@onready var heat_label: Label           = $HeatLabel
@onready var tier_label: Label           = $TierLabel
@onready var health_bar                  = $HealthBar
@onready var food_slots: HBoxContainer   = $FoodSlots

const HEAT_BAR_MAX_WIDTH := 300.0

# ── Cooldown state ─────────────────────────────────────────────────────────────
var _dash_cooldown     : float = 0.0
var _dash_max_cooldown : float = 5.0

var _roll_cooldown     : float = 0.0
var _roll_max_cooldown : float = 3.0

var _player: Node = null

# ── Circle layout ──────────────────────────────────────────────────────────────
const CIRCLE_RADIUS  := 30.0
const ARC_WIDTH      := 8.0
const ARC_SEGMENTS   := 128
const CIRCLE_SPACING := 16.0
const MARGIN         := 20.0
const CAP_RADIUS     := 4.0

const COLOR_BG_DISC    := Color(0.05, 0.05, 0.08, 0.92)
const COLOR_TRACK      := Color(0.18, 0.18, 0.22, 0.85)
const COLOR_TRACK_EDGE := Color(1.0,  1.0,  1.0,  0.06)
const COLOR_TEXT       := Color(1.0,  1.0,  1.0,  0.92)
const COLOR_LABEL      := Color(1.0,  1.0,  1.0,  0.50)

const COLOR_DASH_WORM  := Color(0.95, 0.28, 0.10)
const COLOR_ROLL_WORM  := Color(0.10, 0.82, 0.52)

class _CooldownDrawer extends Control:
	var hud : Node
	func _draw() -> void:
		if hud:
			hud._draw_cooldown_circles(self)

var _draw_node  : _CooldownDrawer
var _dash_centre: Vector2
var _roll_centre: Vector2

const TIER_COLOURS := {
	"cold":    Color(0.2, 0.5, 1.0),
	"warm":    Color(1.0, 0.75, 0.2),
	"hot":     Color(1.0, 0.4, 0.1),
	"burning": Color(0.9, 0.1, 0.05),
}

# ═══════════════════════════════════════════════════════════════════════════════
#  COMBAT SYSTEM
#  ─────────────────────────────────────────────────────────────────────────────
#  Damage multipliers match Appendix F / Sprint 2 spec:
#    Cold    0–25 %   → ×0.5
#    Warm   26–50 %   → ×1.0
#    Hot    51–75 %   → ×1.25
#    Burning76–100%   → ×1.5
#
#  Signals emitted so Player.gd can react without us touching it:
#    attack_hitbox_enable(true/false)  – gate the AttackHitbox Area3D
#    damage_multiplier_changed(float)  – current multiplier
#    speed_multiplier_changed(float)   – current speed scale
# ═══════════════════════════════════════════════════════════════════════════════

## Emitted every time the hitbox should open or close.
signal attack_hitbox_enable(enabled: bool)

## Emitted whenever the effective damage multiplier changes (tier change).
signal damage_multiplier_changed(multiplier: float)

## Emitted whenever the effective speed multiplier changes (tier change).
## Player.gd should multiply its base speed by this value.
signal speed_multiplier_changed(multiplier: float)

## Emitted when the player successfully lands an attack (call request_attack()).
signal attack_landed(damage: float)

# Speed multipliers per tier – the hotter you are, the faster you move.
const SPEED_MULTIPLIERS := {
	"cold":    0.75,   # sluggish – motivates keeping heat up
	"warm":    1.0,    # baseline
	"hot":     1.20,
	"burning": 1.45,
}

# Base damage value – Player.gd or a GameManager can override this.
var base_damage : float = 10.0

# How long an attack's active hitbox frames stay open (seconds).
var attack_active_frames : float = 0.25

# Internal state
var _attack_active       : bool  = false
var _attack_timer        : float = 0.0
var _current_tier        : String = "cold"
var _current_dmg_mult    : float = 0.5
var _current_speed_mult  : float = 0.75

# ─── HUD flash when heat is critically low ────────────────────────────────────
const LOW_HEAT_THRESHOLD := 0.15   # below 15 % → warn player
var _flash_timer : float = 0.0
var _flash_state : bool  = false


# ═══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	HeatManager.heat_changed.connect(_on_heat_changed)
	_refresh_heat_ui(HeatManager.heat_value, HeatManager.get_tier())
	_update_tier(HeatManager.get_tier())          # seed multipliers on start
	heat_label.visible = true

	await get_tree().process_frame
	_recompute_positions()
	get_tree().root.size_changed.connect(_recompute_positions)

	_draw_node     = _CooldownDrawer.new()
	_draw_node.hud = self
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	# ── Find player and wire optional signals ──────────────────────────────────
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

		# Player can connect these to receive our broadcasts:
		#   HUD.attack_hitbox_enable.connect(_on_hitbox_enable)
		#   HUD.damage_multiplier_changed.connect(_on_dmg_mult_changed)
		#   HUD.speed_multiplier_changed.connect(_on_speed_mult_changed)
		#   HUD.attack_landed.connect(_on_attack_landed)
		#
		# Or Player.gd can just poll:
		#   var mult = get_node("HUD").get_damage_multiplier()
		#   var spd  = get_node("HUD").get_speed_multiplier()

		# If base_damage is exported on the player, read it.
		if "base_damage" in player:
			base_damage = player.base_damage


func _recompute_positions() -> void:
	var vp     := get_tree().root.size
	var slot   := (CIRCLE_RADIUS + ARC_WIDTH) * 2.0
	var base_y := vp.y - MARGIN - slot * 0.5 - 14.0
	var base_x := MARGIN + slot * 0.5
	_dash_centre = Vector2(base_x, base_y)
	_roll_centre = Vector2(base_x + slot + CIRCLE_SPACING, base_y)
	if _draw_node:
		_draw_node.queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
#  PROCESS
# ═══════════════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	# ── Cooldown timers ───────────────────────────────────────────────────────
	var dirty := false
	if _dash_cooldown > 0.0:
		_dash_cooldown = max(0.0, _dash_cooldown - delta)
		dirty = true
	if _roll_cooldown > 0.0:
		_roll_cooldown = max(0.0, _roll_cooldown - delta)
		dirty = true
	if dirty and _draw_node:
		_draw_node.queue_redraw()

	# ── Attack active-frames window ───────────────────────────────────────────
	if _attack_active:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_active = false
			attack_hitbox_enable.emit(false)   # close hitbox

	# ── Low-heat flash (warn the player to keep their heat up) ────────────────
	var heat_ratio : float = HeatManager.heat_value / HeatManager.max_heat
	if heat_ratio < LOW_HEAT_THRESHOLD:
		_flash_timer += delta
		if _flash_timer >= 0.4:
			_flash_timer = 0.0
			_flash_state = !_flash_state
			_pulse_heat_bar(_flash_state)
	else:
		_flash_state = false
		_flash_timer = 0.0
		_pulse_heat_bar(false)


# ═══════════════════════════════════════════════════════════════════════════════
#  PUBLIC API  (call these from Player.gd or an InputManager)
# ═══════════════════════════════════════════════════════════════════════════════

## Call this when the player presses the attack button.
## Opens the hitbox for `attack_active_frames` seconds and emits attack_landed
## with the heat-scaled damage value.
func request_attack() -> void:
	if _attack_active:
		return   # already in an attack window – ignore until it closes
	_attack_active = true
	_attack_timer  = attack_active_frames
	attack_hitbox_enable.emit(true)

	var final_damage := base_damage * _current_dmg_mult
	attack_landed.emit(final_damage)


## Returns the current heat-scaled damage multiplier (read by Player.gd).
func get_damage_multiplier() -> float:
	return _current_dmg_mult


## Returns the current heat-scaled speed multiplier (read by Player.gd).
func get_speed_multiplier() -> float:
	return _current_speed_mult


## Player.gd can call this every frame:
##   velocity = velocity.normalized() * base_speed * HUD.get_speed_multiplier()
func get_scaled_speed(base_speed: float) -> float:
	return base_speed * _current_speed_mult


## Returns the damage a single hit should deal right now.
func get_scaled_damage() -> float:
	return base_damage * _current_dmg_mult


# ═══════════════════════════════════════════════════════════════════════════════
#  INTERNAL – tier / multiplier updates
# ═══════════════════════════════════════════════════════════════════════════════
func _update_tier(tier: String) -> void:
	if tier == _current_tier:
		return
	_current_tier      = tier
	_current_dmg_mult  = HeatManager.get_damage_multiplier()
	_current_speed_mult = SPEED_MULTIPLIERS.get(tier, 1.0)

	damage_multiplier_changed.emit(_current_dmg_mult)
	speed_multiplier_changed.emit(_current_speed_mult)

	# Visual feedback on tier change
	_show_tier_flash(tier)


func _pulse_heat_bar(bright: bool) -> void:
	if heat_bar:
		heat_bar.modulate.a = 1.0 if bright else 0.35


func _show_tier_flash(tier: String) -> void:
	# Brief colour flash on the tier label so the player notices the change.
	if tier_label and TIER_COLOURS.has(tier):
		var c : Color = TIER_COLOURS[tier]
		tier_label.add_theme_color_override("font_color", c.lightened(0.4))
		# Fade back after a short tween
		var tw := create_tween()
		tw.tween_property(tier_label, "theme_override_colors/font_color",
						  COLOR_TEXT, 0.6)


# ═══════════════════════════════════════════════════════════════════════════════
#  DRAWING
# ═══════════════════════════════════════════════════════════════════════════════
func _draw_cooldown_circles(canvas: Control) -> void:
	var dash_ratio := 1.0 - (_dash_cooldown / _dash_max_cooldown)
	var roll_ratio := 1.0 - (_roll_cooldown / _roll_max_cooldown)
	_draw_one_circle(canvas, _dash_centre, dash_ratio, _dash_cooldown,
					 COLOR_DASH_WORM, "DASH")
	_draw_one_circle(canvas, _roll_centre, roll_ratio, _roll_cooldown,
					 COLOR_ROLL_WORM, "ROLL")


func _draw_one_circle(canvas: Control, centre: Vector2, fill_ratio: float,
					  remaining: float, worm_color: Color, label: String) -> void:
	var font   := ThemeDB.fallback_font
	var r      := CIRCLE_RADIUS
	var aw     := ARC_WIDTH
	var ring_r := r + aw * 0.5

	canvas.draw_circle(centre, r + aw + 1.0, Color(0.0, 0.0, 0.0, 0.4))
	canvas.draw_circle(centre, r, COLOR_BG_DISC)
	_draw_arc(canvas, centre, ring_r, 0.0, TAU, COLOR_TRACK_EDGE, aw + 2.0)
	_draw_arc(canvas, centre, ring_r, 0.0, TAU, COLOR_TRACK,      aw)

	if fill_ratio > 0.005:
		var sweep := TAU * fill_ratio
		_draw_arc(canvas, centre, ring_r,
				  -PI * 0.5, -PI * 0.5 + sweep, worm_color, aw)
		var tail_angle := -PI * 0.5
		var tail_pos   := centre + Vector2(cos(tail_angle), sin(tail_angle)) * ring_r
		canvas.draw_circle(tail_pos, CAP_RADIUS, worm_color)
		var head_angle := -PI * 0.5 + sweep
		var head_pos   := centre + Vector2(cos(head_angle), sin(head_angle)) * ring_r
		var head_color := worm_color.lightened(0.35)
		canvas.draw_circle(head_pos, CAP_RADIUS, head_color)
		canvas.draw_circle(head_pos, CAP_RADIUS * 0.45, Color(1.0, 1.0, 1.0, 0.55))

	var display : String
	if remaining > 0.05:
		display = "%.1f" % remaining
	elif fill_ratio >= 1.0:
		display = "RDY"
	else:
		display = ""

	if display != "":
		var fsz     := 13
		var tw      := font.get_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz)
		var txt_pos := centre + Vector2(-tw.x * 0.5, tw.y * 0.33)
		canvas.draw_string(font, txt_pos, display,
						   HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, COLOR_TEXT)

	var lsz     := 11
	var lw      := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, lsz).x
	var lbl_pos := Vector2(centre.x - lw * 0.5, centre.y + r + aw + 10.0)
	canvas.draw_string(font, lbl_pos, label,
					   HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, COLOR_LABEL)


func _draw_arc(canvas: Control, centre: Vector2, radius: float,
			   from_a: float, to_a: float, color: Color, width: float) -> void:
	var pts  := PackedVector2Array()
	var span := to_a - from_a
	var segs: int = max(int(abs(span) / TAU * float(ARC_SEGMENTS)), 2)
	for i in range(segs + 1):
		var a := from_a + span * (float(i) / float(segs))
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	canvas.draw_polyline(pts, color, width, true)


# ═══════════════════════════════════════════════════════════════════════════════
#  SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════
func _on_dash_performed() -> void:
	_dash_cooldown = _dash_max_cooldown
	if _draw_node: _draw_node.queue_redraw()

func _on_roll_performed() -> void:
	_roll_cooldown = _roll_max_cooldown
	if _draw_node: _draw_node.queue_redraw()

func _on_heat_changed(new_value: float, tier: String) -> void:
	_refresh_heat_ui(new_value, tier)
	_update_tier(tier)   # this is where multipliers + speed update


func _refresh_heat_ui(value: float, tier: String) -> void:
	var fill_ratio : float = value / HeatManager.max_heat
	var bar_size           := heat_bar.size
	bar_size.x             = fill_ratio * HEAT_BAR_MAX_WIDTH
	heat_bar.size          = bar_size
	if TIER_COLOURS.has(tier):
		heat_bar.color = TIER_COLOURS[tier]
	heat_label.text = "Heat: %.1f / %.0f  |  x%.2f dmg  |  x%.2f spd" % [
		value, HeatManager.max_heat,
		_current_dmg_mult, _current_speed_mult
	]
	tier_label.text = tier.to_upper()


# ═══════════════════════════════════════════════════════════════════════════════
#  FOOD SLOTS & HEALTH  (unchanged)
# ═══════════════════════════════════════════════════════════════════════════════
func update_food_slots(items: Array) -> void:
	for child in food_slots.get_children():
		child.queue_free()
	for item in items:
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(32, 32)
		slot.color = item.get("colour", Color(0.4, 0.4, 0.4))
		food_slots.add_child(slot)


func update_health(current: float, maximum: float) -> void:
	if health_bar is TextureProgressBar:
		health_bar.max_value = maximum
		health_bar.value     = current
	elif health_bar is ColorRect:
		var s : Vector2 = health_bar.size
		s.x = (current / maximum) * 200.0
		health_bar.size = s

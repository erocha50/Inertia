extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════════
#  HUD.gd
# ═══════════════════════════════════════════════════════════════════════════════

@onready var heat_bar_bg: ColorRect      = $HeatBarBG
@onready var heat_bar: ColorRect         = $HeatBar
@onready var heat_label: Label           = $HeatLabel
@onready var tier_label: Label           = $TierLabel
@onready var health_bar                  = $HealthBar
@onready var food_slots: HBoxContainer   = $FoodSlots

const HEAT_BAR_MAX_WIDTH  := 300.0
const HP_BAR_MAX_WIDTH    := 300.0

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

# ── HP bar colours ─────────────────────────────────────────────────────────────
const HP_COLOR_FULL   := Color(0.18, 0.85, 0.38)   # green
const HP_COLOR_MID    := Color(0.95, 0.75, 0.1)    # yellow
const HP_COLOR_LOW    := Color(0.9,  0.18, 0.12)   # red
const HP_COLOR_BG     := Color(0.08, 0.08, 0.08, 0.85)
const HP_COLOR_EDGE   := Color(0.0,  0.0,  0.0,   0.6)  # dark border
const HP_COLOR_SHINE  := Color(1.0,  1.0,  1.0,   0.1)  # highlight shine

# ── HP bar nodes (built in code) ───────────────────────────────────────────────
var _hp_bar_bg:       ColorRect = null
var _hp_bar_fill:     ColorRect = null
var _hp_bar_border:   Control   = null
var _hp_bar_shine:    ColorRect = null
var _hp_label:        Label     = null
var _hp_flash_t:      float     = 0.0
var _hp_flash_on:     bool      = false

class _HPBarBorderDrawer extends Control:
	var hud : Node
	func _draw() -> void:
		if hud: hud._draw_hp_bar_border(self)

class _CooldownDrawer extends Control:
	var hud : Node
	func _draw() -> void:
		if hud: hud._draw_cooldown_circles(self)

var _draw_node  : _CooldownDrawer
var _dash_centre: Vector2
var _roll_centre: Vector2

const TIER_COLOURS := {
	"cold":    Color(0.2, 0.5, 1.0),
	"warm":    Color(1.0, 0.75, 0.2),
	"hot":     Color(1.0, 0.4, 0.1),
	"burning": Color(0.9, 0.1, 0.05),
}

# ── Combat system ──────────────────────────────────────────────────────────────
signal attack_hitbox_enable(enabled: bool)
signal damage_multiplier_changed(multiplier: float)
signal speed_multiplier_changed(multiplier: float)
signal attack_landed(damage: float)

const SPEED_MULTIPLIERS := {
	"cold": 0.75, "warm": 1.0, "hot": 1.20, "burning": 1.45,
}

var base_damage          : float  = 10.0
var attack_active_frames : float  = 0.25
var _attack_active       : bool   = false
var _attack_timer        : float  = 0.0
var _current_tier        : String = "cold"
var _current_dmg_mult    : float  = 0.5
var _current_speed_mult  : float  = 0.75

const LOW_HEAT_THRESHOLD := 0.15
var _flash_timer : float = 0.0
var _flash_state : bool  = false


# ═══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	HeatManager.heat_changed.connect(_on_heat_changed)
	HealthManager.health_changed.connect(_on_health_changed)

	_refresh_heat_ui(HeatManager.heat_value, HeatManager.get_tier())
	_update_tier(HeatManager.get_tier())
	heat_label.visible = true

	_build_hp_bar()
	_refresh_hp_ui(HealthManager.hp, HealthManager.max_hp)

	await get_tree().process_frame
	_recompute_positions()
	get_tree().root.size_changed.connect(_recompute_positions)

	_draw_node     = _CooldownDrawer.new()
	_draw_node.hud = self
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	var root   : Node = get_tree().root.get_child(0)
	var player : Node = root.find_child("Player", true, false)
	if player:
		_player = player
		if "dash_attack_cooldown" in player: _dash_max_cooldown = player.dash_attack_cooldown
		if "roll_cooldown"        in player: _roll_max_cooldown  = player.roll_cooldown
		if player.has_signal("dash_attack_performed"): player.dash_attack_performed.connect(_on_dash_performed)
		if player.has_signal("roll_performed"):        player.roll_performed.connect(_on_roll_performed)
		if "base_damage" in player: base_damage = player.base_damage


func _build_hp_bar() -> void:
	# Build the HP bar entirely in code, positioned just below the heat bar
	# Adjust position offsets to fit your HUD layout
	var hp_y: float = 68.0   # ← move this if the bar overlaps other elements
	var bar_width: float = HP_BAR_MAX_WIDTH
	var bar_height: float = 16
	var border_width: float = 2

	# Background container (darker, has border visuals)
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color                = HP_COLOR_BG
	_hp_bar_bg.size                 = Vector2(bar_width + border_width * 2, bar_height)
	_hp_bar_bg.position             = Vector2(8.0, hp_y)
	add_child(_hp_bar_bg)

	# Fill bar (dynamic width)
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color              = HP_COLOR_FULL
	_hp_bar_fill.size               = Vector2(bar_width, bar_height - border_width * 2)
	_hp_bar_fill.position           = Vector2(border_width, border_width)
	_hp_bar_bg.add_child(_hp_bar_fill)

	# Shine/highlight effect on top
	_hp_bar_shine = ColorRect.new()
	_hp_bar_shine.color             = HP_COLOR_SHINE
	_hp_bar_shine.size              = Vector2(bar_width, 2)
	_hp_bar_shine.position          = Vector2(border_width, border_width)
	_hp_bar_bg.add_child(_hp_bar_shine)

	# Border drawer for crisp edges
	var border_drawer := _HPBarBorderDrawer.new()
	border_drawer.hud = self
	border_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar_border = border_drawer
	_hp_bar_bg.add_child(_hp_bar_border)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_hp_label.position              = Vector2(bar_width + 15.0, hp_y + 1.0)
	_hp_label.text                  = "100 HP"
	add_child(_hp_label)


func _recompute_positions() -> void:
	var vp     := get_tree().root.size
	var slot   := (CIRCLE_RADIUS + ARC_WIDTH) * 2.0
	var base_y := vp.y - MARGIN - slot * 0.5 - 14.0
	var base_x := MARGIN + slot * 0.5
	_dash_centre = Vector2(base_x, base_y)
	_roll_centre = Vector2(base_x + slot + CIRCLE_SPACING, base_y)
	if _draw_node: _draw_node.queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
#  PROCESS
# ═══════════════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	var dirty := false
	if _dash_cooldown > 0.0:
		_dash_cooldown = max(0.0, _dash_cooldown - delta); dirty = true
	if _roll_cooldown > 0.0:
		_roll_cooldown = max(0.0, _roll_cooldown - delta); dirty = true
	if dirty and _draw_node: _draw_node.queue_redraw()

	if _attack_active:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_active = false
			attack_hitbox_enable.emit(false)

	# Heat flash
	var heat_ratio : float = HeatManager.heat_value / HeatManager.max_heat
	if heat_ratio < LOW_HEAT_THRESHOLD:
		_flash_timer += delta
		if _flash_timer >= 0.4:
			_flash_timer = 0.0; _flash_state = !_flash_state
			_pulse_heat_bar(_flash_state)
	else:
		_flash_state = false; _flash_timer = 0.0
		_pulse_heat_bar(false)

	# HP bar low-health pulse (below 25%)
	var hp_ratio := HealthManager.hp / HealthManager.max_hp
	if hp_ratio < 0.25 and _hp_bar_fill:
		_hp_flash_t += delta * 4.0
		_hp_bar_fill.modulate.a = lerpf(0.4, 1.0, sin(_hp_flash_t) * 0.5 + 0.5)
	elif _hp_bar_fill:
		_hp_flash_t   = 0.0
		_hp_bar_fill.modulate.a = 1.0

	# Redraw HP bar border
	if _hp_bar_border:
		_hp_bar_border.queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════
func request_attack() -> void:
	if _attack_active: return
	_attack_active = true; _attack_timer = attack_active_frames
	attack_hitbox_enable.emit(true)
	attack_landed.emit(base_damage * _current_dmg_mult)

func get_damage_multiplier() -> float: return _current_dmg_mult
func get_speed_multiplier()  -> float: return _current_speed_mult
func get_scaled_speed(base_speed: float) -> float: return base_speed * _current_speed_mult
func get_scaled_damage() -> float: return base_damage * _current_dmg_mult


# ═══════════════════════════════════════════════════════════════════════════════
#  INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════
func _update_tier(tier: String) -> void:
	if tier == _current_tier: return
	_current_tier       = tier
	_current_dmg_mult   = HeatManager.get_damage_multiplier()
	_current_speed_mult = SPEED_MULTIPLIERS.get(tier, 1.0)
	damage_multiplier_changed.emit(_current_dmg_mult)
	speed_multiplier_changed.emit(_current_speed_mult)
	_show_tier_flash(tier)

func _pulse_heat_bar(bright: bool) -> void:
	if heat_bar: heat_bar.modulate.a = 1.0 if bright else 0.35

func _show_tier_flash(tier: String) -> void:
	if tier_label and TIER_COLOURS.has(tier):
		tier_label.add_theme_color_override("font_color", TIER_COLOURS[tier].lightened(0.4))
		var tw := create_tween()
		tw.tween_property(tier_label, "theme_override_colors/font_color", COLOR_TEXT, 0.6)


# ═══════════════════════════════════════════════════════════════════════════════
#  DRAWING
# ═══════════════════════════════════════════════════════════════════════════════
func _draw_cooldown_circles(canvas: Control) -> void:
	_draw_one_circle(canvas, _dash_centre,
		1.0 - (_dash_cooldown / _dash_max_cooldown), _dash_cooldown, COLOR_DASH_WORM, "DASH")
	_draw_one_circle(canvas, _roll_centre,
		1.0 - (_roll_cooldown / _roll_max_cooldown), _roll_cooldown, COLOR_ROLL_WORM, "ROLL")

func _draw_one_circle(canvas: Control, centre: Vector2, fill_ratio: float,
					  remaining: float, worm_color: Color, label: String) -> void:
	var font   := ThemeDB.fallback_font
	var r      := CIRCLE_RADIUS; var aw := ARC_WIDTH
	var ring_r := r + aw * 0.5
	canvas.draw_circle(centre, r + aw + 1.0, Color(0.0, 0.0, 0.0, 0.4))
	canvas.draw_circle(centre, r, COLOR_BG_DISC)
	_draw_arc(canvas, centre, ring_r, 0.0, TAU, COLOR_TRACK_EDGE, aw + 2.0)
	_draw_arc(canvas, centre, ring_r, 0.0, TAU, COLOR_TRACK,      aw)
	if fill_ratio > 0.005:
		var sweep := TAU * fill_ratio
		_draw_arc(canvas, centre, ring_r, -PI*0.5, -PI*0.5+sweep, worm_color, aw)
		var tail_pos := centre + Vector2(cos(-PI*0.5), sin(-PI*0.5)) * ring_r
		canvas.draw_circle(tail_pos, CAP_RADIUS, worm_color)
		var head_angle := -PI*0.5+sweep
		var head_pos   := centre + Vector2(cos(head_angle), sin(head_angle)) * ring_r
		var head_color := worm_color.lightened(0.35)
		canvas.draw_circle(head_pos, CAP_RADIUS, head_color)
		canvas.draw_circle(head_pos, CAP_RADIUS * 0.45, Color(1.0, 1.0, 1.0, 0.55))
	var display : String
	if remaining > 0.05:      display = "%.1f" % remaining
	elif fill_ratio >= 1.0:   display = "RDY"
	else:                     display = ""
	if display != "":
		var fsz := 13
		var tw  := font.get_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz)
		canvas.draw_string(font, centre + Vector2(-tw.x*0.5, tw.y*0.33),
						   display, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, COLOR_TEXT)
	var lsz := 11
	var lw  := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, lsz).x
	canvas.draw_string(font, Vector2(centre.x - lw*0.5, centre.y + r + aw + 10.0),
					   label, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, COLOR_LABEL)

func _draw_arc(canvas: Control, centre: Vector2, radius: float,
			   from_a: float, to_a: float, color: Color, width: float) -> void:
	var pts  := PackedVector2Array()
	var span := to_a - from_a
	var segs : int = max(int(abs(span) / TAU * float(ARC_SEGMENTS)), 2)
	for i in range(segs + 1):
		pts.append(centre + Vector2(cos(from_a + span*(float(i)/float(segs))),
									sin(from_a + span*(float(i)/float(segs)))) * radius)
	canvas.draw_polyline(pts, color, width, true)

func _draw_hp_bar_border(canvas: Control) -> void:
	# Draw crisp border around HP bar
	var size := canvas.get_rect().size
	var border: float = 2.0
	# Top edge
	canvas.draw_line(Vector2(0, 0), Vector2(size.x, 0), HP_COLOR_EDGE, border, true)
	# Bottom edge
	canvas.draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Color(0.0, 0.0, 0.0, 0.3), border, true)
	# Left edge
	canvas.draw_line(Vector2(0, 0), Vector2(0, size.y), HP_COLOR_EDGE, border, true)
	# Right edge
	canvas.draw_line(Vector2(size.x, 0), Vector2(size.x, size.y), HP_COLOR_EDGE, border, true)


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
	_update_tier(tier)

func _on_health_changed(new_hp: float, max_hp: float) -> void:
	_refresh_hp_ui(new_hp, max_hp)

func _on_wallhop_assist_changed(active: bool, time_scale: float) -> void:
	_wallhop_assist_active = active
	_wallhop_time_scale_display = time_scale


func _refresh_heat_ui(value: float, tier: String) -> void:
	var fill_ratio : float = value / HeatManager.max_heat
	heat_bar.size.x        = fill_ratio * HEAT_BAR_MAX_WIDTH
	if TIER_COLOURS.has(tier): heat_bar.color = TIER_COLOURS[tier]
	heat_label.text = "Heat: %.1f / %.0f  |  x%.2f dmg  |  x%.2f spd" % [
		value, HeatManager.max_heat, _current_dmg_mult, _current_speed_mult]
	tier_label.text = tier.to_upper()

func _create_wallhop_assist_label() -> void:
	wallhop_assist_label = Label.new()
	wallhop_assist_label.text = "⏱ WALLHOP ASSIST"
	wallhop_assist_label.add_theme_font_size_override("font_size", 18)
	wallhop_assist_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 0.95))
	wallhop_assist_label.position = Vector2(get_viewport_rect().size.x * 0.5 - 100, 40)
	wallhop_assist_label.custom_minimum_size = Vector2(200, 30)
	wallhop_assist_label.visible = false
	add_child(wallhop_assist_label)


func _refresh_hp_ui(hp: float, max_hp: float) -> void:
	if _hp_bar_fill == null:
		return

	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_hp_bar_fill.size.x = ratio * HP_BAR_MAX_WIDTH

	# Colour shifts green → yellow → red as HP drops
	var fill_color: Color
	if ratio > 0.5:
		fill_color = HP_COLOR_FULL.lerp(HP_COLOR_MID, (1.0 - ratio) * 2.0)
	else:
		fill_color = HP_COLOR_MID.lerp(HP_COLOR_LOW, (0.5 - ratio) * 2.0)
	_hp_bar_fill.color = fill_color

	if _hp_label:
		_hp_label.text = "%d HP" % int(hp)


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
	_refresh_hp_ui(current, maximum)

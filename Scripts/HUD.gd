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

const HEAT_BAR_MAX_WIDTH  := 420.0
const HP_BAR_MAX_WIDTH    := 300.0

# ── Cooldown state ─────────────────────────────────────────────────────────────
var _dash_cooldown     : float = 0.0
var _dash_max_cooldown : float = 5.0
var _roll_cooldown     : float = 0.0
var _roll_max_cooldown : float = 3.0
var _player: Node = null

# ── Wallhop assist state ───────────────────────────────────────────────────────
var _wallhop_assist_active : bool = false
var _wallhop_time_scale_display : float = 1.0
var wallhop_assist_label : Label = null

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

# ── Heat bar (diagonal segmented) ──────────────────────────────────────────────
const HEAT_SEGMENTS         := 16      # number of diagonal stripes
const HEAT_BAR_HEIGHT_OLD    := 22.0   # previous height, used to nudge the scene-placed labels down
const HEAT_BAR_HEIGHT        := 34.0
const HEAT_SEG_SKEW          := 13.0   # horizontal slant of each stripe (px)
const HEAT_SEG_GAP           := 4.0    # gap between stripes (px)
const HEAT_SEG_BORDER        := 3.0    # white outline thickness
const HEAT_COLOR_EMPTY       := Color(0.14, 0.14, 0.17, 0.9)   # unlit stripe
const HEAT_COLOR_EMPTY_EDGE  := Color(1.0,  1.0,  1.0,  0.12)  # unlit outline
const HEAT_COLOR_EDGE        := Color(1.0,  1.0,  1.0,  0.95)  # lit outline (white, like the ref)
const HEAT_SHINE_PERIOD      := 1.8    # seconds for one shine sweep

# ── HP bar colours ─────────────────────────────────────────────────────────────
const HP_COLOR_FULL   := Color(0.18, 0.85, 0.38)   # green
const HP_COLOR_MID    := Color(0.95, 0.75, 0.1)    # yellow
const HP_COLOR_LOW    := Color(0.9,  0.18, 0.12)   # red
const HP_COLOR_BG     := Color(0.08, 0.08, 0.08, 0.85)
const HP_COLOR_EDGE   := Color(0.0,  0.0,  0.0,   0.6)  # dark border
const HP_COLOR_SHINE  := Color(1.0,  1.0,  1.0,   0.16) # glossy top highlight
const HP_COLOR_TRAIL  := Color(0.55, 0.1,  0.08,  0.9)  # lagging "damage taken" shadow
const HP_TRAIL_HOLD_TIME     := 0.35   # seconds the trail holds before it starts draining
const HP_TRAIL_CATCHUP_SPEED := 2.5    # how fast the trail drains down to match (ratio/sec)

# ── HP bar nodes (built in code) ───────────────────────────────────────────────
var _hp_bar_bg:         Panel        = null
var _hp_bar_fill:       Panel        = null
var _hp_bar_trail:      Panel        = null
var _hp_bar_shine:      Panel        = null
var _hp_bar_fill_style: StyleBoxFlat = null
var _hp_label:          Label        = null
var _hp_flash_t:        float        = 0.0
var _hp_inner_width:    float        = 0.0
var _hp_target_ratio:   float        = 1.0
var _hp_trail_ratio:    float        = 1.0
var _hp_trail_hold_t:   float        = 0.0

# ── Heat bar drawer (built in code) ────────────────────────────────────────────
var _heat_bar_drawer     : Control = null
var _heat_fill_ratio     : float   = 0.0   # target ratio, set from HeatManager
var _heat_display_ratio  : float   = 0.0   # eased ratio used for drawing (smooth fill)
var _heat_shine_t        : float   = 0.0
var _heat_bar_alpha      : float   = 1.0   # driven by the existing low-heat flash

class _CooldownDrawer extends Control:
	var hud : Node
	func _draw() -> void:
		if hud: hud._draw_cooldown_circles(self)

class _HeatBarDrawer extends Control:
	var hud : Node
	func _draw() -> void:
		if hud: hud._draw_heat_bar(self)

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

	_build_heat_bar()
	_style_heat_text()
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
		if player.has_signal("state_changed"): player.state_changed.connect(_on_player_state_changed)
	
	_create_wallhop_assist_label()


func _build_heat_bar() -> void:
	# Replaces the flat ColorRect fill with a diagonal segmented "fuel gauge" bar,
	# drawn in code. heat_bar_bg/heat_bar stay in the scene (hidden) purely so we
	# can read their anchoring — HeatBarBG is anchored to the bottom-right corner
	# (offset_right = -20, offset_left = -320), so the bar is meant to grow
	# LEFTWARD from a fixed margin off the right edge, not rightward from a
	# fixed left position. Mirroring that anchoring keeps it on-screen and
	# correctly placed at any resolution.
	if heat_bar_bg: heat_bar_bg.visible = false
	if heat_bar:    heat_bar.visible    = false

	var pad     : float = 6.0   # room for the outer glow so it doesn't get clipped
	var total_w : float = HEAT_BAR_MAX_WIDTH + HEAT_SEG_SKEW + pad * 2.0
	var total_h : float = HEAT_BAR_HEIGHT + pad * 2.0

	var margin_right  : float = heat_bar_bg.offset_right  if heat_bar_bg else -20.0
	var margin_bottom : float = heat_bar_bg.offset_bottom if heat_bar_bg else -50.0
	var left_extent   : float = margin_right - total_w   # how far left the bar now reaches

	var drawer := _HeatBarDrawer.new()
	drawer.hud            = self
	drawer.anchor_left    = 1.0
	drawer.anchor_top     = 1.0
	drawer.anchor_right   = 1.0
	drawer.anchor_bottom  = 1.0
	drawer.offset_left    = left_extent
	drawer.offset_top     = margin_bottom - total_h
	drawer.offset_right   = margin_right
	drawer.offset_bottom  = margin_bottom
	drawer.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	add_child(drawer)
	_heat_bar_drawer = drawer

	# Widen the scene-placed labels to match, and drop them down to clear the
	# taller bar — same right margin, same left extent, so everything lines up.
	var bottom_shift := total_h - (HEAT_BAR_HEIGHT_OLD + pad * 2.0)
	if heat_label:
		heat_label.offset_left    = left_extent
		heat_label.offset_right   = margin_right
		heat_label.offset_top    += bottom_shift
		heat_label.offset_bottom += bottom_shift
	if tier_label:
		tier_label.offset_left  = left_extent
		tier_label.offset_right = margin_right
		tier_label.offset_top  += bottom_shift


func _style_heat_text() -> void:
	# Bigger, bolder, with an outline so it stays readable over any background.
	if heat_label:
		heat_label.add_theme_font_size_override("font_size", 20)
		heat_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		heat_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		heat_label.add_theme_constant_override("outline_size", 5)
		heat_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
		heat_label.add_theme_constant_override("shadow_offset_x", 1)
		heat_label.add_theme_constant_override("shadow_offset_y", 2)

	if tier_label:
		tier_label.add_theme_font_size_override("font_size", 28)
		tier_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		tier_label.add_theme_constant_override("outline_size", 6)
		tier_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
		tier_label.add_theme_constant_override("shadow_offset_x", 1)
		tier_label.add_theme_constant_override("shadow_offset_y", 2)


func _build_hp_bar() -> void:
	# Rounded, bordered HP bar with a lagging "damage trail". Built with Panel +
	# StyleBoxFlat so corner rounding and the border come for free — no custom
	# drawing needed.
	var hp_y       : float = 68.0   # ← move this if the bar overlaps other elements
	var bar_width  : float = HP_BAR_MAX_WIDTH
	var bar_height : float = 22.0
	var border_w   : float = 2.0
	var corner_r   : int   = 6

	_hp_inner_width = bar_width

	_hp_bar_bg = Panel.new()
	_hp_bar_bg.position = Vector2(8.0, hp_y)
	_hp_bar_bg.size     = Vector2(bar_width + border_w * 2.0, bar_height)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = HP_COLOR_BG
	bg_style.set_corner_radius_all(corner_r)
	bg_style.set_border_width_all(int(border_w))
	bg_style.border_color = HP_COLOR_EDGE
	_hp_bar_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_hp_bar_bg)

	# Damage trail — sits behind the fill, holds briefly then drains down to
	# match, exposing a red "shadow" the width of what you just lost.
	_hp_bar_trail = Panel.new()
	_hp_bar_trail.position = Vector2(border_w, border_w)
	_hp_bar_trail.size     = Vector2(bar_width, bar_height - border_w * 2.0)
	var trail_style := StyleBoxFlat.new()
	trail_style.bg_color = HP_COLOR_TRAIL
	trail_style.set_corner_radius_all(max(corner_r - 2, 0))
	_hp_bar_trail.add_theme_stylebox_override("panel", trail_style)
	_hp_bar_bg.add_child(_hp_bar_trail)

	# Fill — drawn on top of the trail, updates instantly for responsive feedback
	_hp_bar_fill = Panel.new()
	_hp_bar_fill.position      = Vector2(border_w, border_w)
	_hp_bar_fill.size          = Vector2(bar_width, bar_height - border_w * 2.0)
	_hp_bar_fill.clip_contents = true   # clips the shine child as the bar shrinks
	_hp_bar_fill_style = StyleBoxFlat.new()
	_hp_bar_fill_style.bg_color = HP_COLOR_FULL
	_hp_bar_fill_style.set_corner_radius_all(max(corner_r - 2, 0))
	_hp_bar_fill.add_theme_stylebox_override("panel", _hp_bar_fill_style)
	_hp_bar_bg.add_child(_hp_bar_fill)

	# Glossy top highlight — child of the fill, so it clips/shrinks along with it
	_hp_bar_shine = Panel.new()
	_hp_bar_shine.position     = Vector2(0.0, 0.0)
	_hp_bar_shine.size         = Vector2(bar_width, (bar_height - border_w * 2.0) * 0.4)
	_hp_bar_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shine_style := StyleBoxFlat.new()
	shine_style.bg_color                = HP_COLOR_SHINE
	shine_style.corner_radius_top_left  = max(corner_r - 2, 0)
	shine_style.corner_radius_top_right = max(corner_r - 2, 0)
	_hp_bar_shine.add_theme_stylebox_override("panel", shine_style)
	_hp_bar_fill.add_child(_hp_bar_shine)

	_hp_label = Label.new()
	_hp_label.position = Vector2(bar_width + border_w * 2.0 + 12.0, hp_y - 3.0)
	_hp_label.text     = "100 HP"
	_hp_label.add_theme_font_size_override("font_size", 16)
	_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_hp_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_hp_label.add_theme_constant_override("outline_size", 4)
	_hp_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 2)
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

	# Heat bar: ease the drawn fill toward the target ratio and animate the shine sweep
	if _heat_bar_drawer:
		_heat_display_ratio = lerp(_heat_display_ratio, _heat_fill_ratio, clampf(delta * 8.0, 0.0, 1.0))
		_heat_shine_t += delta
		_heat_bar_drawer.queue_redraw()

	# HP bar low-health pulse (below 25%)
	var hp_ratio := HealthManager.hp / HealthManager.max_hp
	if hp_ratio < 0.25 and _hp_bar_fill:
		_hp_flash_t += delta * 4.0
		_hp_bar_fill.modulate.a = lerpf(0.4, 1.0, sin(_hp_flash_t) * 0.5 + 0.5)
	elif _hp_bar_fill:
		_hp_flash_t = 0.0
		_hp_bar_fill.modulate.a = 1.0

	# HP damage trail — holds briefly after a hit, then drains down to match the fill
	if _hp_bar_trail:
		if _hp_trail_hold_t > 0.0:
			_hp_trail_hold_t = max(0.0, _hp_trail_hold_t - delta)
		else:
			_hp_trail_ratio = move_toward(_hp_trail_ratio, _hp_target_ratio, HP_TRAIL_CATCHUP_SPEED * delta)
		_hp_bar_trail.size.x = clampf(_hp_trail_ratio, 0.0, 1.0) * _hp_inner_width


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
	_heat_bar_alpha = 1.0 if bright else 0.35
	if _heat_bar_drawer: _heat_bar_drawer.queue_redraw()

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



func _draw_heat_bar(canvas: Control) -> void:
	# Diagonal segmented "fuel gauge" bar. All stripes share the same skew so
	# they read as one continuous slanted strip, like the reference image.
	var origin   := Vector2(6.0, 6.0)   # inner padding, matches _build_heat_bar's `pad`
	var h        := HEAT_BAR_HEIGHT
	var seg_w    := (HEAT_BAR_MAX_WIDTH - float(HEAT_SEGMENTS - 1) * HEAT_SEG_GAP) / float(HEAT_SEGMENTS)
	var tier_col : Color = TIER_COLOURS.get(_current_tier, Color(1.0, 1.0, 1.0))

	var lit_f     := _heat_display_ratio * float(HEAT_SEGMENTS)
	var lit_count := int(floor(lit_f))
	var partial   := clampf(lit_f - float(lit_count), 0.0, 1.0)
	var lit_width := (float(lit_count) * (seg_w + HEAT_SEG_GAP)) + (seg_w * partial)

	# soft glow behind the lit portion — colour matches the current tier
	if lit_width > 1.0:
		var glow_col := tier_col
		glow_col.a = 0.28 * _heat_bar_alpha
		canvas.draw_rect(Rect2(origin - Vector2(3.0, 3.0),
			Vector2(lit_width + HEAT_SEG_SKEW + 6.0, h + 6.0)), glow_col, true)

	for i in range(HEAT_SEGMENTS):
		var x0 := origin.x + float(i) * (seg_w + HEAT_SEG_GAP)
		var top_left  := Vector2(x0 + HEAT_SEG_SKEW,          origin.y)
		var top_right := Vector2(x0 + HEAT_SEG_SKEW + seg_w,  origin.y)
		var bot_right := Vector2(x0 + seg_w,                  origin.y + h)
		var bot_left  := Vector2(x0,                          origin.y + h)
		var poly := PackedVector2Array([top_left, top_right, bot_right, bot_left])

		var fill_color : Color
		var edge_color : Color
		if i < lit_count:
			fill_color = tier_col
			edge_color = HEAT_COLOR_EDGE
		elif i == lit_count and partial > 0.02:
			fill_color = HEAT_COLOR_EMPTY.lerp(tier_col, partial)
			edge_color = HEAT_COLOR_EMPTY_EDGE.lerp(HEAT_COLOR_EDGE, partial)
		else:
			fill_color = HEAT_COLOR_EMPTY
			edge_color = HEAT_COLOR_EMPTY_EDGE
		fill_color.a *= _heat_bar_alpha

		canvas.draw_colored_polygon(poly, fill_color)

		# glossy highlight strip along the top of lit/filling segments
		if i <= lit_count:
			var hi_top_l := top_left  + Vector2(0.0, 1.5)
			var hi_top_r := top_right + Vector2(0.0, 1.5)
			var hi_bot_r := top_right + Vector2(-2.0, h * 0.35)
			var hi_bot_l := top_left  + Vector2(2.0,  h * 0.35)
			var hi_col := Color(1.0, 1.0, 1.0, 0.22 * _heat_bar_alpha)
			canvas.draw_colored_polygon(PackedVector2Array([hi_top_l, hi_top_r, hi_bot_r, hi_bot_l]), hi_col)

		var outline := PackedVector2Array([top_left, top_right, bot_right, bot_left, top_left])
		canvas.draw_polyline(outline, edge_color, HEAT_SEG_BORDER, true)

	# slow shine sweep across the lit portion for a bit of extra polish
	if lit_width > 4.0:
		var t        := fmod(_heat_shine_t, HEAT_SHINE_PERIOD) / HEAT_SHINE_PERIOD
		var shine_w  := 14.0
		var shine_x  := origin.x - shine_w + t * (lit_width + shine_w * 2.0)
		var s_top_l := Vector2(shine_x + HEAT_SEG_SKEW,         origin.y)
		var s_top_r := Vector2(shine_x + HEAT_SEG_SKEW + shine_w, origin.y)
		var s_bot_r := Vector2(shine_x + shine_w,               origin.y + h)
		var s_bot_l := Vector2(shine_x,                         origin.y + h)
		var shine_col := Color(1.0, 1.0, 1.0, 0.16 * _heat_bar_alpha)
		canvas.draw_colored_polygon(PackedVector2Array([s_top_l, s_top_r, s_bot_r, s_bot_l]), shine_col)


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

func _on_player_state_changed(new_state: int) -> void:
	# States from player_controller.gd:
	# enum State { IDLE, RUN, AIR, SLIDE, ARC, WALL_RIDE }
	# State 5 is WALL_RIDE
	_wallhop_assist_active = (new_state == 5)
	if wallhop_assist_label:
		wallhop_assist_label.visible = _wallhop_assist_active

func _on_wallhop_assist_changed(active: bool, time_scale: float) -> void:
	_wallhop_assist_active = active
	_wallhop_time_scale_display = time_scale


func _refresh_heat_ui(value: float, tier: String) -> void:
	var fill_ratio : float = value / HeatManager.max_heat
	_heat_fill_ratio        = clampf(fill_ratio, 0.0, 1.0)
	heat_label.text = "HEAT  %.1f/%.0f   ×%.2f DMG   ×%.2f SPD" % [
		value, HeatManager.max_heat, _current_dmg_mult, _current_speed_mult]
	tier_label.text = tier.to_upper()
	if _heat_bar_drawer: _heat_bar_drawer.queue_redraw()

func _create_wallhop_assist_label() -> void:
	if wallhop_assist_label != null:
		return
	
	wallhop_assist_label = Label.new()
	wallhop_assist_label.text = "⏱ WALL RIDE"
	wallhop_assist_label.add_theme_font_size_override("font_size", 18)
	wallhop_assist_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 0.95))
	wallhop_assist_label.anchor_left = 0.5
	wallhop_assist_label.anchor_top = 0.0
	wallhop_assist_label.offset_left = -100.0
	wallhop_assist_label.offset_top = 40.0
	wallhop_assist_label.custom_minimum_size = Vector2(200, 30)
	wallhop_assist_label.visible = false
	add_child(wallhop_assist_label)


func _refresh_hp_ui(hp: float, max_hp: float) -> void:
	if _hp_bar_fill == null:
		return

	var ratio := clampf(hp / max_hp, 0.0, 1.0)

	if ratio < _hp_target_ratio:
		_hp_trail_hold_t = HP_TRAIL_HOLD_TIME   # took damage — trail holds, then catches down
	elif ratio > _hp_trail_ratio:
		_hp_trail_ratio = ratio                 # healed past the trail — snap it up immediately
	_hp_target_ratio = ratio

	_hp_bar_fill.size.x = ratio * _hp_inner_width

	# Colour shifts green → yellow → red as HP drops
	var fill_color: Color
	if ratio > 0.5:
		fill_color = HP_COLOR_FULL.lerp(HP_COLOR_MID, (1.0 - ratio) * 2.0)
	else:
		fill_color = HP_COLOR_MID.lerp(HP_COLOR_LOW, (0.5 - ratio) * 2.0)
	if _hp_bar_fill_style: _hp_bar_fill_style.bg_color = fill_color

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

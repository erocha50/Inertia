extends CanvasLayer

@onready var heat_bar_bg: ColorRect      = $HeatBarBG
@onready var heat_bar: ColorRect         = $HeatBar
@onready var heat_label: Label           = $HeatLabel
@onready var tier_label: Label           = $TierLabel
@onready var health_bar                  = $HealthBar
@onready var food_slots: HBoxContainer   = $FoodSlots

const HEAT_BAR_MAX_WIDTH := 300.0

# ── Cooldown state ────────────────────────────────────────────────────────────
var _dash_cooldown     : float = 0.0
var _dash_max_cooldown : float = 5.0

var _roll_cooldown     : float = 0.0
var _roll_max_cooldown : float = 3.0

var _player: Node = null

# ── Circle layout ─────────────────────────────────────────────────────────────
const CIRCLE_RADIUS  := 30.0
const ARC_WIDTH      := 8.0    # thickness of the worm
const ARC_SEGMENTS   := 128    # smoothness
const CIRCLE_SPACING := 16.0   # horizontal gap between circles
const MARGIN         := 20.0   # distance from screen edges (bottom-left)

# Worm head cap size (round cap drawn as a circle at the leading tip)
const CAP_RADIUS     := 4.0

# Colours
const COLOR_BG_DISC    := Color(0.05, 0.05, 0.08, 0.92)
const COLOR_TRACK      := Color(0.18, 0.18, 0.22, 0.85)
const COLOR_TRACK_EDGE := Color(1.0,  1.0,  1.0,  0.06)
const COLOR_TEXT       := Color(1.0,  1.0,  1.0,  0.92)
const COLOR_LABEL      := Color(1.0,  1.0,  1.0,  0.50)

# Worm colours per ability
const COLOR_DASH_WORM  := Color(0.95, 0.28, 0.10)   # orange-red
const COLOR_ROLL_WORM  := Color(0.10, 0.82, 0.52)   # teal-green

# Inner class — a full-rect Control child used purely for _draw()
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


# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	HeatManager.heat_changed.connect(_on_heat_changed)
	_refresh_heat_ui(HeatManager.heat_value, HeatManager.get_tier())
	heat_label.visible = true

	# Wait one frame so the viewport size is finalised
	await get_tree().process_frame
	_recompute_positions()

	# Recompute if the window is resized
	get_tree().root.size_changed.connect(_recompute_positions)

	# Attach drawing node
	_draw_node     = _CooldownDrawer.new()
	_draw_node.hud = self
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

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


func _recompute_positions() -> void:
	var vp     := get_tree().root.size
	var slot   := (CIRCLE_RADIUS + ARC_WIDTH) * 2.0
	# Bottom-left: first circle leftmost, second to its right
	var base_y := vp.y - MARGIN - slot * 0.5 - 14.0  # 14px extra for label below
	var base_x := MARGIN + slot * 0.5
	_dash_centre = Vector2(base_x, base_y)
	_roll_centre = Vector2(base_x + slot + CIRCLE_SPACING, base_y)
	if _draw_node:
		_draw_node.queue_redraw()


func _physics_process(delta: float) -> void:
	var dirty := false
	if _dash_cooldown > 0.0:
		_dash_cooldown = max(0.0, _dash_cooldown - delta)
		dirty = true
	if _roll_cooldown > 0.0:
		_roll_cooldown = max(0.0, _roll_cooldown - delta)
		dirty = true
	if dirty and _draw_node:
		_draw_node.queue_redraw()


# ── Drawing ───────────────────────────────────────────────────────────────────
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

	# ── 1. Background disc ────────────────────────────────────────────────────
	canvas.draw_circle(centre, r + aw + 1.0, Color(0.0, 0.0, 0.0, 0.4))
	canvas.draw_circle(centre, r, COLOR_BG_DISC)

	# ── 2. Track ring (the groove the worm sits in) ───────────────────────────
	_draw_arc(canvas, centre, ring_r, 0.0, TAU, COLOR_TRACK_EDGE, aw + 2.0)
	_draw_arc(canvas, centre, ring_r, 0.0, TAU, COLOR_TRACK,      aw)

	# ── 3. Worm arc ───────────────────────────────────────────────────────────
	if fill_ratio > 0.005:
		var sweep := TAU * fill_ratio

		# Worm body — solid arc from top, sweeping clockwise
		_draw_arc(canvas, centre, ring_r,
				  -PI * 0.5, -PI * 0.5 + sweep,
				  worm_color, aw)

		# Tail cap (round end at the start/top of the arc)
		var tail_angle := -PI * 0.5
		var tail_pos   := centre + Vector2(cos(tail_angle), sin(tail_angle)) * ring_r
		canvas.draw_circle(tail_pos, CAP_RADIUS, worm_color)

		# Head cap (round end at the leading tip — slightly brighter)
		var head_angle := -PI * 0.5 + sweep
		var head_pos   := centre + Vector2(cos(head_angle), sin(head_angle)) * ring_r
		var head_color := worm_color.lightened(0.35)
		canvas.draw_circle(head_pos, CAP_RADIUS, head_color)

		# Tiny specular glint on the head
		canvas.draw_circle(head_pos, CAP_RADIUS * 0.45, Color(1.0, 1.0, 1.0, 0.55))

	# ── 4. Centre text ────────────────────────────────────────────────────────
	var display : String
	if remaining > 0.05:
		display = "%.1f" % remaining
	elif fill_ratio >= 1.0:
		display = "RDY"
	else:
		display = ""

	if display != "":
		var fsz      := 13
		var tw       := font.get_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz)
		var txt_pos  := centre + Vector2(-tw.x * 0.5, tw.y * 0.33)
		canvas.draw_string(font, txt_pos, display,
						   HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, COLOR_TEXT)

	# ── 5. Label below circle ─────────────────────────────────────────────────
	var lsz     := 11
	var lw      := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, lsz).x
	var lbl_pos := Vector2(centre.x - lw * 0.5, centre.y + r + aw + 10.0)
	canvas.draw_string(font, lbl_pos, label,
					   HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, COLOR_LABEL)


## Polyline arc from from_a → to_a (radians). Positive sweep = clockwise.
func _draw_arc(canvas: Control, centre: Vector2, radius: float,
			   from_a: float, to_a: float, color: Color, width: float) -> void:
	var pts  := PackedVector2Array()
	var span := to_a - from_a
	var segs: int = max(int(abs(span) / TAU * float(ARC_SEGMENTS)), 2)
	for i in range(segs + 1):
		var a := from_a + span * (float(i) / float(segs))
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	canvas.draw_polyline(pts, color, width, true)


# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_dash_performed() -> void:
	_dash_cooldown = _dash_max_cooldown
	if _draw_node: _draw_node.queue_redraw()

func _on_roll_performed() -> void:
	_roll_cooldown = _roll_max_cooldown
	if _draw_node: _draw_node.queue_redraw()

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

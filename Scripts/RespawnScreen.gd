extends CanvasLayer

# ── RespawnScreen.gd ──────────────────────────────────────────────────────────
# Attach to a plain CanvasLayer node — builds all UI in code.
# ─────────────────────────────────────────────────────────────────────────────

const FONT_PATH    := "res://Assets/Fonts/BebasNeue-Regular.ttf"
const COLOR_BG     := Color(0.078, 0.047, 0.031, 0.97)
const COLOR_ORANGE := Color(1.0,   0.314, 0.0,   1.0)
const COLOR_RED    := Color(0.9,   0.1,   0.1,   1.0)
const COLOR_WHITE  := Color(1.0,   1.0,   1.0,   1.0)
const COLOR_MUTED  := Color(1.0,   1.0,   1.0,   0.35)

var death_messages: Array[String] = [
	"COLD", "HEAT LOST", "MOMENTUM ZERO", "BURNED OUT",
]

var _danger_overlay: ColorRect
var _root_control:   Control
var _death_label:    Label
var _heat_val:       Label
var _respawn_btn:    Button
var _menu_btn:       Button
var _pulse_t:        float = 0.0


func _ready() -> void:
	_danger_overlay = ColorRect.new()
	_danger_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger_overlay.color        = Color(0, 0, 0, 0)
	_danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_overlay)

	_root_control = Control.new()
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.visible      = false
	add_child(_root_control)

	_build_ui()
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	DeathRespawnManager.death_timer_changed.connect(_on_death_timer_changed)


func _process(delta: float) -> void:
	if _root_control.visible:
		_pulse_t += delta * 1.8
		_heat_val.modulate.a = lerpf(0.5, 1.0, sin(_pulse_t) * 0.5 + 0.5)


# ── Public API ────────────────────────────────────────────────────────────────

func show_screen() -> void:
	_death_label.text     = death_messages[randi() % death_messages.size()]
	var heat_pct: float   = (DeathRespawnManager._heat_at_death / HeatManager.max_heat) * 100.0
	_heat_val.text        = "%.0f%%" % heat_pct
	# Tint orange if died with decent heat, red if died cold
	_heat_val.add_theme_color_override("font_color",
		COLOR_RED if heat_pct < 25.0 else COLOR_ORANGE)
	_respawn_btn.disabled = false
	_root_control.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func hide_screen() -> void:
	_root_control.visible = false
	var tw := create_tween()
	tw.tween_property(_danger_overlay, "color", Color(0, 0, 0, 0), 0.5)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_death_timer_changed(seconds_remaining: float) -> void:
	var delay   := DeathRespawnManager.heat_zero_death_delay
	var elapsed := delay - seconds_remaining
	var t       := clampf(elapsed / delay, 0.0, 1.0)
	_danger_overlay.color = Color(0, 0, 0, t * t * 0.88)


func _on_respawn_pressed() -> void:
	_respawn_btn.disabled = true
	DeathRespawnManager.do_respawn()


func _on_menu_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


# ── UI Builder ────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color        = Color(0, 0, 0, 0.65)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color         = COLOR_BG
	ps.border_color     = COLOR_ORANGE
	ps.set_border_width_all(0)
	ps.border_width_top = 3
	ps.set_content_margin_all(48)
	ps.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", ps)
	centre.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	var tag := Label.new()
	tag.text                 = "— HEAT EXPIRED —"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", COLOR_ORANGE)
	tag.add_theme_font_size_override("font_size", 11)
	vbox.add_child(tag)

	_add_spacer(vbox, 20)

	_death_label = Label.new()
	_death_label.text                 = "COLD"
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override("font_size", 72)
	_death_label.add_theme_color_override("font_color", COLOR_WHITE)
	if ResourceLoader.exists(FONT_PATH):
		_death_label.add_theme_font_override("font", load(FONT_PATH) as FontFile)
	vbox.add_child(_death_label)

	_add_spacer(vbox, 32)
	_add_divider(vbox)
	_add_spacer(vbox, 24)

	var heat_lbl := Label.new()
	heat_lbl.text                 = "HEAT AT DEATH"
	heat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heat_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	heat_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(heat_lbl)

	_add_spacer(vbox, 6)

	_heat_val = Label.new()
	_heat_val.text                 = "0%"
	_heat_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heat_val.add_theme_font_size_override("font_size", 48)
	_heat_val.add_theme_color_override("font_color", COLOR_ORANGE)
	if ResourceLoader.exists(FONT_PATH):
		_heat_val.add_theme_font_override("font", load(FONT_PATH) as FontFile)
	vbox.add_child(_heat_val)

	_add_spacer(vbox, 32)
	_add_divider(vbox)
	_add_spacer(vbox, 24)

	_respawn_btn = Button.new()
	_respawn_btn.text                = "RUN AGAIN"
	_respawn_btn.custom_minimum_size = Vector2(0, 52)
	_respawn_btn.add_theme_font_size_override("font_size", 24)
	_respawn_btn.add_theme_color_override("font_color",         COLOR_WHITE)
	_respawn_btn.add_theme_color_override("font_hover_color",   COLOR_WHITE)
	_respawn_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	if ResourceLoader.exists(FONT_PATH):
		_respawn_btn.add_theme_font_override("font", load(FONT_PATH) as FontFile)
	var bn := StyleBoxFlat.new()
	bn.bg_color = COLOR_ORANGE
	bn.set_corner_radius_all(0)
	_respawn_btn.add_theme_stylebox_override("normal",  bn)
	_respawn_btn.add_theme_stylebox_override("focus",   bn)
	var bh := StyleBoxFlat.new()
	bh.bg_color = Color(1.0, 0.4, 0.08, 1.0)
	bh.set_corner_radius_all(0)
	_respawn_btn.add_theme_stylebox_override("hover",   bh)
	var bp := StyleBoxFlat.new()
	bp.bg_color = Color(0.8, 0.25, 0.0, 1.0)
	bp.set_corner_radius_all(0)
	_respawn_btn.add_theme_stylebox_override("pressed", bp)
	_respawn_btn.pressed.connect(_on_respawn_pressed)
	vbox.add_child(_respawn_btn)

	_add_spacer(vbox, 10)

	_menu_btn = Button.new()
	_menu_btn.text                = "MAIN MENU"
	_menu_btn.custom_minimum_size = Vector2(0, 36)
	_menu_btn.add_theme_font_size_override("font_size", 12)
	_menu_btn.add_theme_color_override("font_color",         COLOR_MUTED)
	_menu_btn.add_theme_color_override("font_hover_color",   COLOR_WHITE)
	_menu_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	var mn := StyleBoxFlat.new()
	mn.bg_color     = Color(0, 0, 0, 0)
	mn.border_color = Color(1, 1, 1, 0.08)
	mn.set_border_width_all(1)
	mn.set_corner_radius_all(0)
	_menu_btn.add_theme_stylebox_override("normal",  mn)
	_menu_btn.add_theme_stylebox_override("focus",   mn)
	var mh := mn.duplicate() as StyleBoxFlat
	mh.border_color = Color(1, 1, 1, 0.2)
	_menu_btn.add_theme_stylebox_override("hover",   mh)
	_menu_btn.add_theme_stylebox_override("pressed", mh)
	_menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(_menu_btn)


func _add_spacer(parent: Control, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)


func _add_divider(parent: Control) -> void:
	var sep := HSeparator.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color              = Color(1, 1, 1, 0.07)
	sty.content_margin_top    = 0
	sty.content_margin_bottom = 0
	sep.add_theme_stylebox_override("separator", sty)
	parent.add_child(sep)

extends CanvasLayer

# ── RespawnScreen.gd ──────────────────────────────────────────────────────────
# Attach to a plain CanvasLayer node — this script builds ALL UI in code.
# No child nodes needed in the editor.
#
# Optional: drop a .ttf font file into res://Assets/Fonts/BebasNeue-Regular.ttf
# (free from fonts.google.com) for the big death title. Falls back to default.
# ─────────────────────────────────────────────────────────────────────────────

const FONT_PATH    := "res://Assets/Fonts/BebasNeue-Regular.ttf"
const COLOR_BG     := Color(0.078, 0.047, 0.031, 0.97)
const COLOR_ORANGE := Color(1.0,   0.314, 0.0,   1.0)
const COLOR_WHITE  := Color(1.0,   1.0,   1.0,   1.0)
const COLOR_MUTED  := Color(1.0,   1.0,   1.0,   0.35)
const COLOR_SUBTLE := Color(1.0,   1.0,   1.0,   0.07)

var death_messages: Array[String] = [
	"COLD",
	"HEAT LOST",
	"MOMENTUM ZERO",
	"TRAIL LEFT BEHIND",
]

# ── UI nodes ──────────────────────────────────────────────────────────────────
var _root_control:    Control
var _danger_overlay:  ColorRect      # darkens screen as heat drains
var _panel:           PanelContainer
var _death_label:     Label
var _subtitle_label:  Label
var _heat_val:        Label
var _checkpoint_val:  Label
var _recover_val:     Label
var _heat_bar:        ProgressBar
var _bar_note:        Label
var _respawn_btn:     Button
var _menu_btn:        Button
var _trail_label:     Label

var _heat_at_death: float = 0.0
var _pulse_t:       float = 0.0


func _ready() -> void:
	_build_danger_overlay()
	_build_ui()
	hide()
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	DeathRespawnManager.death_timer_changed.connect(_on_death_timer_changed)
	DeathRespawnManager.player_died.connect(_on_player_died)


# ── Public API ────────────────────────────────────────────────────────────────

func show_screen() -> void:
	_heat_at_death = HeatManager.heat_value

	_death_label.text = death_messages[randi() % death_messages.size()]
	_heat_val.text    = "%d" % int(_heat_at_death)
	_recover_val.text = "85%"

	var cp := "LAST SAVE" if DeathRespawnManager._has_checkpoint else "NONE"
	_checkpoint_val.text = cp

	_heat_bar.max_value       = DeathRespawnManager.heat_zero_death_delay
	_heat_bar.value           = 0.0
	_respawn_btn.disabled     = false

	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func hide_screen() -> void:
	hide()
	# Clear the danger overlay on respawn
	if _danger_overlay:
		var tw := create_tween()
		tw.tween_property(_danger_overlay, "color", Color(0, 0, 0, 0), 0.4)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── Process — pulse + danger overlay (runs even before death screen shows) ────

func _process(delta: float) -> void:
	# Pulse the trail label when the death panel is visible
	if visible:
		_pulse_t += delta * 2.2
		if _trail_label:
			_trail_label.modulate.a = lerpf(0.3, 1.0, sin(_pulse_t) * 0.5 + 0.5)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_player_died(_pos: Vector3) -> void:
	pass   # DeathRespawnManager calls show_screen() directly


func _on_death_timer_changed(seconds_remaining: float) -> void:
	var delay    := DeathRespawnManager.heat_zero_death_delay
	var elapsed  := delay - seconds_remaining
	var t        := clampf(elapsed / delay, 0.0, 1.0)

	# ── Danger vignette — visible the whole time heat is at zero ──────────────
	if _danger_overlay:
		# Ramps from invisible → 0.78 black as the timer fills
		_danger_overlay.color = Color(0.0, 0.0, 0.0, t * 0.78)

	# ── Progress bar inside the death panel ───────────────────────────────────
	if _heat_bar and visible:
		_heat_bar.value = elapsed


func _on_respawn_pressed() -> void:
	_respawn_btn.disabled = true
	DeathRespawnManager.do_respawn()


func _on_menu_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


# ── Danger overlay (built separately so it sits behind everything) ────────────

func _build_danger_overlay() -> void:
	_danger_overlay = ColorRect.new()
	_danger_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger_overlay.color        = Color(0, 0, 0, 0)
	_danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_overlay)


# ── UI Builder ────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_control)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(overlay)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color         = COLOR_BG
	panel_style.border_color     = COLOR_ORANGE
	panel_style.set_border_width_all(0)
	panel_style.border_width_top = 3
	panel_style.set_content_margin_all(40)
	panel_style.set_corner_radius_all(0)
	_panel.add_theme_stylebox_override("panel", panel_style)
	centre.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text                 = "— HEAT EXPIRED —"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_color_override("font_color", COLOR_ORANGE)
	icon_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(icon_lbl)

	_add_spacer(vbox, 16)

	_death_label = Label.new()
	_death_label.text                 = "COLD"
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override("font_size", 64)
	_death_label.add_theme_color_override("font_color", COLOR_WHITE)
	if ResourceLoader.exists(FONT_PATH):
		_death_label.add_theme_font_override("font", load(FONT_PATH) as FontFile)
	vbox.add_child(_death_label)

	_subtitle_label = Label.new()
	_subtitle_label.text                 = "MOMENTUM LOST"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_subtitle_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_subtitle_label)

	_add_spacer(vbox, 28)
	_add_divider(vbox)
	_add_spacer(vbox, 20)

	_heat_val       = _add_stat_row(vbox, "HEAT TRAIL VALUE",  "0")
	_checkpoint_val = _add_stat_row(vbox, "LAST CHECKPOINT",   "NONE")
	_recover_val    = _add_stat_row(vbox, "TRAIL RECOVERABLE", "85%")

	_add_spacer(vbox, 16)

	_heat_bar = ProgressBar.new()
	_heat_bar.custom_minimum_size = Vector2(0, 3)
	_heat_bar.show_percentage     = false
	_heat_bar.value               = 0.0
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = COLOR_SUBTLE
	_heat_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_ORANGE
	_heat_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_heat_bar)

	_bar_note = Label.new()
	_bar_note.text = "HEAT RETAINED ON RESPAWN"
	_bar_note.add_theme_color_override("font_color", Color(1.0, 0.314, 0.0, 0.5))
	_bar_note.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_bar_note)

	_add_spacer(vbox, 24)

	_respawn_btn = Button.new()
	_respawn_btn.text                = "RUN AGAIN"
	_respawn_btn.custom_minimum_size = Vector2(0, 48)
	_respawn_btn.add_theme_font_size_override("font_size", 22)
	_respawn_btn.add_theme_color_override("font_color",         COLOR_WHITE)
	_respawn_btn.add_theme_color_override("font_hover_color",   COLOR_WHITE)
	_respawn_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	if ResourceLoader.exists(FONT_PATH):
		_respawn_btn.add_theme_font_override("font", load(FONT_PATH) as FontFile)
	var btn_n := StyleBoxFlat.new()
	btn_n.bg_color = COLOR_ORANGE
	btn_n.set_corner_radius_all(0)
	_respawn_btn.add_theme_stylebox_override("normal", btn_n)
	_respawn_btn.add_theme_stylebox_override("focus",  btn_n)
	var btn_h := StyleBoxFlat.new()
	btn_h.bg_color = Color(1.0, 0.4, 0.08, 1.0)
	btn_h.set_corner_radius_all(0)
	_respawn_btn.add_theme_stylebox_override("hover", btn_h)
	var btn_p := StyleBoxFlat.new()
	btn_p.bg_color = Color(0.8, 0.25, 0.0, 1.0)
	btn_p.set_corner_radius_all(0)
	_respawn_btn.add_theme_stylebox_override("pressed", btn_p)
	_respawn_btn.pressed.connect(_on_respawn_pressed)
	vbox.add_child(_respawn_btn)

	_add_spacer(vbox, 8)

	_menu_btn = Button.new()
	_menu_btn.text                = "MAIN MENU"
	_menu_btn.custom_minimum_size = Vector2(0, 36)
	_menu_btn.add_theme_font_size_override("font_size", 12)
	_menu_btn.add_theme_color_override("font_color",         COLOR_MUTED)
	_menu_btn.add_theme_color_override("font_hover_color",   COLOR_WHITE)
	_menu_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	var menu_n := StyleBoxFlat.new()
	menu_n.bg_color     = Color(0, 0, 0, 0)
	menu_n.border_color = Color(1, 1, 1, 0.08)
	menu_n.set_border_width_all(1)
	menu_n.set_corner_radius_all(0)
	_menu_btn.add_theme_stylebox_override("normal", menu_n)
	_menu_btn.add_theme_stylebox_override("focus",  menu_n)
	var menu_h := menu_n.duplicate() as StyleBoxFlat
	menu_h.border_color = Color(1, 1, 1, 0.2)
	_menu_btn.add_theme_stylebox_override("hover",   menu_h)
	_menu_btn.add_theme_stylebox_override("pressed", menu_h)
	_menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(_menu_btn)

	_add_spacer(vbox, 20)
	_add_divider(vbox)
	_add_spacer(vbox, 12)

	_trail_label = Label.new()
	_trail_label.text                 = "• HEAT TRAIL WAITING AT DEATH POINT"
	_trail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trail_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_trail_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_trail_label)


# ── Helpers ───────────────────────────────────────────────────────────────────

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


func _add_stat_row(parent: Control, label_text: String, value_text: String) -> Label:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)
	_add_spacer(parent, 10)

	var lbl := Label.new()
	lbl.text                  = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", COLOR_MUTED)
	lbl.add_theme_font_size_override("font_size", 11)
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", COLOR_ORANGE)
	val.add_theme_font_size_override("font_size", 13)
	hbox.add_child(val)

	return val

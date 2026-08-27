extends Area3D

# Attach this to an Area3D node with a CollisionShape3D child sized to your
# finish-line trigger volume. No other child nodes needed — everything below
# is built in code, same idea as NarratorScreen.gd.

@export_group("Win Screen")
@export var title_text: String = "YOU MADE IT"
@export var subtitle_text: String = "LEVEL COMPLETE"
@export_multiline var message_text: String = "You survived the descent."

@export_group("Transition")
@export_file("*.tscn") var main_menu_scene_path: String = "res://Scenes/main_menu.tscn"

var canvas: CanvasLayer
var background: ColorRect
var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var message_label: Label
var menu_button: Button

var has_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if has_triggered:
		return
	if not body.is_in_group("player"):
		return
	has_triggered = true
	_show_win_screen()


func _show_win_screen() -> void:
	# Must be set BEFORE pausing, or the fade-in tween below freezes at alpha 0
	process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	canvas = CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	# --- Background ---
	background = ColorRect.new()
	background.color = Color(0.05, 0.045, 0.04, 0.92)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Centered panel ---
	var center := CenterContainer.new()
	canvas.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.7, 0.5, 0.4)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 32.0
	style.content_margin_top = 28.0
	style.content_margin_right = 32.0
	style.content_margin_bottom = 28.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)

	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# --- Title / subtitle / message ---
	title_label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = subtitle_text
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5, 0.9))
	subtitle_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(subtitle_label)

	message_label = Label.new()
	message_label.text = message_text
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	message_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(message_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# --- Main Menu button ---
	menu_button = Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.custom_minimum_size = Vector2(180, 48)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(_on_menu_button_pressed)
	vbox.add_child(menu_button)

	# --- Fade in ---
	background.modulate.a = 0.0
	panel.modulate.a = 0.0

	var fade_in := create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.set_parallel(true)
	fade_in.tween_property(background, "modulate:a", 1.0, 0.5)
	fade_in.chain().tween_property(panel, "modulate:a", 1.0, 0.4)

	menu_button.grab_focus()


func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(main_menu_scene_path)

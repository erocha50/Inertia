extends Node

# Attach this to a single, empty Node and save it as its own scene
# (e.g. NarratorIntro.tscn). No child nodes needed — everything below
# is built in code, same idea as ObjectiveMessage.gd.

@export_group("Narrator")
@export var narrator_portrait: Texture2D
@export var kicker_text: String = "THE GUIDE"
@export_multiline var message_text: String = "Welcome, wanderer.\n\nYour goal is to survive the descent — keep your heat burning, or the cold will claim you."

@export_group("Timing")
@export var display_duration: float = 60.0
@export var allow_skip: bool = true

@export_group("Transition")
@export_file("*.tscn") var next_scene_path: String

var canvas: CanvasLayer
var background: ColorRect
var panel: PanelContainer
var portrait_rect: TextureRect
var kicker_label: Label
var message_label: Label
var skip_label: Label

var timer: Timer
var has_transitioned: bool = false
var _skip_key_was_down: bool = false


func _ready() -> void:
	print("[NarratorScreen] ready. allow_skip=", allow_skip, " next_scene_path='", next_scene_path, "' display_duration=", display_duration)
	canvas = CanvasLayer.new()
	add_child(canvas)

	# --- Background ---
	background = ColorRect.new()
	background.color = Color(0.05, 0.045, 0.04, 0.92)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Centered panel ---
	var center := CenterContainer.new()
	canvas.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)

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
	style.content_margin_left = 28.0
	style.content_margin_top = 24.0
	style.content_margin_right = 32.0
	style.content_margin_bottom = 28.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)

	center.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	panel.add_child(hbox)

	# --- Portrait ---
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(160, 160)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_rect.clip_contents = true
	if narrator_portrait:
		portrait_rect.texture = narrator_portrait
	else:
		portrait_rect.visible = false
	hbox.add_child(portrait_rect)

	# --- Text side ---
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	kicker_label = Label.new()
	kicker_label.text = kicker_text
	kicker_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5, 0.9))
	kicker_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(kicker_label)

	message_label = Label.new()
	message_label.text = message_text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(message_label)

	# --- Skip hint, bottom of screen ---
	skip_label = Label.new()
	skip_label.text = "Press Space to continue"
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	skip_label.add_theme_font_size_override("font_size", 14)
	skip_label.visible = allow_skip
	canvas.add_child(skip_label)
	skip_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	skip_label.offset_top = -48.0
	skip_label.offset_bottom = -16.0

	# --- Fade in ---
	background.modulate.a = 0.0
	panel.modulate.a = 0.0
	skip_label.modulate.a = 0.0

	var fade_in := create_tween()
	fade_in.set_parallel(true)
	fade_in.tween_property(background, "modulate:a", 1.0, 0.5)
	fade_in.chain().tween_property(panel, "modulate:a", 1.0, 0.4)
	fade_in.parallel().tween_property(skip_label, "modulate:a", 0.6, 0.4)

	# --- Auto-advance timer ---
	timer = Timer.new()
	timer.wait_time = display_duration
	timer.one_shot = true
	timer.timeout.connect(_go_to_next_scene)
	add_child(timer)
	timer.start()


func _process(_delta: float) -> void:
	if not allow_skip or has_transitioned:
		return

	var key_down := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ENTER)
	if key_down and not _skip_key_was_down:
		print("[NarratorScreen] skip key detected")
		_go_to_next_scene()
	_skip_key_was_down = key_down

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		print("[NarratorScreen] skip click detected")
		_go_to_next_scene()


func _go_to_next_scene() -> void:
	print("[NarratorScreen] _go_to_next_scene called. has_transitioned=", has_transitioned, " next_scene_path='", next_scene_path, "'")
	if has_transitioned:
		return
	has_transitioned = true

	if next_scene_path == "":
		push_warning("NarratorScreen: next_scene_path is not set in the Inspector.")
		return

	if has_node("/root/SceneTransition"):
		print("[NarratorScreen] transitioning via SceneTransition")
		SceneTransition.transition_to_scene(next_scene_path)
	else:
		print("[NarratorScreen] SceneTransition autoload not found, using change_scene_to_file")
		get_tree().change_scene_to_file(next_scene_path)

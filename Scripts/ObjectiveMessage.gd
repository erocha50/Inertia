extends CanvasLayer

# Assign a portrait image in the Inspector once this script is
# attached — a square-ish image works best (e.g. 128x128 or
# 256x256). If left empty, the portrait slot is hidden and the
# message box behaves exactly as before.
@export var guide_portrait: Texture2D

var panel: PanelContainer
var hbox: HBoxContainer
var portrait_rect: TextureRect
var vbox: VBoxContainer
var kicker_label: Label
var message_label: Label
var fade_tween: Tween
var idle_tween: Tween

func _ready() -> void:
	panel = PanelContainer.new()
	panel.name = "MessagePanel"

	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(440, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.7, 0.5, 0.35)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)

	panel.add_theme_stylebox_override("panel", style)

	hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# --- Portrait, left side ---
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(64, 64)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_rect.clip_contents = true
	if guide_portrait:
		portrait_rect.texture = guide_portrait
	else:
		portrait_rect.visible = false
	hbox.add_child(portrait_rect)

	# --- Text side ---
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	kicker_label = Label.new()
	kicker_label.text = "OBJECTIVE"
	kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kicker_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5, 0.9))
	kicker_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(kicker_label)

	message_label = Label.new()
	message_label.text = "Tutorial Message"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(message_label)

	add_child(panel)

	panel.modulate.a = 0.0
	visible = false
	add_to_group("message_ui")


func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text = text
	panel.modulate.a = 0.0
	panel.offset_top = 12.0
	panel.offset_bottom = 12.0
	visible = true

	if fade_tween:
		fade_tween.kill()
	if idle_tween:
		idle_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_QUAD)

	fade_tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	fade_tween.tween_property(panel, "offset_top", 0.0, 0.35)
	fade_tween.tween_property(panel, "offset_bottom", 0.0, 0.35)

	if portrait_rect.visible:
		# Portrait pops in with a little overshoot bounce
		portrait_rect.pivot_offset = portrait_rect.size / 2.0
		portrait_rect.scale = Vector2(0.4, 0.4)
		fade_tween.tween_property(portrait_rect, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	fade_tween.chain().tween_callback(_start_idle_bob)
	fade_tween.chain().tween_interval(duration)

	fade_tween.chain().tween_property(panel, "modulate:a", 0.0, 0.4)

	fade_tween.chain().tween_callback(func():
		visible = false
		if idle_tween:
			idle_tween.kill()
	)


func _start_idle_bob() -> void:
	if not portrait_rect.visible:
		return
	idle_tween = create_tween()
	idle_tween.set_loops()
	idle_tween.set_trans(Tween.TRANS_SINE)
	idle_tween.set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(portrait_rect, "position:y", -4.0, 0.8)
	idle_tween.tween_property(portrait_rect, "position:y", 0.0, 0.8)

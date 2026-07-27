extends CanvasLayer

var panel: PanelContainer
var vbox: VBoxContainer
var kicker_label: Label
var message_label: Label
var fade_tween: Tween

func _ready() -> void:
	panel = PanelContainer.new()
	panel.name = "MessagePanel"

	# True center, auto-sized to content: anchor the CENTER POINT
	# only (all anchors = 0.5, all offsets = 0), then let the
	# panel's own minimum size (driven by its children) determine
	# how big it actually is. No manual pixel math to get wrong.
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
	panel.custom_minimum_size = Vector2(560, 0)  # fixed width, auto height

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
	style.content_margin_left = 26.0
	style.content_margin_top = 16.0
	style.content_margin_right = 26.0
	style.content_margin_bottom = 18.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)

	panel.add_theme_stylebox_override("panel", style)

	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	kicker_label = Label.new()
	kicker_label.text = "OBJECTIVE"
	kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5, 0.9))
	kicker_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(kicker_label)

	message_label = Label.new()
	message_label.text = "Tutorial Message"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	message_label.add_theme_constant_override("outline_size", 3)
	message_label.add_theme_font_size_override("font_size", 24)
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

	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_QUAD)

	fade_tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	fade_tween.tween_property(panel, "offset_top", 0.0, 0.35)
	fade_tween.tween_property(panel, "offset_bottom", 0.0, 0.35)

	fade_tween.chain().tween_interval(duration)

	fade_tween.chain().tween_property(panel, "modulate:a", 0.0, 0.4)

	fade_tween.chain().tween_callback(func(): visible = false)

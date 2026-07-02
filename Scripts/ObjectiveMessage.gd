extends CanvasLayer

var label: Label
var fade_tween: Tween

func _ready() -> void:
	# Create the label programmatically
	label = Label.new()
	label.name = "MessageLabel"
	label.text = "Tutorial Message"
	
	# Anchor it to screen center
	label.anchors_preset = Control.PRESET_CENTER
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -300.0
	label.offset_top = -60.0
	label.offset_right = 300.0
	label.offset_bottom = 60.0
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Text settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Styling - background box with border
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.6, 1.0, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 20.0
	style.content_margin_top = 15.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 15.0
	
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 28)
	
	add_child(label)
	
	# Start hidden
	label.modulate.a = 0.0
	visible = false
	add_to_group("message_ui")


func show_message(text: String, duration: float = 3.0) -> void:
	label.text = text
	label.modulate.a = 0.0
	visible = true

	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_QUAD)
	
	# Fade in (smooth)
	fade_tween.tween_property(label, "modulate:a", 1.0, 0.4)
	
	# Hold for duration
	fade_tween.tween_interval(duration)
	
	# Fade out (smooth)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	
	# Hide when done
	fade_tween.tween_callback(func(): visible = false)

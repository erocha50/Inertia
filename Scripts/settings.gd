extends Control

@export var font_config: FontConfig

# Scroll speed in UV units per second (tweak to taste)
@export var scroll_speed: float = 0.015

# Path to your starfield texture, used only if no Background node exists yet
@export var background_texture_path: String = "res://Assets/starfield.png"

var _bg: TextureRect
var _scroll_shader: ShaderMaterial

const SCROLL_SHADER_CODE = """
shader_type canvas_item;

uniform float offset_x : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + offset_x);
	COLOR = texture(TEXTURE, uv);
}
"""

func _ready() -> void:
	# Make sure the root itself fills the screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_setup_background()

	if font_config == null:
		font_config = load("res://Resources/font_config.tres") as FontConfig
	if font_config == null:
		font_config = FontConfig.new()
		print("⚠ FontConfig resource not found, created new instance")

	_build_ui()

func _setup_background() -> void:
	_bg = get_node_or_null("Background")
	if _bg == null:
		_bg = TextureRect.new()
		_bg.name = "Background"
		add_child(_bg)
		move_child(_bg, 0)
		var tex = load(background_texture_path)
		if tex:
			_bg.texture = tex
		else:
			push_warning("settings: Could not load background texture at '%s'." % background_texture_path)

	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var shader = Shader.new()
	shader.code = SCROLL_SHADER_CODE
	_scroll_shader = ShaderMaterial.new()
	_scroll_shader.shader = shader
	_scroll_shader.set_shader_parameter("offset_x", 0.0)
	_bg.material = _scroll_shader

func _process(delta: float) -> void:
	if _scroll_shader == null:
		return
	var current: float = _scroll_shader.get_shader_parameter("offset_x")
	_scroll_shader.set_shader_parameter("offset_x", fmod(current + scroll_speed * delta, 1.0))

func _build_ui() -> void:
	# CenterContainer handles all the centering math for us — fills the screen,
	# and centers whatever single child we put inside it.
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Everything lives in one vertical stack inside the CenterContainer
	var main_box := VBoxContainer.new()
	main_box.name = "MainBox"
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_theme_constant_override("separation", 12)
	center.add_child(main_box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_config.get_title_font():
		title.add_theme_font_override("font", font_config.get_title_font())
		title.add_theme_font_size_override("font_size", font_config.title_font_size)
	else:
		title.add_theme_font_size_override("font_size", 64)
	main_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "AUDIO & GAMEPLAY"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	if font_config.get_subtitle_font():
		subtitle.add_theme_font_override("font", font_config.get_subtitle_font())
		subtitle.add_theme_font_size_override("font_size", font_config.subtitle_font_size)
	else:
		subtitle.add_theme_font_size_override("font_size", 18)
	main_box.add_child(subtitle)

	# Spacer between title block and settings block
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 40)
	main_box.add_child(spacer_top)

	var volume_label := Label.new()
	volume_label.text = "VOLUME"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_config.get_status_font():
		volume_label.add_theme_font_override("font", font_config.get_status_font())
		volume_label.add_theme_font_size_override("font_size", font_config.status_font_size)
	else:
		volume_label.add_theme_font_size_override("font_size", 16)
	main_box.add_child(volume_label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(280, 0)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = AudioManager.get_volume("Master")
	slider.value_changed.connect(_on_volume_slider_changed)
	main_box.add_child(slider)

	# Spacer between slider and back button
	var spacer_bottom := Control.new()
	spacer_bottom.custom_minimum_size = Vector2(0, 24)
	main_box.add_child(spacer_bottom)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(160, 44)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if font_config.get_button_font():
		back_btn.add_theme_font_override("font", font_config.get_button_font())
		back_btn.add_theme_font_size_override("font_size", font_config.button_font_size)
	back_btn.pressed.connect(_on_back_button_pressed)
	main_box.add_child(back_btn)

func _on_volume_slider_changed(value: float) -> void:
	AudioManager.set_volume("Master", value)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

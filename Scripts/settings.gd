extends Control

@export var font_config: FontConfig

# Scroll speed in UV units per second (tweak to taste)
@export var scroll_speed: float = 0.015

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
	_setup_background()

	if font_config == null:
		font_config = load("res://Resources/font_config.tres") as FontConfig
	if font_config == null:
		font_config = FontConfig.new()
		print("⚠ FontConfig resource not found, created new instance")

	_apply_fonts()
	_setup_volume_slider()

func _setup_background() -> void:
	_bg = get_node_or_null("Background")
	if _bg == null:
		push_warning("settings: No TextureRect named 'Background' found.")
		return

	# Make it fill the whole screen
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# Build and assign the scroll shader
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
	# fract keeps it in 0-1 so it loops seamlessly
	_scroll_shader.set_shader_parameter("offset_x", fmod(current + scroll_speed * delta, 1.0))

func _apply_fonts() -> void:
	var title: Label = get_node_or_null("TitleContainer/Title")
	var subtitle: Label = get_node_or_null("TitleContainer/Subtitle")
	var back_btn: Button = get_node_or_null("SettingsContainer/BackButton")
	var volume_label: Label = get_node_or_null("SettingsContainer/VolumeLabel")

	if title and font_config.get_title_font():
		title.add_theme_font_override("font", font_config.get_title_font())
		title.add_theme_font_size_override("font_size", font_config.title_font_size)

	if subtitle and font_config.get_subtitle_font():
		subtitle.add_theme_font_override("font", font_config.get_subtitle_font())
		subtitle.add_theme_font_size_override("font_size", font_config.subtitle_font_size)

	if font_config.get_button_font() and back_btn:
		back_btn.add_theme_font_override("font", font_config.get_button_font())
		back_btn.add_theme_font_size_override("font_size", font_config.button_font_size)

	if font_config.get_status_font() and volume_label:
		volume_label.add_theme_font_override("font", font_config.get_status_font())
		volume_label.add_theme_font_size_override("font_size", font_config.status_font_size)

func _setup_volume_slider() -> void:
	var slider: HSlider = get_node_or_null("SettingsContainer/VolumeSlider")
	if slider == null:
		push_warning("settings: No HSlider named 'VolumeSlider' found.")
		return

	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = AudioManager.get_volume("Master")
	slider.value_changed.connect(_on_volume_slider_changed)

func _on_volume_slider_changed(value: float) -> void:
	AudioManager.set_volume("Master", value)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
